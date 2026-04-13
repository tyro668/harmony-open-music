import { AppThemeAppearance, BaiduPanEntry } from '../../models/AppModels';
import { t } from '../../utils/I18nUtil';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct BaiduPanImportPanel {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop appKey: string = '';
  @Prop accessToken: string = '';
  @Prop currentDir: string = '/';
  @Prop entries: BaiduPanEntry[] = [];
  @Prop isLoading: boolean = false;
  @Prop importingKeys: string[] = [];
  @Prop importedKeySnapshot: string = '';
  onClose: () => void = () => {};
  onAppKeyChange: (value: string) => void = (_: string) => {};
  onOpenAuth: () => void = () => {};
  onRefresh: () => void = () => {};
  onEnterDirectory: (entry: BaiduPanEntry) => void = (_: BaiduPanEntry) => {};
  onGoParent: () => void = () => {};
  onImportEntry: (entry: BaiduPanEntry) => void = (_: BaiduPanEntry) => {};

  private entryImportKey(entry: BaiduPanEntry): string {
    return `baidupan:${entry.fsId}`;
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private isImported(entry: BaiduPanEntry): boolean {
    return this.importedKeySnapshot.indexOf(this.entryImportKey(entry)) >= 0;
  }

  private isImporting(entry: BaiduPanEntry): boolean {
    return this.importingKeys.indexOf(this.entryImportKey(entry)) >= 0;
  }

  private actionLabel(entry: BaiduPanEntry): string {
    if (this.isImported(entry)) {
      return t('common.imported');
    }
    if (this.isImporting(entry)) {
      return t('common.importing');
    }
    return t('common.import');
  }

  private actionEnabled(entry: BaiduPanEntry): boolean {
    return !entry.isDirectory && !this.isImported(entry) && !this.isImporting(entry);
  }

  private formatFileSize(size: number): string {
    if (size <= 0) {
      return '--';
    }
    if (size < 1024) {
      return `${size} B`;
    }
    if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`;
    }
    if (size < 1024 * 1024 * 1024) {
      return `${(size / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${(size / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }

  private entrySubtitle(entry: BaiduPanEntry): string {
    if (entry.isDirectory) {
      return entry.path;
    }
    return this.formatFileSize(entry.size);
  }

  private hasAccessToken(): boolean {
    return this.accessToken.trim().length > 0;
  }

  private actionBackground(entry: BaiduPanEntry): string {
    let label = this.actionLabel(entry);
    if (label === t('common.imported')) {
      return this.theme().successBackground;
    }
    if (label === t('common.importing')) {
      return this.theme().accentSoftBackground;
    }
    return this.theme().accent;
  }

  private actionFontColor(entry: BaiduPanEntry): string {
    let label = this.actionLabel(entry);
    if (label === t('common.imported')) {
      return this.theme().successText;
    }
    if (label === t('common.importing')) {
      return this.theme().accent;
    }
    return this.theme().onAccent;
  }

  @Builder
  private entryBadge(entry: BaiduPanEntry) {
    Row() {
      Text(entry.isDirectory ? 'DIR' : 'MP3')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(entry.isDirectory ? this.theme().accent : this.theme().primaryText)
    }
    .width(38)
    .height(38)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(entry.isDirectory ? this.theme().accentSoftBackground : this.theme().panelSecondaryBackground)
    .borderRadius(10)
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
      Column() {
        Row() {
          Text(t('baidu.import_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().primaryText)
          Blank()
          Text(t('common.close'))
            .fontSize(14)
            .fontColor(this.theme().accent)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 12 })

        Column({ space: 8 }) {
          Row({ space: 8 }) {
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

            this.compactAction(this.hasAccessToken() ? t('baidu.reauth') : t('baidu.auth'), this.appKey.trim().length > 0, true, () => {
              this.onOpenAuth();
            })
          }
          .width('100%')

          Row({ space: 10 }) {
            Text(this.currentDir)
              .fontSize(12)
              .fontColor(this.theme().secondaryText)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (this.currentDir !== '/') {
              Text(t('baidu.parent_dir'))
                .fontSize(12)
                .fontColor(this.theme().warningText)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(this.theme().warningBackground)
                .borderRadius(12)
                .onClick(() => {
                  this.onGoParent();
                })
            }

            this.compactAction(t('baidu.parent'), this.currentDir !== '/', false, () => {
              this.onGoParent();
            })

            this.compactAction(t('common.refresh'), this.hasAccessToken() && !this.isLoading, false, () => {
              this.onRefresh();
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 12 })

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(this.theme().accent)
          }
          .width('100%')
          .padding({ top: 56, bottom: 56 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.accessToken.trim().length === 0) {
          Column() {
            Text(t('baidu.not_authorized'))
              .fontSize(15)
              .fontColor(this.theme().secondaryText)
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 56, bottom: 56 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.entries.length === 0) {
          Column() {
            Text(t('baidu.empty_dir'))
              .fontSize(15)
              .fontColor(this.theme().secondaryText)
          }
          .width('100%')
          .padding({ top: 56, bottom: 56 })
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column({ space: 0 }) {
              ForEach(this.entries, (entry: BaiduPanEntry, index: number) => {
                Row({ space: 12 }) {
                  this.entryBadge(entry)

                  Column({ space: 4 }) {
                    Text(entry.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme().primaryText)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(this.entrySubtitle(entry))
                      .fontSize(12)
                      .fontColor(this.theme().secondaryText)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  if (entry.isDirectory) {
                    Text(t('common.enter'))
                      .fontSize(12)
                      .fontColor(this.theme().accent)
                      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                      .backgroundColor(this.theme().accentSoftBackground)
                      .borderRadius(11)
                      .onClick(() => {
                        this.onEnterDirectory(entry);
                      })
                  } else {
                    Text(this.actionLabel(entry))
                      .fontSize(12)
                      .fontColor(this.actionFontColor(entry))
                      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                      .backgroundColor(this.actionBackground(entry))
                      .borderRadius(11)
                      .opacity(this.actionEnabled(entry) ? 1 : 0.78)
                      .onClick(() => {
                        if (this.actionEnabled(entry)) {
                          this.onImportEntry(entry);
                        }
                      })
                  }
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 14, bottom: 14 })

                if (index < this.entries.length - 1) {
                  Row()
                    .width('100%')
                    .height(1)
                    .backgroundColor(this.theme().divider)
                    .margin({ left: 20, right: 20 })
                }
              }, (entry: BaiduPanEntry) => `${entry.fsId}_${this.importedKeySnapshot}_${this.importingKeys.join('|')}`)
            }
            .width('100%')
            .constraintSize({ minHeight: '100%' })
            .justifyContent(FlexAlign.Start)
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme().panelBackground)
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
