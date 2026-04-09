import { MusicSourceConfig } from '../../models/AppModels';

@Component
export struct ProfilePageContent {
  @Prop totalHours: number = 0;
  @Prop musicSources: MusicSourceConfig[] = [];
  onOpenFavorites: () => void = () => {};
  onOpenRecent: () => void = () => {};
  onImportLocal: () => void = () => {};
  onOpenOnlineDownload: () => void = () => {};
  onOpenSourceManager: () => void = () => {};
  onBrowseSource: (source: MusicSourceConfig) => void = (_: MusicSourceConfig) => {};
  onOpenEqualizer: () => void = () => {};

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

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Row({ space: 18 }) {
          Row() {
            Image($r('app.media.ic_user'))
              .width(34)
              .height(34)
              .opacity(0.7)
          }
          .width(84)
          .height(84)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#242424')
          .borderRadius(42)

          Column({ space: 8 }) {
            Text('本地听众')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7F7F7')

            Text(`听歌时长 ${this.totalHours} 小时`)
              .fontSize(15)
              .fontColor('#6C6C6C')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        Column() {
          this.sectionItem('我的收藏', '快速查看已标记喜欢的歌曲', true, () => {
            this.onOpenFavorites();
          })
          this.sectionItem('最近播放', '回到最近听过的内容', false, () => {
            this.onOpenRecent();
          })
        }
        .width('100%')
        .backgroundColor('#171717')
        .borderRadius(20)

        Column() {
          this.sectionItem('本地导入设置', '重新选择本地音乐文件', true, () => {
            this.onImportLocal();
          })
          this.sectionItem('在线下载导入', '输入音频链接并自动加入曲库', false, () => {
            this.onOpenOnlineDownload();
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
      .padding({ left: 20, right: 20, top: 26, bottom: 20 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}
