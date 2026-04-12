import quickJsBridge from 'libentry.so';

interface QuickJsBridgeModule {
  createEngine(): string;
  destroyEngine(engineId: string): void;
  loadSource(engineId: string, setupScript: string): string;
  dispatch(engineId: string, engineKey: string, action: string, dataJson: string): string;
  rawInflate(data: ArrayBuffer): ArrayBuffer;
}

const nativeBridge: QuickJsBridgeModule = quickJsBridge as QuickJsBridgeModule;

export function rawInflate(data: ArrayBuffer): ArrayBuffer {
  return nativeBridge.rawInflate(data);
}

interface QuickJsLoadEnvelope {
  status: boolean;
  payloadJson?: string;
  errorMessage?: string;
}

interface QuickJsDispatchEnvelope {
  type: string;
  action?: string;
  payloadJson?: string;
  errorMessage?: string;
}

interface QuickJsTimerHostEvent {
  id: number;
  ms: number;
}

export interface QuickJsHttpOptions {
  method: string;
  headers: Record<string, string>;
  body?: string;
  form?: Record<string, string>;
  formData?: Record<string, string>;
  timeout: number;
  binary: boolean;
}

export interface QuickJsHttpRequest {
  requestKey: string;
  url: string;
  options: QuickJsHttpOptions;
}

export interface QuickJsHttpTask {
  response: Promise<string>;
  abort?: () => void;
}

export interface QuickJsHostEvent {
  action: string;
  payloadJson: string;
}

export class QuickJsEngineAdapter {
  private readonly bridge: QuickJsBridgeModule = nativeBridge;
  private engineId: string = '';
  private isDisposed: boolean = false;
  private readonly hostRequestHandler: (request: QuickJsHttpRequest) => QuickJsHttpTask;
  private readonly hostEventHandler?: (event: QuickJsHostEvent) => Promise<void>;
  private readonly pendingRequestTasks: Map<string, QuickJsHttpTask> = new Map();
  private pendingEngineEvents: Array<Promise<QuickJsDispatchEnvelope>> = [];
  private dispatchChain: Promise<void> = Promise.resolve();

  constructor(
    hostRequestHandler: (request: QuickJsHttpRequest) => QuickJsHttpTask,
    hostEventHandler?: (event: QuickJsHostEvent) => Promise<void>
  ) {
    this.hostRequestHandler = hostRequestHandler;
    this.hostEventHandler = hostEventHandler;
    this.engineId = this.bridge.createEngine();
  }

  dispose(): void {
    this.isDisposed = true;
    let pendingTasks = Array.from(this.pendingRequestTasks.values());
    this.pendingRequestTasks.clear();
    this.pendingEngineEvents = [];
    this.dispatchChain = Promise.resolve();
    for (let index = 0; index < pendingTasks.length; index++) {
      let task = pendingTasks[index];
      if (!task.abort) {
        continue;
      }
      try {
        task.abort();
      } catch (error) {
        console.error(`QuickJS request abort failed during dispose: ${JSON.stringify(error)}`);
      }
    }
    if (this.engineId.length === 0) {
      return;
    }
    this.bridge.destroyEngine(this.engineId);
    this.engineId = '';
  }

  async loadSource(engineKey: string, setupScript: string): Promise<string> {
    if (this.isDisposed) {
      throw new Error('QuickJS engine is disposed');
    }
    this.ensureEngine();
    let raw = this.bridge.loadSource(this.engineId, setupScript);
    let envelope = JSON.parse(raw) as QuickJsLoadEnvelope;
    if (envelope.status !== true || !envelope.payloadJson) {
      throw new Error(envelope.errorMessage || 'QuickJS loadSource failed');
    }
    let current = this.parseDispatch(envelope.payloadJson);
    return this.awaitTerminalResult(engineKey, current, 'QuickJS source script did not initialize', 'init');
  }

  async dispatch(engineKey: string, action: string, dataJson: string): Promise<string> {
    if (this.isDisposed) {
      throw new Error('QuickJS engine is disposed');
    }
    this.ensureEngine();
    let current = await this.dispatchIntoEngine(engineKey, action, dataJson);
    return this.awaitTerminalResult(engineKey, current, 'QuickJS engine returned idle before producing a response');
  }

  private ensureEngine(): void {
    if (this.isDisposed) {
      return;
    }
    if (this.engineId.length === 0) {
      this.engineId = this.bridge.createEngine();
    }
  }

  private parseDispatch(raw: string): QuickJsDispatchEnvelope {
    return JSON.parse(raw) as QuickJsDispatchEnvelope;
  }

