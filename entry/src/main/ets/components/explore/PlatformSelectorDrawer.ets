import { AppThemeAppearance, MusicSourceQuality } from '../../models/AppModels';
import { t } from '../../utils/I18nUtil';
import {
  resolvePreferredSourceQuality,
  sourceDisplayName,
  sourceQualityDisplayName
} from '../../utils/MusicSourceUtils';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct PlatformSelectorDrawer {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop subSources: MusicSourceQuality[] = [];
  @Prop activeSearchSource: string = '';
  @Prop qualitySnapshot: string = '';
  onClose: () => void = () => {};
  onSelectSubSource: (sourceCode: string) => void = (_: string) => {};
  onSelectQuality: (sourceCode: string, quality: string) => void = (_: string, __: string) => {};

  private isActive(sourceCode: string): boolean {
    return this.activeSearchSource === sourceCode;
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private accentColor(sourceCode: string): string {
    if (sourceCode === 'kw') {
      return '#4CC7D8';
    }
    if (sourceCode === 'kg') {
      return '#53C77A';
    }
    if (sourceCode === 'tx') {
      return '#5EA7FF';
    }
    if (sourceCode === 'mg') {
      return '#F2AE5B';
    }
    if (sourceCode === 'wy') {
      return '#E97B88';
    }
    return '#5DB8C9';
  }

  private tintColor(sourceCode: string): string {
    if (sourceCode === 'kw') {
      return '#17353B';
    }
    if (sourceCode === 'kg') {
      return '#183223';
    }
    if (sourceCode === 'tx') {
      return '#173145';
    }
    if (sourceCode === 'mg') {
      return '#392714';
    }
    if (sourceCode === 'wy') {
      return '#3B1E23';
    }
    return '#193038';
  }

  private itemBorderColor(sourceCode: string): string {
    if (sourceCode === 'kw') {
      return '#2F7F8C';
    }
    if (sourceCode === 'kg') {
      return '#2D7748';
    }
    if (sourceCode === 'tx') {
      return '#366EAA';
    }
    if (sourceCode === 'mg') {
      return '#9A6228';
    }
    if (sourceCode === 'wy') {
      return '#9C4A54';
    }
    return '#356B77';
  }

  private badgeText(sourceCode: string): string {
    return sourceCode.toUpperCase();
  }

  private preferredQuality(item: MusicSourceQuality): string {
    let snapshot = this.qualitySnapshot;
    if (snapshot.length < 0) {
      return '128k';
    }
    return resolvePreferredSourceQuality(item);
  }

  private isQualitySelected(item: MusicSourceQuality, quality: string): boolean {
    return this.preferredQuality(item) === quality;
  }

  @Builder
  private qualityChip(item: MusicSourceQuality, quality: string) {
    Text(sourceQualityDisplayName(quality))
      .fontSize(11)
      .fontWeight(this.isQualitySelected(item, quality) ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.isQualitySelected(item, quality) ? '#0B0F10' : this.theme().secondaryText)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.isQualitySelected(item, quality) ? this.accentColor(item.source) : this.theme().panelSecondaryBackground)
      .borderRadius(12)
      .border({
        width: 1,
        color: this.isQualitySelected(item, quality) ? this.accentColor(item.source) : this.theme().divider
      })
      .onClick(() => {
        this.onSelectQuality(item.source, quality);
      })
  }

  @Builder
  private platformItem(item: MusicSourceQuality) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(this.badgeText(item.source))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isActive(item.source) ? '#FFFFFF' : this.accentColor(item.source))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.isActive(item.source)
            ? (this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFF1A' : '#FFFFFF66')
            : this.theme().panelSecondaryBackground)
          .borderRadius(10)

        Text(sourceDisplayName(item.source))
          .fontSize(16)
          .fontWeight(this.isActive(item.source) ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.isActive(item.source) ? this.theme().primaryText : this.theme().primaryText)
          .layoutWeight(1)
          .maxLines(1)

        if (this.isActive(item.source)) {
          Text(t('common.current'))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        } else {
          Image($r('app.media.ic_chevron_right'))
            .width(14)
            .height(14)
            .fillColor(this.theme().secondaryText)
        }
      }
      .width('100%')
      .onClick(() => {
        this.onSelectSubSource(item.source);
      })

      Text(t('explore.platform_quality_summary', sourceQualityDisplayName(this.preferredQuality(item)), `${item.qualitys.length}`))
        .fontSize(12)
        .fontColor(this.isActive(item.source) ? this.theme().secondaryText : this.theme().secondaryText)

      Scroll() {
        Row({ space: 8 }) {
          ForEach(item.qualitys, (quality: string) => {
            this.qualityChip(item, quality)
          }, (quality: string) => `${item.source}_${quality}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 18, right: 18, top: 14, bottom: 14 })
    .backgroundColor(this.isActive(item.source) ? this.tintColor(item.source) : this.theme().panelSecondaryBackground)
    .borderRadius(20)
    .border({
      width: 1,
      color: this.isActive(item.source) ? this.itemBorderColor(item.source) : this.theme().divider
    })
  }

  build() {
    Stack() {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme().maskBackground)
        .transition(TransitionEffect.opacity(0))
        .onClick(() => {
          this.onClose();
        })

      Row() {
        Column() {
          Row() {
            Column({ space: 6 }) {
              Text(t('explore.platform_title'))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme().primaryText)

              Text(t('explore.platform_hint'))
                .fontSize(13)
                .fontColor(this.theme().secondaryText)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(t('common.close'))
              .fontSize(15)
              .fontColor(this.theme().accent)
              .onClick(() => {
                this.onClose();
              })
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 26, bottom: 18 })

          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.subSources, (item: MusicSourceQuality) => {
                this.platformItem(item)
              }, (item: MusicSourceQuality) => `${item.source}_${this.qualitySnapshot}`)
            }
            .width('100%')
            .padding({ left: 22, right: 22, bottom: 28 })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .layoutWeight(1)
          .width('100%')
        }
        .width('74%')
        .height('100%')
        .backgroundColor(this.theme().frostedBackground)
        .backdropBlur(18)
        .border({
          width: 1,
          color: this.theme().divider
        })
        .borderRadius({ topRight: 30, bottomRight: 30 })
        .transition(
          TransitionEffect.translate({ x: -320 })
            .combine(TransitionEffect.opacity(0))
        )

        Blank()
          .layoutWeight(1)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
