import { common } from '@kit.AbilityKit';

export class BaseViewModel {
  protected showToastFn: (message: string) => void = () => {};
  protected schedulePersistFn: () => void = () => {};
  protected getContextFn: () => common.UIAbilityContext = () => {
    throw new Error('getContextFn not bound');
  };

  bindDependencies(
    showToast: (message: string) => void,
    schedulePersist: () => void,
    getContext: () => common.UIAbilityContext
  ): void {
    this.showToastFn = showToast;
    this.schedulePersistFn = schedulePersist;
    this.getContextFn = getContext;
  }

  protected showToast(message: string): void {
    this.showToastFn(message);
  }

  protected schedulePersist(): void {
    this.schedulePersistFn();
  }

  protected context(): common.UIAbilityContext {
    return this.getContextFn();
  }
}
