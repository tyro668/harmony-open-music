import { AppThemeAppearance, MusicSourceConfig, MusicSourceQuality } from '../../models/AppModels';
import { sourceDisplayName } from '../../utils/MusicSourceUtils';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct SourceManagerPanel {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop musicSources: MusicSourceConfig[] = [];
  @Prop addSourceLoading: boolean = false;
  @Prop sourceUrlInput: string = '';
  onClose: () => void = () => {};
  onSourceUrlChange: (value: string) => void = (_: string) => {};
  onAddFromFile: () => void = () => {};
  onAddFromUrl: () => void = () => {};
  onToggleUpdateAlert: (sourceId: string) => void = (_: string) => {};
  onRemoveSource: (sourceId: string) => void = (_: string) => {};

  private sourceInitial(source: MusicSourceConfig): string {
    return source.name.length > 0 ? source.name.substring(0, 1) : 'S';
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  build() {
    Column() {
      Column() {
        Row() {
          Text('音源管理')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().primaryText)
          Blank()
          Text('关闭')
            .fontSize(15)
            .fontColor(this.theme().accent)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 16 })

        Column({ space: 12 }) {
          Text('导入洛雪音乐自定义音源脚本，支持本地 .js 文件或远程 URL。')
            .fontSize(12)
            .fontColor(this.theme().secondaryText)
            .lineHeight(18)
            .width('100%')

          Button(this.addSourceLoading ? '导入中...' : '从本地文件导入')
            .width('100%')
            .height(42)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.theme().accentSoftBackground)
            .fontColor(this.theme().accent)
            .borderRadius(14)
            .enabled(!this.addSourceLoading)
            .onClick(() => {
              this.onAddFromFile();
            })

          Row({ space: 8 }) {
            TextInput({ placeholder: '输入音源脚本 URL', text: this.sourceUrlInput })
              .height(42)
              .fontSize(14)
              .fontColor(this.theme().primaryText)
              .placeholderColor(this.theme().tertiaryText)
              .placeholderFont({ size: 14 })
              .backgroundColor(this.theme().inputBackground)
              .borderRadius(14)
              .padding({ left: 14, right: 14 })
              .layoutWeight(1)
              .enabled(!this.addSourceLoading)
              .onChange((value: string) => {
                this.onSourceUrlChange(value);
              })
            Button(this.addSourceLoading ? '...' : '导入')
              .height(42)
              .width(72)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.theme().accentSoftBackground)
              .fontColor(this.theme().accent)
              .borderRadius(14)
              .enabled(!this.addSourceLoading && this.sourceUrlInput.length > 0)
              .onClick(() => {
                this.onAddFromUrl();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 16 })

        Scroll() {
          Column({ space: 0 }) {
            if (this.musicSources.length === 0) {
              Column({ space: 10 }) {
                Text('暂无音源')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme().secondaryText)
                Text('请导入洛雪音乐自定义音源 .js 脚本')
                  .fontSize(13)
                  .fontColor(this.theme().tertiaryText)
              }
              .width('100%')
              .padding({ top: 60, bottom: 60 })
              .alignItems(HorizontalAlign.Center)
            } else {
              ForEach(this.musicSources, (source: MusicSourceConfig) => {
                Row({ space: 14 }) {
                  Row() {
                    Text(this.sourceInitial(source))
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.theme().accent)
                  }
                  .width(44)
                  .height(44)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(this.theme().accentSoftBackground)
                  .borderRadius(12)

                  Column({ space: 4 }) {
                    Text(source.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme().primaryText)
                    Text(`${source.author} · v${source.version}`)
                      .fontSize(12)
                      .fontColor(this.theme().secondaryText)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`子源: ${source.musicSources.map((item: MusicSourceQuality) => sourceDisplayName(item.source)).join(', ')}`)
                      .fontSize(11)
                      .fontColor(this.theme().tertiaryText)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`更新提醒: ${source.allowShowUpdateAlert ? '开启' : '关闭'}`)
                      .fontSize(11)
                      .fontColor(source.allowShowUpdateAlert ? this.theme().accent : this.theme().secondaryText)
                    if (source.homepage.length > 0) {
                      Text(source.homepage)
                        .fontSize(11)
                        .fontColor(this.theme().tertiaryText)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Column({ space: 8 }) {
                    Text(source.allowShowUpdateAlert ? '关闭提醒' : '开启提醒')
                      .fontSize(12)
                      .fontColor(source.allowShowUpdateAlert ? this.theme().warningText : this.theme().accent)
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor(source.allowShowUpdateAlert ? this.theme().warningBackground : this.theme().accentSoftBackground)
                      .borderRadius(12)
                      .onClick(() => {
                        this.onToggleUpdateAlert(source.id);
                      })

                    Text('删除')
                      .fontSize(13)
                      .fontColor(this.theme().dangerText)
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor(this.theme().dangerBackground)
                      .borderRadius(12)
                      .onClick(() => {
                        this.onRemoveSource(source.id);
                      })
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%')
                .padding({ left: 24, right: 24, top: 14, bottom: 14 })
              }, (source: MusicSourceConfig) => source.id)
            }
          }
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
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
