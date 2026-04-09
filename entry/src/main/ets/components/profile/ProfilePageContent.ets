import { MusicSourceConfig } from '../../models/AppModels';

@Component
export struct ProfilePageContent {
  @Prop totalHours: number = 0;
  @Prop musicSources: MusicSourceConfig[] = [];
  @Prop importedTrackCount: number = 0;
  @Prop playQueueTrackCount: number = 0;
  @Prop bottomInset: number = 0;
  onImportLocal: () => void = () => {};
  onOpenOnlineDownload: () => void = () => {};
  onOpenImportedTrackManager: () => void = () => {};
  onOpenSourceManager: () => void = () => {};
  onBrowseSource: (source: MusicSourceConfig) => void = (_: MusicSourceConfig) => {};
  onOpenEqualizer: () => void = () => {};

  private importedTrackSubtitle(): string {
    if (this.importedTrackCount === 0) {
      return '管理已导入歌曲，并决定是否加入播放列表';
    }
    return `已导入 ${this.importedTrackCount} 首，当前在播放列表中 ${this.playQueueTrackCount} 首`;
  }

  @Builder
  private sectionItem(title: string, subtitle: string, showDivider: boolean, action: () => void) {
    Column() {
      Row({ space: 14 }) {
        Column({ space: 4 }) {
          Text(title)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F5F5F5')
          Text(subtitle)
            .fontSize(13)
            .fontColor('#707070')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.ic_chevron_right'))
          .width(16)
          .height(16)
          .opacity(0.4)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .onClick(action)

      if (showDivider) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor('#222222')
          .margin({ left: 20, right: 20 })
      }
    }
  }

  @Builder
  private statsHeader() {
    Row() {
      Row({ space: 6 }) {
        Image($r('app.media.ic_clock'))
          .width(14)
          .height(14)
          .fillColor('#5DB8C9')

        Text(`累计听歌 ${this.totalHours} 小时`)
          .fontSize(12)
          .fontColor('#8A8A8A')
      }

      Blank()

      Text(`${this.importedTrackCount} 首已导入`)
        .fontSize(12)
        .fontColor('#8A8A8A')
    }
    .width('100%')
    .height(42)
  }

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Column() {
          this.statsHeader()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 8 })

        Column({ space: 20 }) {
        Column() {
          this.sectionItem('本地导入设置', '重新选择本地音乐文件', true, () => {
            this.onImportLocal();
          })
          this.sectionItem('在线下载导入', '输入音频链接并自动加入曲库', true, () => {
            this.onOpenOnlineDownload();
          })
          this.sectionItem('导入音乐管理', this.importedTrackSubtitle(), false, () => {
            this.onOpenImportedTrackManager();
          })
        }
        .width('100%')
        .backgroundColor('#171717')
        .borderRadius(20)

        Column({ space: 0 }) {
          Row() {
            Text('音源设置')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F5F5F5')
            Blank()
            Text('管理')
              .fontSize(14)
              .fontColor('#5DB8C9')
              .onClick(() => {
                this.onOpenSourceManager();
              })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })

          if (this.musicSources.length === 0) {
            Text('暂未添加自定义音源，点击管理添加')
              .fontSize(13)
              .fontColor('#555555')
              .padding({ left: 20, right: 20, bottom: 16 })
              .width('100%')
          } else {
            ForEach(this.musicSources, (source: MusicSourceConfig, index: number) => {
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(source.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#E8E8E8')
                  Text(`${source.author} · v${source.version}`)
                    .fontSize(12)
                    .fontColor('#666666')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('浏览')
                  .fontSize(13)
                  .fontColor('#050505')
                  .fontWeight(FontWeight.Medium)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .backgroundColor('#5DB8C9')
                  .borderRadius(14)
                  .onClick(() => {
                    this.onBrowseSource(source);
                  })
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 10, bottom: 10 })

              if (index < this.musicSources.length - 1) {
                Row()
                  .width('100%')
                  .height(1)
                  .backgroundColor('#222222')
                  .margin({ left: 20, right: 20 })
              }
            }, (source: MusicSourceConfig) => source.id)
            Blank().height(6)
          }
        }
        .width('100%')
        .backgroundColor('#171717')
        .borderRadius(20)

        Column() {
          this.sectionItem('均衡器调节', '当前版本先保留入口', false, () => {
            this.onOpenEqualizer();
          })
        }
        .width('100%')
        .backgroundColor('#171717')
        .borderRadius(20)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .padding({ bottom: this.bottomInset + 20 })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
  }
}
