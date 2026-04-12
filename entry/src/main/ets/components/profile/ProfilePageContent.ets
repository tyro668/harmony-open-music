import {
  PAGE_HEADER_BOTTOM_PADDING,
  PAGE_HEADER_HEIGHT,
  PAGE_HEADER_HORIZONTAL_PADDING,
  PAGE_HEADER_ICON_SIZE,
  PAGE_HEADER_PRIMARY_FONT_SIZE,
  PAGE_HEADER_RADIUS,
  PAGE_HEADER_SECONDARY_FONT_SIZE,
  PAGE_HEADER_TOP_PADDING
} from '../../constants/AppConstants';
import { AppThemeAppearance, MusicSourceConfig } from '../../models/AppModels';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct ProfilePageContent {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop totalHours: number = 0;
  @Prop themeModeLabel: string = '浅色';
  @Prop musicSources: MusicSourceConfig[] = [];
  @Prop importedTrackCount: number = 0;
  @Prop playQueueTrackCount: number = 0;
  @Prop bottomInset: number = 0;
  onImportLocal: () => void = () => {};
  onOpenBaiduPanImport: () => void = () => {};
  onOpenThemeMode: () => void = () => {};
  onOpenImportedTrackManager: () => void = () => {};
  onOpenSourceManager: () => void = () => {};
  onBrowseSource: (source: MusicSourceConfig) => void = (_: MusicSourceConfig) => {};
  onOpenEqualizer: () => void = () => {};

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

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
            .fontColor(this.theme().primaryText)
          Text(subtitle)
            .fontSize(13)
            .fontColor(this.theme().secondaryText)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($r('app.media.ic_chevron_right'))
          .width(16)
          .height(16)
          .fillColor(this.theme().tertiaryText)
          .opacity(0.7)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .onClick(action)

      if (showDivider) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(this.theme().divider)
          .margin({ left: 20, right: 20 })
      }
    }
  }

  @Builder
  private statsHeader() {
    Row({ space: 12 }) {
      Row({ space: 8 }) {
        Image($r('app.media.ic_clock'))
          .width(PAGE_HEADER_ICON_SIZE)
          .height(PAGE_HEADER_ICON_SIZE)
          .fillColor(this.theme().accent)

        Text(`累计听歌 ${this.totalHours} 小时`)
          .fontSize(PAGE_HEADER_PRIMARY_FONT_SIZE)
          .fontColor(this.theme().secondaryText)
          .fontWeight(FontWeight.Medium)
      }
      .layoutWeight(1)

      Text(`${this.importedTrackCount} 首已导入`)
        .fontSize(PAGE_HEADER_SECONDARY_FONT_SIZE)
        .fontColor(this.theme().secondaryText)
    }
    .width('100%')
    .height(PAGE_HEADER_HEIGHT)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.theme().headerBackground)
    .borderRadius(PAGE_HEADER_RADIUS)
    .border({
      width: 1,
      color: this.theme().headerBorder
    })
  }

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Column() {
          this.statsHeader()
        }
        .width('100%')
        .padding({
          left: PAGE_HEADER_HORIZONTAL_PADDING,
          right: PAGE_HEADER_HORIZONTAL_PADDING,
          top: PAGE_HEADER_TOP_PADDING,
          bottom: PAGE_HEADER_BOTTOM_PADDING
        })

        Column({ space: 20 }) {
        Column() {
          this.sectionItem('本地导入设置', '重新选择本地音乐文件', true, () => {
            this.onImportLocal();
          })
          this.sectionItem('百度网盘导入', '浏览百度网盘中的音频文件', true, () => {
            this.onOpenBaiduPanImport();
          })
          this.sectionItem('主题外观', this.themeModeLabel, true, () => {
            this.onOpenThemeMode();
          })
          this.sectionItem('导入音乐管理', this.importedTrackSubtitle(), false, () => {
            this.onOpenImportedTrackManager();
          })
        }
        .width('100%')
        .backgroundColor(this.theme().panelBackground)
        .borderRadius(20)

        Column({ space: 0 }) {
          Row() {
            Text('音源设置')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().primaryText)
            Blank()
            Text('管理')
              .fontSize(14)
              .fontColor(this.theme().accent)
              .onClick(() => {
                this.onOpenSourceManager();
              })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })

          if (this.musicSources.length === 0) {
            Text('暂未添加自定义音源，点击管理添加')
              .fontSize(13)
              .fontColor(this.theme().tertiaryText)
              .padding({ left: 20, right: 20, bottom: 16 })
              .width('100%')
          } else {
            ForEach(this.musicSources, (source: MusicSourceConfig, index: number) => {
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(source.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme().primaryText)
                  Text(`${source.author} · v${source.version}`)
                    .fontSize(12)
                    .fontColor(this.theme().secondaryText)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('浏览')
                  .fontSize(13)
                  .fontColor(this.theme().onAccent)
                  .fontWeight(FontWeight.Medium)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .backgroundColor(this.theme().accent)
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
                  .backgroundColor(this.theme().divider)
                  .margin({ left: 20, right: 20 })
              }
            }, (source: MusicSourceConfig) => source.id)
            Blank().height(6)
          }
        }
        .width('100%')
        .backgroundColor(this.theme().panelBackground)
        .borderRadius(20)

        Column() {
          this.sectionItem('均衡器调节', '当前版本先保留入口', false, () => {
            this.onOpenEqualizer();
          })
        }
        .width('100%')
        .backgroundColor(this.theme().panelBackground)
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
