import { webview } from '@kit.ArkWeb';
import { AppThemeAppearance } from '../../models/AppModels';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct BaiduPanAuthPanel {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop appKey: string = '';
  @Prop authUrl: string = '';
  @Prop isAuthorizing: boolean = false;
  @State lastObservedPayload: string = '';
  onClose: () => void = () => {};
  onAppKeyChange: (value: string) => void = (_: string) => {};
  onStartAuth: () => void = () => {};
  onObservedPayload: (payload: string) => void = (_: string) => {};
  private controller: webview.WebviewController = new webview.WebviewController();

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private emitPayload(payload: string): void {
    let normalized = payload.trim();
    if (normalized.length === 0 || normalized === this.lastObservedPayload) {
      return;
    }
    this.lastObservedPayload = normalized;
    this.onObservedPayload(normalized);
  }

  private async inspectCurrentPage(): Promise<void> {
    try {
      let currentUrl = await this.controller.runJavaScript('window.location.href');
      this.emitPayload(currentUrl);
    } catch (_) {
      // controller may not be ready yet
    }

    try {
      let snapshot = await this.controller.runJavaScript(
        '(function(){try{return window.location.href + "\\n" + (document.body ? document.body.innerText.slice(0, 800) : "");}catch(e){return "";}})();'
      );
      this.emitPayload(snapshot);
    } catch (_) {
      // page may not allow script execution at this moment
    }
  }

  @Builder
  private compactAction(label: string, enabled: boolean, primary: boolean, action: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor(primary ? this.theme().onAccent : this.theme().accent)
      .fontWeight(FontWeight.Medium)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(primary ? this.theme().accent : this.theme().accentSoftBackground)
      .borderRadius(11)
      .opacity(enabled ? 1 : 0.45)
      .onClick(() => {
        if (enabled) {
          action();
        }
      })
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Row() {
          Text('百度授权登录')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().primaryText)
          Blank()
          Text('关闭')
            .fontSize(14)
            .fontColor(this.theme().accent)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')

        Row({ space: 10 }) {
          TextInput({
            placeholder: 'AppKey',
            text: this.appKey
          })
            .height(40)
            .fontSize(14)
            .fontColor(this.theme().primaryText)
            .placeholderColor(this.theme().tertiaryText)
            .backgroundColor(this.theme().inputBackground)
            .borderRadius(12)
            .padding({ left: 14, right: 14 })
            .layoutWeight(1)
            .onChange((value: string) => {
              this.onAppKeyChange(value);
            })
            .onSubmit(() => {
              if (!this.isAuthorizing && this.appKey.trim().length > 0) {
                this.onStartAuth();
              }
            })

          this.compactAction(this.isAuthorizing ? '重载' : '打开', this.appKey.trim().length > 0, true, () => {
            this.onStartAuth();
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 12 })

      if (this.authUrl.trim().length === 0) {
        Column() {
          Text('待授权')
            .fontSize(15)
            .fontColor(this.theme().secondaryText)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 40, bottom: 56 })
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Web({ src: this.authUrl, controller: this.controller })
            .width('100%')
            .layoutWeight(1)
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .databaseAccess(true)
            .fileAccess(false)
            .onPageBegin((event) => {
              if (event?.url) {
                this.emitPayload(event.url);
              }
            })
            .onPageEnd((event) => {
              if (event?.url) {
                this.emitPayload(event.url);
              }
              void this.inspectCurrentPage();
            })
            .onUrlLoadIntercept((event) => {
              if (typeof event?.data === 'string') {
                this.emitPayload(event.data as string);
              }
              return false;
            })
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().panelBackground)
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}
