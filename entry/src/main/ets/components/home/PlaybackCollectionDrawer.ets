import {
  AppThemeAppearance,
  CustomPlaylist,
  MusicTrack,
  PlaybackCollectionKind,
  PlaybackCollectionSummary
} from '../../models/AppModels';
import { t } from '../../utils/I18nUtil';
import { customPlaylistIdFromCollectionId, isCustomPlaybackCollectionId } from '../../utils/PlaybackCollectionUtils';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct PlaybackCollectionDrawer {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop activeCollectionId: string = '';
  @Prop allCollection: PlaybackCollectionSummary = {
    id: '',
    title: '',
    subtitle: '',
    trackCount: 0,
    kind: PlaybackCollectionKind.All
  };
  @Prop favoriteCollection: PlaybackCollectionSummary = {
    id: '',
    title: '',
    subtitle: '',
    trackCount: 0,
    kind: PlaybackCollectionKind.Favorites
  };
  @Prop albumCollections: PlaybackCollectionSummary[] = [];
  @Prop artistCollections: PlaybackCollectionSummary[] = [];
  @Prop customCollections: PlaybackCollectionSummary[] = [];
  @Prop importedTracks: MusicTrack[] = [];
  @Prop customPlaylists: CustomPlaylist[] = [];
  @Prop showAlbumCollections: boolean = false;
  @Prop showArtistCollections: boolean = false;
  @State showCreateInput: boolean = false;
  @State newPlaylistName: string = '';
  onClose: () => void = () => {};
  onSelectCollection: (collectionId: string) => void = (_: string) => {};
  onCreateCustomPlaylist: (name: string) => void = (_: string) => {};
  onDeleteCustomPlaylist: (playlistId: string) => void = (_: string) => {};
  onToggleAlbumCollections: (expanded: boolean) => void = (_: boolean) => {};
  onToggleArtistCollections: (expanded: boolean) => void = (_: boolean) => {};
  onToggleTrackInCustomPlaylist: (playlistId: string, trackId: string) => void = (_: string, __: string) => {};

  private isCollectionActive(collectionId: string): boolean {
    return this.activeCollectionId === collectionId;
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private activeCustomPlaylistId(): string {
    return customPlaylistIdFromCollectionId(this.activeCollectionId);
  }

  private activeCustomPlaylist(): CustomPlaylist | undefined {
    let playlistId = this.activeCustomPlaylistId();
    return this.customPlaylists.find((playlist: CustomPlaylist) => playlist.id === playlistId);
  }

  private isTrackInActiveCustomPlaylist(trackId: string): boolean {
    let playlist = this.activeCustomPlaylist();
    return playlist ? playlist.trackIds.indexOf(trackId) >= 0 : false;
  }

  private customTrackKey(track: MusicTrack): string {
    return `${this.activeCustomPlaylistId()}_${track.id}`;
  }

  private drawerItemBackground(active: boolean): string {
    return active ? this.theme().floatingActiveSurface : this.theme().panelSecondaryBackground;
  }

  private drawerItemBorder(active: boolean): string {
    return active ? this.theme().accentSoftBorder : this.theme().divider;
  }

  private foldIndicatorBackground(expanded: boolean): string {
    return expanded ? this.theme().accentSoftBackground : this.theme().controlSecondaryBackground;
  }

  private foldIndicatorBorder(expanded: boolean): string {
    return expanded ? this.theme().accentSoftBorder : this.theme().controlSecondaryBorder;
  }

  private foldActionBackground(expanded: boolean): string {
    return expanded ? this.theme().accentSoftBackground : this.theme().controlSecondaryBackground;
  }

  private foldActionBorder(expanded: boolean): string {
    return expanded ? this.theme().accentSoftBorder : this.theme().controlSecondaryBorder;
  }

  private submitCreatePlaylist(): void {
    let playlistName = this.newPlaylistName.trim();
    if (playlistName.length === 0) {
      return;
    }
    this.onCreateCustomPlaylist(playlistName);
    this.newPlaylistName = '';
    this.showCreateInput = false;
  }

  @Builder
  private drawerHeader() {
    Row() {
      Text(t('collection.play_queue'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme().primaryText)
      Blank()
      Text(t('common.close'))
        .fontSize(14)
        .fontColor(this.theme().accent)
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 18, bottom: 10 })
  }

  @Builder
  private sectionTitle(title: string, actionTitle: string = '', action: () => void = () => {}) {
    Row() {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme().secondaryText)
      Blank()
      if (actionTitle.length > 0) {
        Text(actionTitle)
          .fontSize(12)
          .fontColor(this.theme().accent)
          .onClick(() => {
            action();
          })
      }
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 8, bottom: 8 })
  }

  @Builder
  private collectionRow(summary: PlaybackCollectionSummary, allowDelete: boolean = false, deleteAction: () => void = () => {}) {
    Column() {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(summary.title)
            .fontSize(15)
            .fontWeight(this.isCollectionActive(summary.id) ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.theme().primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(summary.subtitle)
            .fontSize(11)
            .fontColor(this.theme().secondaryText)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (allowDelete) {
          Row() {
            Image($r('app.media.ic_trash'))
              .width(15)
              .height(15)
              .fillColor(this.theme().dangerText)
          }
          .width(28)
          .height(28)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.theme().dangerBackground)
          .borderRadius(14)
          .border({
            width: 1,
            color: this.theme().dangerText
          })
          .onClick(() => {
            deleteAction();
          })
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 12, bottom: 12 })
      .backgroundColor(this.drawerItemBackground(this.isCollectionActive(summary.id)))
      .borderRadius(16)
      .border({
        width: 1,
        color: this.drawerItemBorder(this.isCollectionActive(summary.id))
      })
      .onClick(() => {
        this.onSelectCollection(summary.id);
      })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 4 })
  }

  @Builder
  private albumFoldableSection() {
    Column() {
      Row({ space: 12 }) {
        Row() {
          Image($r('app.media.ic_chevron_right'))
            .width(13)
            .height(13)
            .fillColor(this.showAlbumCollections ? this.theme().accent : this.theme().secondaryText)
            .rotate({
              angle: this.showAlbumCollections ? 90 : 0,
              x: 0,
              y: 0,
              z: 1,
              centerX: '50%',
              centerY: '50%'
            })
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.foldIndicatorBackground(this.showAlbumCollections))
        .borderRadius(14)
        .border({
          width: 1,
          color: this.foldIndicatorBorder(this.showAlbumCollections)
        })

        Column({ space: 2 }) {
          Text(t('collection.by_album'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme().primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`${this.albumCollections.length}${t('common.unit_group')}`)
            .fontSize(11)
            .fontColor(this.theme().secondaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text(this.showAlbumCollections ? t('common.collapse') : t('common.expand'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.showAlbumCollections ? this.theme().accent : this.theme().secondaryText)
            .maxLines(1)
        }
        .width(58)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.foldActionBackground(this.showAlbumCollections))
        .borderRadius(14)
        .border({
          width: 1,
          color: this.foldActionBorder(this.showAlbumCollections)
        })
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.drawerItemBackground(this.showAlbumCollections))
      .borderRadius(16)
      .border({
        width: 1,
        color: this.drawerItemBorder(this.showAlbumCollections)
      })
      .onClick(() => {
        this.onToggleAlbumCollections(!this.showAlbumCollections);
      })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 4 })
  }

  @Builder
  private artistFoldableSection() {
    Column() {
      Row({ space: 12 }) {
        Row() {
          Image($r('app.media.ic_chevron_right'))
            .width(13)
            .height(13)
            .fillColor(this.showArtistCollections ? this.theme().accent : this.theme().secondaryText)
            .rotate({
              angle: this.showArtistCollections ? 90 : 0,
              x: 0,
              y: 0,
              z: 1,
              centerX: '50%',
              centerY: '50%'
            })
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.foldIndicatorBackground(this.showArtistCollections))
        .borderRadius(14)
        .border({
          width: 1,
          color: this.foldIndicatorBorder(this.showArtistCollections)
        })

        Column({ space: 2 }) {
          Text(t('collection.by_artist'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme().primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`${this.artistCollections.length}${t('common.unit_group')}`)
            .fontSize(11)
            .fontColor(this.theme().secondaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text(this.showArtistCollections ? t('common.collapse') : t('common.expand'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.showArtistCollections ? this.theme().accent : this.theme().secondaryText)
            .maxLines(1)
        }
        .width(58)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.foldActionBackground(this.showArtistCollections))
        .borderRadius(14)
        .border({
          width: 1,
          color: this.foldActionBorder(this.showArtistCollections)
        })
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(this.drawerItemBackground(this.showArtistCollections))
      .borderRadius(16)
      .border({
        width: 1,
        color: this.drawerItemBorder(this.showArtistCollections)
      })
      .onClick(() => {
        this.onToggleArtistCollections(!this.showArtistCollections);
      })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 4 })
  }

  @Builder
  private createPlaylistInput() {
    Row({ space: 8 }) {
      TextInput({ text: this.newPlaylistName, placeholder: t('home.input_playlist_name') })
        .layoutWeight(1)
        .height(38)
        .placeholderColor(this.theme().tertiaryText)
        .fontSize(14)
        .fontColor(this.theme().primaryText)
        .backgroundColor(this.theme().inputBackground)
        .caretColor(this.theme().accent)
        .borderRadius(12)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.newPlaylistName = value;
        })

      Text(t('common.cancel'))
        .fontSize(12)
        .fontColor(this.theme().secondaryText)
        .onClick(() => {
          this.showCreateInput = false;
          this.newPlaylistName = '';
        })

      Text(t('common.create'))
        .fontSize(12)
        .fontColor(this.theme().accent)
        .onClick(() => {
          this.submitCreatePlaylist();
        })
    }
    .width('100%')
    .padding({ left: 22, right: 22, bottom: 6 })
  }

  @Builder
  private customTrackRow(track: MusicTrack) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(track.title)
          .fontSize(14)
          .fontColor(this.theme().primaryText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(track.artist)
          .fontSize(11)
          .fontColor(this.theme().secondaryText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Image(this.isTrackInActiveCustomPlaylist(track.id) ? $r('app.media.ic_minus') : $r('app.media.ic_plus'))
          .width(15)
          .height(15)
          .fillColor(this.isTrackInActiveCustomPlaylist(track.id) ? this.theme().warningText : this.theme().accent)
      }
      .width(30)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.isTrackInActiveCustomPlaylist(track.id) ? this.theme().warningBackground : this.theme().accentSoftBackground)
      .borderRadius(15)
      .border({
        width: 1,
        color: this.isTrackInActiveCustomPlaylist(track.id) ? this.theme().warningText : this.theme().accentSoftBorder
      })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 10, bottom: 10 })
    .onClick(() => {
      let playlistId = this.activeCustomPlaylistId();
      if (playlistId.length > 0) {
        this.onToggleTrackInCustomPlaylist(playlistId, track.id);
      }
    })
  }

  @Builder
  private customPlaylistEditor() {
    if (this.activeCustomPlaylistId().length > 0) {
      Column({ space: 0 }) {
        this.sectionTitle(t('home.manage_tracks'))
        if (this.importedTracks.length === 0) {
          Text(t('home.no_imported'))
            .fontSize(12)
            .fontColor(this.theme().secondaryText)
            .width('100%')
            .padding({ left: 22, right: 22, top: 4, bottom: 12 })
        } else {
          ForEach(this.importedTracks, (track: MusicTrack, index: number) => {
            Column() {
              this.customTrackRow(track)
              if (index < this.importedTracks.length - 1) {
                Row()
                  .width('100%')
                  .height(1)
                  .backgroundColor(this.theme().divider)
                  .margin({ left: 22, right: 22 })
              }
            }
          }, (track: MusicTrack) => this.customTrackKey(track))
        }
      }
      .width('100%')
      .padding({ bottom: 22 })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme().maskBackground)
        .onClick(() => {
          this.onClose();
        })

      Column({ space: 0 }) {
        this.drawerHeader()
        Scroll() {
          Column({ space: 0 }) {
            this.sectionTitle(t('collection.builtin'))
            this.collectionRow(this.allCollection)
            this.collectionRow(this.favoriteCollection)

            this.albumFoldableSection()
            if (this.showAlbumCollections) {
              ForEach(this.albumCollections, (summary: PlaybackCollectionSummary) => {
                this.collectionRow(summary)
              }, (summary: PlaybackCollectionSummary) => summary.id)
            }

            this.artistFoldableSection()
            if (this.showArtistCollections) {
              ForEach(this.artistCollections, (summary: PlaybackCollectionSummary) => {
                this.collectionRow(summary)
              }, (summary: PlaybackCollectionSummary) => summary.id)
            }

            this.sectionTitle(t('collection.custom'), this.showCreateInput ? '' : t('collection.new_playlist'), () => {
              this.showCreateInput = true;
            })
            if (this.showCreateInput) {
              this.createPlaylistInput()
            }
            if (this.customCollections.length === 0) {
              Text(t('home.no_custom_playlist'))
                .fontSize(12)
                .fontColor(this.theme().secondaryText)
                .width('100%')
                .padding({ left: 22, right: 22, top: 4, bottom: 12 })
            } else {
              ForEach(this.customCollections, (summary: PlaybackCollectionSummary) => {
                this.collectionRow(
                  summary,
                  true,
                  () => {
                    this.onDeleteCustomPlaylist(customPlaylistIdFromCollectionId(summary.id));
                  }
                )
              }, (summary: PlaybackCollectionSummary) => summary.id)
            }

            if (isCustomPlaybackCollectionId(this.activeCollectionId)) {
              this.customPlaylistEditor()
            } else {
              Row().height(18)
            }
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
      }
      .width('82%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(this.theme().panelBackground)
      .borderRadius({ topRight: 26, bottomRight: 26 })
      .shadow({
        radius: 24,
        color: this.themeAppearance === AppThemeAppearance.Dark ? '#00000066' : '#0B1F2A22',
        offsetX: 6,
        offsetY: 0
      })
    }
    .width('100%')
    .height('100%')
  }
}
