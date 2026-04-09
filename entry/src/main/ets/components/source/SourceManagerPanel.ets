import { MusicSourceConfig, MusicSourceQuality } from '../../models/AppModels';
import { sourceDisplayName } from '../../utils/MusicSourceUtils';

@Component
export struct SourceManagerPanel {
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

  build() {
    Column() {
      Column() {
        Row() {
          Text('音源管理')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F5F5F5')
          Blank()
          Text('关闭')
            .fontSize(15)
            .fontColor('#5DB8C9')
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 16 })

        Column({ space: 12 }) {
          Text('导入洛雪音乐自定义音源脚本，支持本地 .js 文件或远程 URL。')
            .fontSize(12)
            .fontColor('#777')
            .lineHeight(18)
            .width('100%')

          Button(this.addSourceLoading ? '导入中...' : '从本地文件导入')
            .width('100%')
            .height(42)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#1E3A4A')
            .fontColor('#5DB8C9')
            .borderRadius(14)
            .enabled(!this.addSourceLoading)
            .onClick(() => {
              this.onAddFromFile();
            })

          Row({ space: 8 }) {
            TextInput({ placeholder: '输入音源脚本 URL', text: this.sourceUrlInput })
              .height(42)
              .fontSize(14)
              .fontColor('#E0E0E0')
              .placeholderColor('#666')
              .placeholderFont({ size: 14 })
              .backgroundColor('#1A2A32')
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
              .backgroundColor('#1E3A4A')
              .fontColor('#5DB8C9')
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
                  .fontColor('#888')
                Text('请导入洛雪音乐自定义音源 .js 脚本')
                  .fontSize(13)
                  .fontColor('#555')
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
                      .fontColor('#5DB8C9')
                  }
                  .width(44)
                  .height(44)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor('#1E3A4A')
                  .borderRadius(12)

                  Column({ space: 4 }) {
                    Text(source.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#F0F0F0')
                    Text(`${source.author} · v${source.version}`)
                      .fontSize(12)
                      .fontColor('#666')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`子源: ${source.musicSources.map((item: MusicSourceQuality) => sourceDisplayName(item.source)).join(', ')}`)
                      .fontSize(11)
                      .fontColor('#444')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`更新提醒: ${source.allowShowUpdateAlert ? '开启' : '关闭'}`)
                      .fontSize(11)
                      .fontColor(source.allowShowUpdateAlert ? '#5DB8C9' : '#777777')
                    if (source.homepage.length > 0) {
                      Text(source.homepage)
                        .fontSize(11)
                        .fontColor('#555555')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Column({ space: 8 }) {
                    Text(source.allowShowUpdateAlert ? '关闭提醒' : '开启提醒')
                      .fontSize(12)
                      .fontColor(source.allowShowUpdateAlert ? '#D6B65D' : '#5DB8C9')
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor(source.allowShowUpdateAlert ? '#2F2714' : '#16333B')
                      .borderRadius(12)
                      .onClick(() => {
                        this.onToggleUpdateAlert(source.id);
                      })

                    Text('删除')
                      .fontSize(13)
                      .fontColor('#D94040')
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .backgroundColor('#2A1515')
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
      .backgroundColor('#111111')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
