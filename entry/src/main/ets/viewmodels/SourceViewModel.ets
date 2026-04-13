import { common } from '@kit.AbilityKit';
import { picker, fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import fs from '@ohos.file.fs';
import { MusicSourceConfig, MusicSourceTrack, QuickJsLogPayload, SourceUpdateAlertPayload } from '../models/AppModels';
import { QuickJsEngineAdapter, QuickJsHostEvent } from '../utils/QuickJsEngine';
import { LX_PRELOAD_SCRIPT as USER_API_PRELOAD_SCRIPT } from '../utils/LxUserApiPreload';
import {
  buildQuickJsLyricRequest,
  buildQuickJsMusicUrlRequest,
  buildQuickJsSourceSetupScript,
  createQuickJsHttpRequestTask,
  handleJsEngineInitPayload,
  parseQuickJsLyricResponse,
  parseQuickJsMusicUrlResponse,
  SourceLyricResult
} from '../services/QuickJsSourceService';
import {
  createPendingMusicSource,
  removeSourceById,
  toggleSourceUpdateAlert,
  updateSourcePreferredQuality
} from '../services/CustomSourceCatalogService';
import { sourceDisplayName, sourceQualityDisplayName } from '../utils/MusicSourceUtils';
import { t } from '../utils/I18nUtil';
import { BaseViewModel } from './BaseViewModel';

@Observed
export class SourceState {
  musicSources: MusicSourceConfig[] = [];
  showSourceManager: boolean = false;
  showAddSourceDialog: boolean = false;
  addSourceLoading: boolean = false;
  sourceUrlInput: string = '';
  showSourceUpdateAlertDialog: boolean = false;
  sourceUpdateAlertName: string = '';
  sourceUpdateAlertLog: string = '';
  sourceUpdateAlertUrl: string = '';
}

export class SourceViewModel extends BaseViewModel {
  private jsEngineKey: string = '';
  private jsEngineSourceId: string = '';
  private jsEngineReady: boolean = false;
  private jsEngineLastError: string = '';
  private quickJsEngine: QuickJsEngineAdapter | null = null;
  private musicSourceScripts: Map<string, string> = new Map();

  // Callbacks
  onSourcesChanged: (() => void) | null = null;
  onShowSourceUpdateAlert: ((name: string, log: string, url: string) => void) | null = null;
  onGetMusicSourceScript: ((sourceId: string) => Promise<string>) | null = null;
  onDeleteMusicSourceScript: ((sourceId: string) => Promise<void>) | null = null;
  onGetActiveSourceForUpdateAlert: (() => MusicSourceConfig | undefined) | null = null;

  getMusicSourceScripts(): Map<string, string> {
    return this.musicSourceScripts;
  }

  setMusicSourceScripts(scripts: Map<string, string>): void {
    this.musicSourceScripts = scripts;
  }

  getJsEngineSourceId(): string {
    return this.jsEngineSourceId;
  }

  isJsEngineReady(): boolean {
    return this.jsEngineReady;
  }

  getJsEngineLastError(): string {
    return this.jsEngineLastError;
  }

  resetQuickJsEngine(): void {
    if (this.quickJsEngine !== null) {
      this.quickJsEngine.dispose();
      this.quickJsEngine = null;
    }
    this.jsEngineReady = false;
    this.jsEngineLastError = '';
    this.jsEngineSourceId = '';
    this.jsEngineKey = '';
  }

  private getQuickJsEngine(): QuickJsEngineAdapter {
    if (this.quickJsEngine === null) {
      this.quickJsEngine = new QuickJsEngineAdapter(
        createQuickJsHttpRequestTask,
        async (event: QuickJsHostEvent): Promise<void> => {
          await this.handleQuickJsHostEvent(event.action, event.payloadJson);
        }
      );
    }
    return this.quickJsEngine;
  }

  private async handleQuickJsHostEvent(action: string, payloadJson: string): Promise<void> {
    if (action === 'showUpdateAlert') {
      this.handleSourceUpdateAlert(payloadJson);
      return;
    }
    if (action === 'log') {
      this.handleSourceConsoleLog(payloadJson);
      return;
    }
    console.warn(`Unhandled QuickJS host event: ${action}`);
  }

  private handleSourceConsoleLog(payloadJson: string): void {
    try {
      let payload = JSON.parse(payloadJson) as QuickJsLogPayload;
      let message = payload && typeof payload.log === 'string' ? payload.log : payloadJson;
      if (payload.type === 'warn') {
        console.warn(`[source-script] ${message}`);
      } else if (payload.type === 'error') {
        console.error(`[source-script] ${message}`);
      } else {
        console.info(`[source-script] ${message}`);
      }
    } catch (error) {
      console.info(`[source-script] ${payloadJson}`);
    }
  }

  private handleSourceUpdateAlert(payloadJson: string): void {
    try {
      let payload: SourceUpdateAlertPayload = JSON.parse(payloadJson) as SourceUpdateAlertPayload;
      if (this.onGetActiveSourceForUpdateAlert) {
        let activeSource: MusicSourceConfig | undefined = this.onGetActiveSourceForUpdateAlert();
        if (activeSource && activeSource.allowShowUpdateAlert === false) return;
        let name: string = payload && typeof payload.name === 'string' && payload.name.length > 0 ? payload.name : (activeSource?.name || t('source.default_name'));
        let log: string = payload && typeof payload.log === 'string' && payload.log.length > 0 ? payload.log : t('source.default_alert_msg');
        let url: string = payload && typeof payload.updateUrl === 'string' ? payload.updateUrl : '';
        if (this.onShowSourceUpdateAlert) {
          this.onShowSourceUpdateAlert(name, log, url);
        }
      }
    } catch (error) {
      console.error(`parse source update alert failed: ${JSON.stringify(error)}`);
    }
  }

  private handleJsEngineInit(state: SourceState, data: Record<string, Object>): void {
    let initOutcome = handleJsEngineInitPayload(state.musicSources, this.jsEngineSourceId, data);
    if (initOutcome.ready && initOutcome.didUpdateSources) {
      state.musicSources = initOutcome.musicSources;
      this.schedulePersist();
    }
    if (!initOutcome.ready) {
      console.error(`JS engine init failed: ${initOutcome.errorMessage}`);
    }
    this.jsEngineReady = initOutcome.ready;
    this.jsEngineLastError = initOutcome.errorMessage;
  }

  async loadSourceIntoJsEngine(state: SourceState, source: MusicSourceConfig): Promise<boolean> {
    if (this.jsEngineSourceId === source.id && this.jsEngineReady) return true;
    this.jsEngineReady = false;
    this.jsEngineLastError = '';
    this.jsEngineSourceId = '';
    this.jsEngineKey = `key_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    try {
      let script = this.musicSourceScripts.get(source.id) ?? '';
      if (script.length === 0 && this.onGetMusicSourceScript) {
        script = await this.onGetMusicSourceScript(source.id);
      }
      if (script.length === 0) throw new Error('source script not found');
      let setupScript = buildQuickJsSourceSetupScript(this.jsEngineKey, source, script, USER_API_PRELOAD_SCRIPT);
      let initPayloadJson = await this.getQuickJsEngine().loadSource(this.jsEngineKey, setupScript);
      this.jsEngineSourceId = source.id;
      this.handleJsEngineInit(state, JSON.parse(initPayloadJson) as Record<string, Object>);
      if (!this.jsEngineReady) {
        let errMsg = this.jsEngineLastError.length > 0 ? this.jsEngineLastError : 'source init returned not ready';
        this.resetQuickJsEngine();
        this.jsEngineLastError = errMsg;
        return false;
      }
      return true;
    } catch (error) {
      let errMsg = error instanceof Error ? error.message : String(error);
      console.error(`loadSourceIntoJsEngine failed: ${errMsg}`);
      this.resetQuickJsEngine();
      this.jsEngineLastError = errMsg;
      return false;
    }
  }

  async requestMusicUrlFromEngine(state: SourceState, source: MusicSourceConfig, track: MusicSourceTrack, quality: string): Promise<string> {
    let loaded = await this.loadSourceIntoJsEngine(state, source);
    if (!loaded) throw new Error(this.jsEngineLastError || 'JS engine not ready');
    let requestKey = `musicUrl_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    let responsePayloadJson = await this.getQuickJsEngine().dispatch(this.jsEngineKey, 'request', buildQuickJsMusicUrlRequest(requestKey, track, quality));
    return parseQuickJsMusicUrlResponse(responsePayloadJson);
  }

  async requestLyricFromEngine(state: SourceState, source: MusicSourceConfig, track: MusicSourceTrack): Promise<SourceLyricResult | null> {
    let loaded = await this.loadSourceIntoJsEngine(state, source);
    if (!loaded) return null;
    try {
      let requestKey = `lyric_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
      let responsePayloadJson = await this.getQuickJsEngine().dispatch(this.jsEngineKey, 'request', buildQuickJsLyricRequest(requestKey, track));
      return parseQuickJsLyricResponse(responsePayloadJson);
    } catch (error) {
      console.error(`request lyric from JS engine failed: source=${track.source}, name=${track.name}`);
      return null;
    }
  }

  processAndAddSource(state: SourceState, scriptContent: string): MusicSourceConfig | null {
    try {
      let result = createPendingMusicSource(scriptContent, state.musicSources);
      if (!result.source) {
        this.showToast(result.errorMessage);
        return null;
      }
      this.musicSourceScripts.set(result.source.id, scriptContent);
      state.musicSources = state.musicSources.concat([result.source]);
      state.showAddSourceDialog = false;
      this.schedulePersist();
      return result.source;
    } catch (error) {
      let errMsg = error instanceof Error ? error.message : t('source.import_fail_invalid');
      this.showToast(errMsg);
      return null;
    }
  }

  async validateAndActivateSource(state: SourceState, source: MusicSourceConfig): Promise<boolean> {
    let loaded = await this.loadSourceIntoJsEngine(state, source);
    if (!loaded) {
      this.removeMusicSource(state, source.id, false);
      this.showToast(t('source.load_fail', source.name, this.jsEngineLastError));
      return false;
    }
    this.schedulePersist();
    this.showToast(t('source.added', source.name));
    return true;
  }

  async importAndValidateSourceScript(state: SourceState, scriptContent: string): Promise<boolean> {
    let source = this.processAndAddSource(state, scriptContent);
    if (!source) return false;
    return await this.validateAndActivateSource(state, source);
  }

  async importMusicSourceScriptFromUrl(url: string): Promise<string> {
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (response.responseCode !== 200) throw new Error(t('source.download_fail', `${response.responseCode}`));
      let scriptContent = response.result as string;
      if (!scriptContent || scriptContent.length === 0) throw new Error(t('source.empty_script'));
      return scriptContent;
    } finally {
      httpRequest.destroy();
    }
  }

  private async readMusicSourceScriptFromFile(uri: string): Promise<string> {
    let fileUriObj: fileUri.FileUri = new fileUri.FileUri(uri);
    let file: fs.File = fs.openSync(fileUriObj.path, fs.OpenMode.READ_ONLY);
    try {
      let buf: ArrayBuffer = new ArrayBuffer(128 * 1024);
      let readLen: number = fs.readSync(file.fd, buf);
      let decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buf, 0, readLen));
    } finally {
      fs.closeSync(file);
    }
  }

  async addMusicSourceFromFile(state: SourceState): Promise<void> {
    state.addSourceLoading = true;
    try {
      let context = this.context();
      let options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = [t('source.file_filter')];
      let documentPicker = new picker.DocumentViewPicker(context);
      let uris = await documentPicker.select(options);
      if (!uris || uris.length === 0) {
        state.addSourceLoading = false;
        return;
      }
      let scriptContent = await this.readMusicSourceScriptFromFile(uris[0]);
      await this.importAndValidateSourceScript(state, scriptContent);
    } catch (error) {
      this.showToast(t('source.import_fail_invalid'));
    } finally {
      state.addSourceLoading = false;
    }
  }

  async addMusicSourceFromUrl(state: SourceState): Promise<void> {
    let url = state.sourceUrlInput.trim();
    if (url.length === 0) { this.showToast(t('source.url_required')); return; }
    if (!url.startsWith('http://') && !url.startsWith('https://')) { this.showToast(t('source.url_invalid')); return; }
    state.addSourceLoading = true;
    try {
      let scriptContent = await this.importMusicSourceScriptFromUrl(url);
      if (await this.importAndValidateSourceScript(state, scriptContent)) {
        state.sourceUrlInput = '';
      }
    } catch (error) {
      let errMsg = error instanceof Error ? error.message : t('source.url_import_fail');
      this.showToast(errMsg);
    } finally {
      state.addSourceLoading = false;
    }
  }

  toggleMusicSourceAllowShowUpdateAlert(state: SourceState, sourceId: string): void {
    let updateResult = toggleSourceUpdateAlert(state.musicSources, sourceId);
    state.musicSources = updateResult.sources;
    if (updateResult.updated) this.schedulePersist();
  }

  updateMusicSourcePreferredQuality(state: SourceState, sourceId: string, sourceCode: string, quality: string): void {
    let updateResult = updateSourcePreferredQuality(state.musicSources, sourceId, sourceCode, quality);
    if (!updateResult.updated) return;
    state.musicSources = updateResult.sources;
    this.schedulePersist();
    this.showToast(t('source.quality_switched', sourceDisplayName(sourceCode), sourceQualityDisplayName(quality)));
  }

  removeMusicSource(state: SourceState, sourceId: string, showToast: boolean = true): void {
    let removeResult = removeSourceById(state.musicSources, sourceId);
    if (!removeResult.updated) return;
    state.musicSources = removeResult.sources;
    if (this.jsEngineSourceId === sourceId) this.resetQuickJsEngine();
    if (this.onDeleteMusicSourceScript) {
      void this.onDeleteMusicSourceScript(sourceId).catch(() => {});
    }
    this.schedulePersist();
    if (showToast) this.showToast(t('source.deleted'));
  }

  closeSourceManager(state: SourceState): void {
    state.showSourceManager = false;
    state.showAddSourceDialog = false;
  }

  dispose(): void {
    this.resetQuickJsEngine();
  }
}
