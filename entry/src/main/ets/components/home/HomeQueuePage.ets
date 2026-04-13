import { image } from '@kit.ImageKit';

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
import { AppThemeAppearance, MusicTrack, PlayMode } from '../../models/AppModels';
import { t } from '../../utils/I18nUtil';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct HomeQueuePage {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop tracks: MusicTrack[] = [];
  @Prop currentTrackId: string = '';
  @Prop playMode: PlayMode = PlayMode.Sequential;
  @Prop activeCollectionTitle: string = t('collection.all_music');
  @Prop showRenameDialog: boolean = false;
  @Prop renameText: string = '';
  @Prop searchKeyword: string = '';
  @Prop bottomInset: number = 0;
  @Prop coveredTrackIds: string[] = [];
  onOpenPlaylistDrawer: () => void = () => {};
  onSelectPlayMode: (mode: PlayMode) => void = (_: PlayMode) => {};
  onSearchKeywordChange: (value: string) => void = (_: string) => {};
  onSearch: () => void = () => {};
  onTrackTap: (track: MusicTrack) => void = (_: MusicTrack) => {};
  onToggleFavorite: (trackId: string) => void = (_: string) => {};
  onOpenRename: (track: MusicTrack) => void = (_: MusicTrack) => {};
  onRenameTextChange: (value: string) => void = (_: string) => {};
  onCancelRename: () => void = () => {};
  onConfirmRename: () => void = () => {};
  trackDurationText: (track: MusicTrack) => string = (_: MusicTrack) => '--:--';
  coverForTrack: (trackId: string) => image.PixelMap | null = (_: string) => null;

  private hasTrackCover(trackId: string): boolean {
    return this.coveredTrackIds.indexOf(trackId) >= 0 && this.coverForTrack(trackId) !== null;
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private trackCover(trackId: string): image.PixelMap {
    return this.coverForTrack(trackId) as image.PixelMap;
  }

  private playlistTriggerBackground(): string {
    return this.themeAppearance === AppThemeAppearance.Light
      ? this.theme().panelSecondaryBackground
      : '#00000000';
  }

  private playlistTriggerBorderWidth(): number {
    return this.themeAppearance === AppThemeAppearance.Light ? 1 : 0;
  }

  private playlistTriggerBorderColor(): string {
    return this.themeAppearance === AppThemeAppearance.Light
      ? this.theme().divider
      : '#00000000';
  }

  private trackRenderKey(track: MusicTrack): string {
    return `${track.id}_${track.isFavorite ? '1' : '0'}`;
  }

  private currentPlayModeIcon(): Resource {
    if (this.playMode === PlayMode.Shuffle) {
      return $r('app.media.ic_shuffle');
    }
    if (this.playMode === PlayMode.Loop) {
      return $r('app.media.ic_loop');
    }
    return $r('app.media.ic_sequential');
  }

  private cyclePlayMode(): void {
    if (this.playMode === PlayMode.Sequential) {
      this.onSelectPlayMode(PlayMode.Shuffle);
    } else if (this.playMode === PlayMode.Shuffle) {
      this.onSelectPlayMode(PlayMode.Loop);
    } else {
      this.onSelectPlayMode(PlayMode.Sequential);
    }
  }

  @Builder
  private playModeButton(label: string, icon: Resource, mode: PlayMode) {
    Row({ space: 5 }) {
      Image(icon)
        .width(12)
        .height(12)
        .fillColor(this.playMode === mode ? this.theme().onAccent : this.theme().secondaryText)

      Text(label)
        .fontSize(PAGE_HEADER_SECONDARY_FONT_SIZE)
        .fontColor(this.playMode === mode ? this.theme().onAccent : this.theme().secondaryText)
        .fontWeight(this.playMode === mode ? FontWeight.Medium : FontWeight.Normal)
    }
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor(this.playMode === mode ? this.theme().accent : Color.Transparent)
    .borderRadius(14)
    .onClick(() => {
      this.onSelectPlayMode(mode);
    })
  }

  @Builder
  private playlistHeader() {
    Row({ space: 8 }) {
      Row() {
        Image($r('app.media.ic_list'))
          .width(PAGE_HEADER_ICON_SIZE)
          .height(PAGE_HEADER_ICON_SIZE)
          .fillColor(this.theme().navActiveIcon)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme().controlSecondaryBackground)
      .borderRadius(12)
      .border({
        width: 1,
        color: this.theme().controlSecondaryBorder
      })
      .onClick(() => {
        this.onOpenPlaylistDrawer();
      })

      Row({ space: 8 }) {
        Image($r('app.media.ic_search'))
          .width(14)
          .height(14)
          .fillColor(this.theme().tertiaryText)

        TextInput({ text: this.searchKeyword, placeholder: t('home.search_placeholder') })
          .placeholderColor(this.theme().tertiaryText)
          .placeholderFont({ size: PAGE_HEADER_SECONDARY_FONT_SIZE })
          .fontSize(PAGE_HEADER_SECONDARY_FONT_SIZE)
          .fontColor(this.theme().primaryText)
          .backgroundColor(Color.Transparent)
          .padding(0)
          .layoutWeight(1)
          .height(32)
          .onChange((value: string) => {
            this.onSearchKeywordChange(value);
          })
          .onSubmit(() => {
            this.onSearch();
          })

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

      Row() {
        Image(this.currentPlayModeIcon())
          .width(PAGE_HEADER_ICON_SIZE)
          .height(PAGE_HEADER_ICON_SIZE)
          .fillColor(this.theme().navActiveIcon)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme().controlSecondaryBackground)
      .borderRadius(12)
      .border({
        width: 1,
        color: this.theme().controlSecondaryBorder
      })
      .onClick(() => {
        this.cyclePlayMode();
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
    .margin({ left: PAGE_HEADER_HORIZONTAL_PADDING, right: PAGE_HEADER_HORIZONTAL_PADDING })
  }

  @Builder
  private coverArt(track: MusicTrack, size: number) {
    if (this.hasTrackCover(track.id)) {
      Stack() {
        Row()
          .width(size)
          .height(size)
          .backgroundColor(track.accentColor)
          .borderRadius(14)

        Image(this.trackCover(track.id))
          .width(size)
          .height(size)
          .objectFit(ImageFit.Cover)
          .borderRadius(14)
      }
      .width(size)
      .height(size)
    } else if (track.pic.length > 0) {
      Stack() {
        Row()
          .width(size)
          .height(size)
          .backgroundColor(track.accentColor)
          .borderRadius(14)

        Image(track.pic)
          .width(size)
          .height(size)
          .objectFit(ImageFit.Cover)
          .borderRadius(14)
      }
      .width(size)
      .height(size)
    } else {
      Row() {
        Image($r('app.media.ic_note'))
          .width(size * 0.34)
          .height(size * 0.34)
          .opacity(0.45)
      }
      .width(size)
      .height(size)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(track.accentColor)
      .borderRadius(14)
    }
  }

  @Builder
  private trackRow(track: MusicTrack, isLast: boolean) {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        if (this.currentTrackId === track.id) {
          Row()
            .width(3)
            .height(28)
            .backgroundColor(this.theme().accent)
            .borderRadius(1.5)
        } else {
          Blank().width(3)
        }

        if (this.currentTrackId === track.id) {
          Stack({ alignContent: Alignment.Center }) {
            this.coverArt(track, 50)
            Row() {
              Image($r('app.media.ic_play'))
                .width(16)
                .height(16)
                .fillColor('#FFFFFF')
            }
            .width(50)
            .height(50)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme().maskBackground)
            .borderRadius(14)
          }
          .width(50)
          .height(50)
        } else {
          this.coverArt(track, 50)
        }

        Column({ space: 3 }) {
          Text(track.title)
            .fontSize(16)
            .fontWeight(this.currentTrackId === track.id ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.theme().primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(track.artist)
            .fontSize(12)
            .fontColor(this.theme().secondaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Image(track.isFavorite ? $r('app.media.ic_heart_filled') : $r('app.media.ic_heart'))
          .width(18)
          .height(18)
          .fillColor(track.isFavorite ? '#E85D75' : this.theme().tertiaryText)
          .onClick(() => {
            this.onToggleFavorite(track.id);
          })

        Row({ space: 4 }) {
          Image($r('app.media.ic_clock'))
            .width(12)
            .height(12)
            .fillColor(this.theme().tertiaryText)

          Text(this.trackDurationText(track))
            .fontSize(12)
            .fontColor(this.theme().tertiaryText)
        }

        Image($r('app.media.ic_more'))
          .width(18)
          .height(18)
          .fillColor(this.theme().tertiaryText)
          .onClick(() => {
            this.onOpenRename(track);
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.currentTrackId === track.id ? this.theme().activeRowBackground : Color.Transparent)
      .onClick(() => {
        this.onTrackTap(track);
      })

      if (!isLast) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(this.theme().divider)
      }
    }
    .width('100%')
  }

  @Builder
  private emptyState() {
    Column({ space: 10 }) {
      Text(t('home.no_tracks'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().primaryText)
      Text(t('home.import_hint'))
        .fontSize(14)
        .fontColor(this.theme().secondaryText)
        .textAlign(TextAlign.Center)
        .lineHeight(22)
    }
    .width('100%')
    .padding({ top: 56, bottom: 56, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private renameDialog() {
    Column() {
      Column({ space: 20 }) {
        Text(t('home.rename_track'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().primaryText)

        TextInput({ text: this.renameText, placeholder: t('home.rename_placeholder') })
          .placeholderColor(this.theme().tertiaryText)
          .fontSize(16)
          .fontColor(this.theme().primaryText)
          .backgroundColor(this.theme().inputBackground)
          .caretColor(this.theme().accent)
          .borderRadius(14)
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .onChange((value: string) => {
            this.onRenameTextChange(value);
          })

        Row({ space: 12 }) {
          Button(t('common.cancel'))
            .layoutWeight(1)
            .height(42)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.theme().panelSecondaryBackground)
            .fontColor(this.theme().secondaryText)
            .borderRadius(21)
            .onClick(() => {
              this.onCancelRename();
            })

          Button(t('common.confirm'))
            .layoutWeight(1)
            .height(42)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.theme().accent)
            .fontColor(this.theme().onAccent)
            .borderRadius(21)
            .onClick(() => {
              this.onConfirmRename();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(24)
      .backgroundColor(this.theme().panelBackground)
      .borderRadius(24)
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 40 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        Column() {
          this.playlistHeader()
        }
        .width('100%')
        .padding({
          top: PAGE_HEADER_TOP_PADDING,
          bottom: PAGE_HEADER_BOTTOM_PADDING
        })

        Scroll() {
          Column({ space: 0 }) {
          if (this.tracks.length === 0) {
            this.emptyState()
          } else {
            ForEach(this.tracks, (track: MusicTrack, index: number) => {
              this.trackRow(track, index >= this.tracks.length - 1)
            }, (track: MusicTrack) => this.trackRenderKey(track))
          }
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
          .padding({ bottom: this.bottomInset })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.None)
      }
      .width('100%')
      .height('100%')

      if (this.showRenameDialog) {
        this.renameDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
