import {
  PAGE_HEADER_BOTTOM_PADDING,
  PAGE_HEADER_HEIGHT,
  PAGE_HEADER_ICON_SIZE,
  PAGE_HEADER_PRIMARY_FONT_SIZE,
  PAGE_HEADER_RADIUS,
  PAGE_HEADER_SECONDARY_FONT_SIZE,
  PAGE_HEADER_TOP_PADDING
} from '../../constants/AppConstants';
import { AppThemeAppearance, MusicSourceConfig } from '../../models/AppModels';
import { t } from '../../utils/I18nUtil';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct ProfilePageContent {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop totalListeningText: string = t('profile.listening_hours', '0');
  @Prop themeModeLabel: string = t('theme.light');
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
      return t('profile.import_setting_desc');
    }
    return t('profile.imported_stats', `${this.importedTrackCount}`, `${this.playQueueTrackCount}`);
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

        Text(this.totalListeningText)
          .fontSize(PAGE_HEADER_PRIMARY_FONT_SIZE)
          .fontColor(this.theme().secondaryText)
          .fontWeight(FontWeight.Medium)
      }
      .layoutWeight(1)

      Text(t('profile.imported_count', `${this.importedTrackCount}`))
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
          top: PAGE_HEADER_TOP_PADDING,
          bottom: PAGE_HEADER_BOTTOM_PADDING
        })

        Column({ space: 20 }) {
        Column() {
          this.sectionItem(t('profile.local_import'), t('profile.local_import_desc'), true, () => {
            this.onImportLocal();
          })
          this.sectionItem(t('profile.baidu_import'), t('profile.baidu_import_desc'), true, () => {
            this.onOpenBaiduPanImport();
          })
          this.sectionItem(t('profile.theme_appearance'), this.themeModeLabel, true, () => {
            this.onOpenThemeMode();
          })
          this.sectionItem(t('profile.track_manager'), this.importedTrackSubtitle(), false, () => {
            this.onOpenImportedTrackManager();
          })
        }
        .width('100%')
        .backgroundColor(this.theme().panelBackground)
        .borderRadius(20)

        Column({ space: 0 }) {
          Row() {
            Text(t('profile.source_setting'))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().primaryText)
            Blank()
            Text(t('common.manage'))
              .fontSize(14)
              .fontColor(this.theme().accent)
              .onClick(() => {
                this.onOpenSourceManager();
              })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })

          if (this.musicSources.length === 0) {
            Text(t('profile.no_source_hint'))
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

                Text(t('common.browse'))
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
          this.sectionItem(t('profile.equalizer'), t('profile.equalizer_desc'), false, () => {
            this.onOpenEqualizer();
          })
        }
        .width('100%')
        .backgroundColor(this.theme().panelBackground)
        .borderRadius(20)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .padding({ bottom: this.bottomInset })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
  }
}
