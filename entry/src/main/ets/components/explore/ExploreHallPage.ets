import {
  PAGE_HEADER_BOTTOM_PADDING,
  PAGE_HEADER_HEIGHT,
  PAGE_HEADER_HORIZONTAL_PADDING,
  PAGE_HEADER_ICON_SIZE,
  PAGE_HEADER_RADIUS,
  PAGE_HEADER_SECONDARY_FONT_SIZE,
  PAGE_HEADER_TOP_PADDING
} from '../../constants/AppConstants';
import { AppThemeAppearance, MusicSourceConfig, MusicSourceQuality, MusicSourceTrack, SourceBoardItem } from '../../models/AppModels';
import { filterSupportedExploreSources, sourceDisplayName } from '../../utils/MusicSourceUtils';
import { t } from '../../utils/I18nUtil';
import { appThemePalette } from '../../utils/ThemeUtils';
import { PlatformSelectorDrawer } from './PlatformSelectorDrawer';

@Component
export struct ExploreHallPage {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop musicSources: MusicSourceConfig[] = [];
  @Prop activeSourceId: string = '';
  @Prop activeSearchSource: string = '';
  @Prop sourceTracks: MusicSourceTrack[] = [];
  @Prop sourceTracksLoading: boolean = false;
  @Prop sourceSearchKeyword: string = '';
  @Prop sourceCurrentPage: number = 1;
  @Prop sourceTotal: number = 0;
  @Prop sourceBoardList: SourceBoardItem[] = [];
  @Prop sourceBoardsLoading: boolean = false;
  @Prop activeBoardId: string = '';
  @Prop exploreMode: string = 'board';
  @Prop bottomInset: number = 0;
  @Prop sourceImportingTrackKeys: string[] = [];
  @Prop sourceQualitySnapshot: string = '';
  @State showPlatformDrawer: boolean = false;
  onGoToProfile: () => void = () => {};
  onSelectSource: (source: MusicSourceConfig) => void = (_: MusicSourceConfig) => {};
  onSelectSubSource: (sourceCode: string) => void = (_: string) => {};
  onSelectSourceQuality: (sourceCode: string, quality: string) => void = (_: string, __: string) => {};
  onToggleMode: () => void = () => {};
  onSearchKeywordChange: (value: string) => void = (_: string) => {};
  onSearch: () => void = () => {};
  onSelectBoard: (board: SourceBoardItem) => void = (_: SourceBoardItem) => {};
  onImportTrack: (track: MusicSourceTrack) => void = (_: MusicSourceTrack) => {};
  onLoadMore: () => void = () => {};
  sourceTrackActionLabel: (track: MusicSourceTrack) => string = (_: MusicSourceTrack) => t('common.import');
  sourceTrackActionEnabled: (track: MusicSourceTrack) => boolean = (_: MusicSourceTrack) => true;

  private activeSource(): MusicSourceConfig | undefined {
    return this.musicSources.find((source: MusicSourceConfig) => source.id === this.activeSourceId);
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private availableSubSources(): MusicSourceQuality[] {
    let source = this.activeSource();
    return source ? filterSupportedExploreSources(source.musicSources) : [];
  }

  private formatDuration(seconds: number): string {
    let minutes = Math.floor(seconds / 60);
    let remainSeconds = seconds % 60;
    return `${minutes}:${remainSeconds < 10 ? '0' : ''}${remainSeconds}`;
  }

  private isSourceActive(sourceId: string): boolean {
    return this.activeSourceId === sourceId;
  }

  private isPlatformActive(sourceCode: string): boolean {
    return this.activeSearchSource === sourceCode;
  }

  private isBoardActive(boardId: string): boolean {
    return this.activeBoardId === boardId;
  }

  private platformAccentColor(sourceCode: string): string {
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

  private currentPlatformCode(): string {
    if (this.activeSearchSource.length > 0) {
      return this.activeSearchSource;
    }
    let subSources = this.availableSubSources();
    return subSources.length > 0 ? subSources[0].source : '';
  }

  private closePlatformDrawer(): void {
    this.showPlatformDrawer = false;
  }

  private openPlatformDrawer(): void {
    if (this.availableSubSources().length === 0) {
      return;
    }
    this.showPlatformDrawer = true;
  }

  private handleSelectSource(source: MusicSourceConfig): void {
    this.showPlatformDrawer = false;
    this.onSelectSource(source);
  }

  private handleSelectSubSource(sourceCode: string): void {
    this.showPlatformDrawer = false;
    this.onSelectSubSource(sourceCode);
  }

  @Builder
  private sourceCatalogChip(source: MusicSourceConfig) {
    Row({ space: 8 }) {
      Row()
        .width(7)
        .height(7)
        .backgroundColor(this.isSourceActive(source.id) ? this.theme().accent : this.theme().tertiaryText)
        .borderRadius(4)

      Text(source.name)
        .fontSize(13)
        .fontWeight(this.isSourceActive(source.id) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.isSourceActive(source.id) ? this.theme().primaryText : this.theme().secondaryText)
    }
    .padding({ left: 14, right: 16, top: 10, bottom: 10 })
    .backgroundColor(this.isSourceActive(source.id) ? this.theme().accentSoftBackground : this.theme().panelSecondaryBackground)
    .borderRadius(18)
    .border({
      width: 1,
      color: this.isSourceActive(source.id) ? this.theme().accentSoftBorder : this.theme().divider
    })
    .onClick(() => {
      this.handleSelectSource(source);
    })
  }

  @Builder
  private platformTriggerIcon() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Row() {
        Image($r('app.media.ic_list'))
          .width(PAGE_HEADER_ICON_SIZE)
          .height(PAGE_HEADER_ICON_SIZE)
          .fillColor(this.currentPlatformCode().length > 0 ? this.platformAccentColor(this.currentPlatformCode()) : this.theme().secondaryText)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme().panelSecondaryBackground)
      .borderRadius(12)
      .border({
        width: 1,
        color: this.theme().divider
      })

      if (this.currentPlatformCode().length > 0) {
        Row()
          .width(9)
          .height(9)
          .backgroundColor(this.platformAccentColor(this.currentPlatformCode()))
          .borderRadius(4.5)
          .border({
            width: 2,
            color: this.theme().panelSecondaryBackground
          })
      }
    }
    .onClick(() => {
      this.openPlatformDrawer();
    })
  }

