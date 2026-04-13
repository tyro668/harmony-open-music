import { AppThemeAppearance, MusicSourceQuality, MusicSourceTrack } from '../../models/AppModels';
import {
  resolvePreferredSourceQuality,
  sourceDisplayName,
  sourceQualityDisplayName
} from '../../utils/MusicSourceUtils';
import { t } from '../../utils/I18nUtil';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct SourceBrowserPanel {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop title: string = t('source.browser_title');
  @Prop subSources: MusicSourceQuality[] = [];
  @Prop activeSearchSource: string = '';
  @Prop sourceSearchKeyword: string = '';
  @Prop sourceTracks: MusicSourceTrack[] = [];
  @Prop sourceTracksLoading: boolean = false;
  @Prop sourceTotal: number = 0;
  @Prop sourceCurrentPage: number = 1;
  @Prop sourceImportingTrackKeys: string[] = [];
  @Prop sourceQualitySnapshot: string = '';
  onClose: () => void = () => {};
  onSelectSubSource: (sourceCode: string) => void = (_: string) => {};
  onSelectQuality: (sourceCode: string, quality: string) => void = (_: string, __: string) => {};
  onSearchKeywordChange: (value: string) => void = (_: string) => {};
  onSearch: () => void = () => {};
  onLoadMore: () => void = () => {};
  onImportTrack: (track: MusicSourceTrack) => void = (_: MusicSourceTrack) => {};
  sourceTrackActionLabel: (track: MusicSourceTrack) => string = (_: MusicSourceTrack) => t('common.import');
  sourceTrackActionEnabled: (track: MusicSourceTrack) => boolean = (_: MusicSourceTrack) => true;

  private formatDuration(seconds: number): string {
    let minutes = Math.floor(seconds / 60);
    let remainSeconds = seconds % 60;
    return `${minutes}:${remainSeconds < 10 ? '0' : ''}${remainSeconds}`;
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private activeSubSourceItem(): MusicSourceQuality | undefined {
    let current = this.subSources.find((item: MusicSourceQuality) => item.source === this.activeSearchSource);
    if (current) {
      return current;
    }
    return this.subSources.length > 0 ? this.subSources[0] : undefined;
  }

  private preferredQuality(item: MusicSourceQuality): string {
    let snapshot = this.sourceQualitySnapshot;
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
      .fontColor(this.isQualitySelected(item, quality) ? this.theme().onAccent : this.theme().secondaryText)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.isQualitySelected(item, quality) ? this.theme().accent : this.theme().panelSecondaryBackground)
      .borderRadius(12)
      .border({
        width: 1,
        color: this.isQualitySelected(item, quality) ? this.theme().accent : this.theme().divider
      })
      .onClick(() => {
        this.onSelectQuality(item.source, quality);
      })
  }

  @Builder
  private qualitySelector(item: MusicSourceQuality) {
    Column({ space: 8 }) {
      Text(t('source.current_quality', sourceQualityDisplayName(this.preferredQuality(item))))
        .fontSize(12)
        .fontColor(this.theme().secondaryText)

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
    .width('100%')
    .padding({ left: 24, right: 24, bottom: 10 })
  }

  private resolvedTrackActionLabel(track: MusicSourceTrack): string {
    let importQueueSnapshot = this.sourceImportingTrackKeys.join('|');
    return importQueueSnapshot.length < 0 ? t('common.import') : this.sourceTrackActionLabel(track);
  }

  private resolvedTrackActionEnabled(track: MusicSourceTrack): boolean {
    let importQueueSnapshot = this.sourceImportingTrackKeys.join('|');
    return importQueueSnapshot.length < 0 ? true : this.sourceTrackActionEnabled(track);
  }

  private importButtonBackground(track: MusicSourceTrack): string {
    let label = this.resolvedTrackActionLabel(track);
    if (label === t('common.imported')) {
      return this.theme().successBackground;
    }
    if (label === t('common.importing')) {
      return this.theme().accentSoftBackground;
    }
    return this.theme().accent;
  }

  private importButtonFontColor(track: MusicSourceTrack): string {
    let label = this.resolvedTrackActionLabel(track);
    if (label === t('common.imported')) {
      return this.theme().successText;
    }
    if (label === t('common.importing')) {
      return this.theme().accent;
    }
    return this.theme().onAccent;
  }

  build() {
    Column() {
      Column() {
        Row() {
          Text('← ')
            .fontSize(20)
            .fontColor(this.theme().accent)
            .onClick(() => {
              this.onClose();
            })
          Text(this.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().primaryText)
            .layoutWeight(1)
          Text(t('common.close'))
            .fontSize(15)
            .fontColor(this.theme().accent)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 12 })

        if (this.subSources.length > 0) {
          Scroll() {
            Row({ space: 6 }) {
              ForEach(this.subSources, (item: MusicSourceQuality) => {
                Text(sourceDisplayName(item.source))
                  .fontSize(13)
                  .fontWeight(this.activeSearchSource === item.source ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.activeSearchSource === item.source ? this.theme().onAccent : this.theme().secondaryText)
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .backgroundColor(this.activeSearchSource === item.source ? this.theme().accent : this.theme().panelSecondaryBackground)
                  .borderRadius(16)
                  .onClick(() => {
                    this.onSelectSubSource(item.source);
                  })
              }, (item: MusicSourceQuality) => `${item.source}_${this.sourceQualitySnapshot}`)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 10 })

          if (this.activeSubSourceItem()) {
            this.qualitySelector(this.activeSubSourceItem() as MusicSourceQuality)
          }

          Row({ space: 10 }) {
            TextInput({ placeholder: t('explore.search_placeholder'), text: this.sourceSearchKeyword })
              .onChange((value: string) => {
                this.onSearchKeywordChange(value);
              })
              .onSubmit(() => {
                this.onSearch();
              })
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .fontColor(this.theme().primaryText)
              .placeholderColor(this.theme().tertiaryText)
              .backgroundColor(this.theme().inputBackground)
              .borderRadius(12)
              .padding({ left: 14, right: 14 })

            Button(t('common.search'))
              .height(40)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.theme().accent)
              .fontColor(this.theme().onAccent)
              .borderRadius(12)
              .padding({ left: 16, right: 16 })
              .onClick(() => {
                this.onSearch();
              })
          }
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 12 })
        }

        if (this.sourceTracksLoading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(this.theme().accent)
            Text(t('common.loading'))
              .fontSize(14)
              .fontColor(this.theme().secondaryText)
              .margin({ top: 10 })
          }
          .width('100%')
          .padding({ top: 60 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.subSources.length === 0) {
          Column({ space: 10 }) {
            Text(t('source.no_search_library'))
              .fontSize(18)
              .fontColor(this.theme().secondaryText)
            Text(t('source.search_supported'))
              .fontSize(13)
              .fontColor(this.theme().tertiaryText)
          }
          .width('100%')
          .padding({ top: 60 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.sourceTracks.length === 0) {
          Column({ space: 10 }) {
            Text(t('source.search_title'))
              .fontSize(18)
              .fontColor(this.theme().secondaryText)
            Text(t('source.search_hint'))
              .fontSize(13)
              .fontColor(this.theme().tertiaryText)
          }
          .width('100%')
          .padding({ top: 60 })
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column({ space: 0 }) {
              ForEach(this.sourceTracks, (track: MusicSourceTrack) => {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text(track.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme().primaryText)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row({ space: 6 }) {
                      Text(track.singer)
                        .fontSize(13)
                        .fontColor(this.theme().secondaryText)
                        .maxLines(1)
                      if (track.album.length > 0) {
                        Text(`· ${track.album}`)
                          .fontSize(13)
                          .fontColor(this.theme().secondaryText)
                          .maxLines(1)
                      }
                      if (track.duration > 0) {
                        Text(this.formatDuration(track.duration))
                          .fontSize(12)
                          .fontColor(this.theme().tertiaryText)
                      }
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(this.resolvedTrackActionLabel(track))
                    .fontSize(13)
                    .fontColor(this.importButtonFontColor(track))
                    .fontWeight(FontWeight.Medium)
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(this.importButtonBackground(track))
                    .borderRadius(14)
                    .opacity(this.resolvedTrackActionEnabled(track) ? 1 : 0.86)
                    .onClick(() => {
                      if (this.resolvedTrackActionEnabled(track)) {
                        this.onImportTrack(track);
                      }
                    })
                }
                .width('100%')
                .padding({ left: 24, right: 24, top: 12, bottom: 12 })
              }, (track: MusicSourceTrack) => track.id)

              if (this.sourceTracks.length < this.sourceTotal) {
                Row() {
                  Button(t('common.load_more'))
                    .height(38)
                    .fontSize(14)
                    .backgroundColor(this.theme().accentSoftBackground)
                    .fontColor(this.theme().accent)
                    .borderRadius(14)
                    .onClick(() => {
                      this.onLoadMore();
                    })
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ top: 16, bottom: 20 })
              }
            }
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