  private async awaitTerminalResult(
    engineKey: string,
    initial: QuickJsDispatchEnvelope,
    idleErrorMessage: string,
    expectedAction?: string
  ): Promise<string> {
    let current = initial;
    while (true) {
      if (current.type === 'done') {
        if (expectedAction && current.action !== expectedAction) {
          throw new Error(`QuickJS terminal action mismatch: expected ${expectedAction}, got ${current.action || 'unknown'}`);
        }
        return current.payloadJson || '';
      }
      if (current.type === 'host') {
        current = await this.handleHostEvent(engineKey, current);
        continue;
      }
      if (current.type === 'idle') {
        if (this.pendingEngineEvents.length > 0) {
          current = await Promise.race(this.pendingEngineEvents);
          continue;
        }
        throw new Error(idleErrorMessage);
      }
      throw new Error(current.errorMessage || 'QuickJS dispatch failed');
    }
  }

  private async dispatchIntoEngine(engineKey: string, action: string, dataJson: string): Promise<QuickJsDispatchEnvelope> {
    let executeDispatch = async (): Promise<QuickJsDispatchEnvelope> => {
      if (this.isDisposed) {
        return { type: 'idle' };
      }
      this.ensureEngine();
      if (this.engineId.length === 0) {
        return { type: 'idle' };
      }
      return this.parseDispatch(this.bridge.dispatch(this.engineId, engineKey, action, dataJson));
    };
    let scheduled = this.dispatchChain.then(executeDispatch, executeDispatch);
    this.dispatchChain = scheduled.then((): void => undefined, (): void => undefined);
    return scheduled;
  }

  private trackPendingEngineEvent(task: Promise<QuickJsDispatchEnvelope>): void {
    let tracked = task.finally((): void => {
      this.removePendingEngineEvent(tracked);
    });
    this.pendingEngineEvents.push(tracked);
  }

  private removePendingEngineEvent(target: Promise<QuickJsDispatchEnvelope>): void {
    let remaining: Array<Promise<QuickJsDispatchEnvelope>> = [];
    for (let index = 0; index < this.pendingEngineEvents.length; index++) {
      let current = this.pendingEngineEvents[index];
      if (current !== target) {
        remaining.push(current);
      }
    }
    this.pendingEngineEvents = remaining;
  }

  private createRequestErrorResponseJson(requestKey: string, error: Object): string {
    let errorMessage = '';
    if (error instanceof Error) {
      errorMessage = error.message;
    } else {
      errorMessage = JSON.stringify(error);
      if (errorMessage.length === 0) {
        errorMessage = String(error);
      }
    }
    return JSON.stringify({
      requestKey: requestKey,
      error: errorMessage || 'request failed'
    });
  }

  private async handleHostEvent(engineKey: string, event: QuickJsDispatchEnvelope): Promise<QuickJsDispatchEnvelope> {
    if (!event.action || event.payloadJson === undefined) {
      throw new Error('QuickJS host event is missing action or payload');
    }
    if (event.action === 'request') {
      let request = JSON.parse(event.payloadJson) as QuickJsHttpRequest;
      let requestTask = this.hostRequestHandler(request);
      this.pendingRequestTasks.set(request.requestKey, requestTask);
      let responseDispatch = requestTask.response
        .catch((error: Object): string => this.createRequestErrorResponseJson(request.requestKey, error))
        .then((responseJson: string): Promise<QuickJsDispatchEnvelope> => {
          return this.dispatchIntoEngine(engineKey, 'response', responseJson);
        })
        .finally((): void => {
          this.pendingRequestTasks.delete(request.requestKey);
        });
      this.trackPendingEngineEvent(responseDispatch);
      return this.dispatchIntoEngine(engineKey, '__continue__', 'null');
    }
    if (event.action === 'cancelRequest') {
      let requestKey = JSON.parse(event.payloadJson) as string;
      let requestTask = this.pendingRequestTasks.get(requestKey);
      if (requestTask && requestTask.abort) {
        try {
          requestTask.abort();
        } catch (error) {
          console.error(`QuickJS request abort failed: ${JSON.stringify(error)}`);
        }
      }
      return this.dispatchIntoEngine(engineKey, '__continue__', 'null');
    }
    if (event.action === '__set_timeout__') {
      let timerInfo = JSON.parse(event.payloadJson) as QuickJsTimerHostEvent;
      let delay = Math.max(0, Math.min(timerInfo.ms || 0, 60000));
      let timerDispatch = new Promise<QuickJsDispatchEnvelope>((resolve, reject) => {
        setTimeout(() => {
          this.dispatchIntoEngine(engineKey, '__set_timeout__', String(timerInfo.id))
            .then((result: QuickJsDispatchEnvelope) => {
              resolve(result);
            })
            .catch((error: Object) => {
              reject(error);
            });
        }, delay);
      });
      this.trackPendingEngineEvent(timerDispatch);
      return this.dispatchIntoEngine(engineKey, '__continue__', 'null');
    }
    if (this.hostEventHandler) {
      try {
        await this.hostEventHandler({
          action: event.action,
          payloadJson: event.payloadJson
        });
      } catch (error) {
        console.error(`QuickJS host event handler failed: action=${event.action}, error=${JSON.stringify(error)}`);
      }
      return this.dispatchIntoEngine(engineKey, '__continue__', 'null');
    }
    throw new Error(`Unsupported QuickJS host action: ${event.action}`);
  }
}