  @Builder
  private boardChip(board: SourceBoardItem) {
    Row({ space: 8 }) {
      Row()
        .width(7)
        .height(7)
        .backgroundColor(this.isBoardActive(board.bangid) ? '#F7C27A' : this.theme().tertiaryText)
        .borderRadius(4)

      Text(board.name)
        .fontSize(12)
        .fontWeight(this.isBoardActive(board.bangid) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.isBoardActive(board.bangid) ? '#7A4F14' : this.theme().secondaryText)
    }
    .padding({ left: 14, right: 16, top: 9, bottom: 9 })
    .backgroundColor(this.isBoardActive(board.bangid) ? '#F7EFDB' : this.theme().panelSecondaryBackground)
    .borderRadius(16)
    .border({
      width: 1,
      color: this.isBoardActive(board.bangid) ? '#E7C897' : this.theme().divider
    })
    .onClick(() => {
      this.onSelectBoard(board);
    })
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
    Stack() {
      Column() {
        if (this.musicSources.length === 0) {
          Column({ space: 18 }) {
            Blank().layoutWeight(1)
            Row() {
              Image($r('app.media.ic_discover'))
                .width(42)
                .height(42)
                .opacity(0.6)
            }
            .width(80)
            .height(80)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme().panelSecondaryBackground)
            .borderRadius(40)

            Text(t('explore.no_source'))
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme().secondaryText)
            Text(t('explore.add_source_hint'))
              .fontSize(14)
              .fontColor(this.theme().tertiaryText)
            Button(t('explore.go_profile'))
              .height(42)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.theme().accentSoftBackground)
              .fontColor(this.theme().accent)
              .borderRadius(14)
              .padding({ left: 24, right: 24 })
              .margin({ top: 8 })
              .onClick(() => {
                this.onGoToProfile();
              })
            Blank().layoutWeight(1)
          }
          .width('100%')
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        } else {
          if (this.availableSubSources().length > 0) {
            Row({ space: 8 }) {
              this.platformTriggerIcon()

              Row({ space: 8 }) {
                Image($r('app.media.ic_search'))
                  .width(14)
                  .height(14)
                  .fillColor(this.theme().tertiaryText)

                TextInput({ placeholder: t('explore.search_placeholder'), text: this.sourceSearchKeyword })
                  .onChange((value: string) => {
                    this.onSearchKeywordChange(value);
                  })
                  .onSubmit(() => {
                    this.onSearch();
                  })
                  .layoutWeight(1)
                  .height(32)
                  .fontSize(PAGE_HEADER_SECONDARY_FONT_SIZE)
                  .fontColor(this.theme().primaryText)
                  .placeholderColor(this.theme().tertiaryText)
                  .placeholderFont({ size: PAGE_HEADER_SECONDARY_FONT_SIZE })
                  .backgroundColor(Color.Transparent)
                  .padding(0)

                Text(t('common.search'))
                  .fontSize(PAGE_HEADER_SECONDARY_FONT_SIZE)
                  .fontColor(this.theme().accent)
                  .fontWeight(FontWeight.Medium)
                  .onClick(() => {
                    this.onSearch();
                  })
              }
              .layoutWeight(1)
              .height(32)
              .padding({ left: 10, right: 10 })
              .backgroundColor(this.theme().controlSecondaryBackground)
              .borderRadius(12)
              .border({
                width: 1,
                color: this.theme().controlSecondaryBorder
              })
            }
            .width('100%')
            .height(PAGE_HEADER_HEIGHT)
            .padding({ left: 12, right: 8 })
            .backgroundColor(this.theme().headerBackground)
            .borderRadius(PAGE_HEADER_RADIUS)
            .border({
              width: 1,
              color: this.theme().headerBorder
            })
            .margin({
              left: PAGE_HEADER_HORIZONTAL_PADDING,
              right: PAGE_HEADER_HORIZONTAL_PADDING,
              top: PAGE_HEADER_TOP_PADDING,
              bottom: PAGE_HEADER_BOTTOM_PADDING
            })
        }

          if (this.musicSources.length > 1) {
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.musicSources, (source: MusicSourceConfig) => {
                  this.sourceCatalogChip(source)
                }, (source: MusicSourceConfig) => source.id)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 6 })
          }

          if (this.sourceBoardsLoading) {
            Row() {
              LoadingProgress().width(20).height(20).color('#5DB8C9')
              Text(t('explore.loading_board')).fontSize(13).fontColor(this.theme().secondaryText).margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 12 })
          } else if (this.sourceBoardList.length > 0) {
            Row() {
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.sourceBoardList, (board: SourceBoardItem) => {
                    this.boardChip(board)
                  }, (board: SourceBoardItem) => board.bangid)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }
            .width('100%')
            .padding(4)
            .margin({ left: 24, right: 24, bottom: 12 })
            .backgroundColor(this.theme().panelSecondaryBackground)
            .borderRadius(20)
            .border({
              width: 1,
              color: this.theme().divider
            })
          }

          if (this.sourceTracksLoading) {
            Column() {
              LoadingProgress()
                .width(36)
                .height(36)
                .color('#5DB8C9')
              Text(t('common.loading'))
                .fontSize(14)
                .fontColor(this.theme().secondaryText)
                .margin({ top: 10 })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else if (this.availableSubSources().length === 0) {
            Column({ space: 10 }) {
              Text(t('explore.no_browsable_library'))
                .fontSize(16)
                .fontColor(this.theme().secondaryText)
              Text(t('explore.no_browsable_subsource'))
                .fontSize(13)
                .fontColor(this.theme().tertiaryText)
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.sourceTracks.length === 0 && !this.sourceBoardsLoading) {
            Column({ space: 10 }) {
              if (this.exploreMode === 'board') {
                Text(t('explore.select_board'))
                  .fontSize(16)
                  .fontColor(this.theme().secondaryText)
                Text(t('explore.switch_or_browse'))
                  .fontSize(13)
                  .fontColor(this.theme().tertiaryText)
              } else {
                Text(t('explore.search_discover'))
                  .fontSize(16)
                  .fontColor(this.theme().secondaryText)
                Text(t('explore.search_input_hint'))
                  .fontSize(13)
                  .fontColor(this.theme().tertiaryText)
              }
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            Scroll() {
              Column({ space: 0 }) {
                ForEach(this.sourceTracks, (track: MusicSourceTrack, index: number) => {
                  Row({ space: 12 }) {
                    if (this.exploreMode === 'board') {
                      Text(`${index + 1}`)
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(index < 3 ? '#F0A050' : this.theme().secondaryText)
                        .width(28)
                        .textAlign(TextAlign.Center)
                    }
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
                      .padding({ left: 20, right: 20 })
                      .onClick(() => {
                        this.onLoadMore();
                      })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .padding({ top: 16, bottom: 20 })
                }
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
            .layoutWeight(1)
          }
        }
      }
      .width('100%')
      .height('100%')

      if (this.showPlatformDrawer && this.availableSubSources().length > 0) {
        PlatformSelectorDrawer({
          subSources: this.availableSubSources(),
          activeSearchSource: this.activeSearchSource,
          qualitySnapshot: this.sourceQualitySnapshot,
          onClose: () => {
            this.closePlatformDrawer();
          },
          onSelectSubSource: (sourceCode: string) => {
            this.handleSelectSubSource(sourceCode);
          },
          onSelectQuality: (sourceCode: string, quality: string) => {
            this.onSelectSourceQuality(sourceCode, quality);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
