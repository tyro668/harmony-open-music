import { DEFAULT_PLAYBACK_COLLECTION_ID, MAX_RECENT_TRACKS, MINI_PLACEHOLDER_TRACK } from '../constants/AppConstants';
import { CollectionMode, CustomPlaylist, LibraryDimension, MainTab, MusicTrack, PlayMode } from '../models/AppModels';
import { copyTrack, formatDurationMs } from '../utils/TrackUtils';
import { moveTrackByReference } from '../utils/LibraryStateUtils';
import {
  albumPlaybackCollectionSummaries,
  allPlaybackCollectionSummary,
  artistPlaybackCollectionSummaries,
  buildCustomPlaybackCollectionId,
  customPlaybackCollectionSummaries,
  favoritePlaybackCollectionSummary,
  playbackCollectionExists,
  playbackCollectionSelectorSummaries,
  playbackCollectionSummaryById,
  playbackCollectionTracks,
  trackBelongsToPlaybackCollection
} from '../utils/PlaybackCollectionUtils';
import {
  createCustomPlaylist,
  removeCustomPlaylist,
  removeTracksFromCustomPlaylists,
  toggleTrackInCustomPlaylist
} from '../services/CustomPlaylistService';
import { t } from '../utils/I18nUtil';
import { BaseViewModel } from './BaseViewModel';

class RemoveImportResult {
  shouldReleasePlayer: boolean = false;
  constructor(shouldReleasePlayer: boolean) {
    this.shouldReleasePlayer = shouldReleasePlayer;
  }
}

@Observed
export class LibraryState {
  localTracks: Array<MusicTrack> = [];
  recentTrackIds: Array<string> = [];
  currentTrackId: string = MINI_PLACEHOLDER_TRACK.id;
  activePlaybackCollectionId: string = DEFAULT_PLAYBACK_COLLECTION_ID;
  playbackDrawerShowAlbumCollections: boolean = false;
  playbackDrawerShowArtistCollections: boolean = false;
  customPlaylists: CustomPlaylist[] = [];
  collectionMode: CollectionMode = CollectionMode.Library;
  activeLibraryDimension: LibraryDimension = LibraryDimension.Song;
  searchKeyword: string = '';
  showPlaybackCollectionDrawer: boolean = false;
  showRenameDialog: boolean = false;
  renameTrackId: string = '';
  renameText: string = '';
  showTrackMenu: boolean = false;
  menuTrackId: string = '';
  totalListeningMs: number = 0;
  playMode: PlayMode = PlayMode.Sequential;
  activeMainTab: MainTab = MainTab.Home;
}

export class LibraryViewModel extends BaseViewModel {
  // Callbacks
  onStateChanged: (() => void) | null = null;
  onCurrentTrackChanged: ((trackId: string) => void) | null = null;
  onAVSessionUpdateNeeded: (() => void) | null = null;

  private notifyStateChanged(): void {
    if (this.onStateChanged) {
      this.onStateChanged();
    }
  }

  playQueueTracks(state: LibraryState): Array<MusicTrack> {
    return playbackCollectionTracks(state.localTracks, state.customPlaylists, state.activePlaybackCollectionId);
  }

  filteredPlayQueueTracks(state: LibraryState): Array<MusicTrack> {
    let tracks = this.playQueueTracks(state);
    let keyword = state.searchKeyword.trim().toLowerCase();
    if (keyword.length === 0) return tracks;
    return tracks.filter((track: MusicTrack) => {
      let target = `${track.title} ${track.artist} ${track.album}`.toLowerCase();
      return target.indexOf(keyword) >= 0;
    });
  }

  activePlaybackCollectionTitle(state: LibraryState): string {
    return playbackCollectionSummaryById(state.localTracks, state.customPlaylists, state.activePlaybackCollectionId).title;
  }

  ensureActivePlaybackCollectionValid(state: LibraryState): void {
    if (!playbackCollectionExists(state.localTracks, state.customPlaylists, state.activePlaybackCollectionId)) {
      state.activePlaybackCollectionId = DEFAULT_PLAYBACK_COLLECTION_ID;
    }
  }

  syncCurrentTrackSelection(state: LibraryState, preferredTrackId: string = '', loadedTrackId: string = ''): void {
    this.ensureActivePlaybackCollectionValid(state);
    let current = state.localTracks.find((track: MusicTrack) => track.id === state.currentTrackId);
    if (current) {
      let isCurrentLoaded = loadedTrackId === current.id;
      if (trackBelongsToPlaybackCollection(current.id, state.localTracks, state.customPlaylists, state.activePlaybackCollectionId) || isCurrentLoaded) {
        return;
      }
    }
    if (preferredTrackId.length > 0) {
      let preferredTrack = state.localTracks.find((track: MusicTrack) => track.id === preferredTrackId);
      if (preferredTrack && trackBelongsToPlaybackCollection(preferredTrack.id, state.localTracks, state.customPlaylists, state.activePlaybackCollectionId)) {
        state.currentTrackId = preferredTrack.id;
        return;
      }
    }
    let queueTracks = this.playQueueTracks(state);
    let firstTrack = queueTracks.length > 0 ? queueTracks[0] : null;
    state.currentTrackId = firstTrack ? firstTrack.id : MINI_PLACEHOLDER_TRACK.id;
  }

  selectPlaybackCollection(state: LibraryState, collectionId: string, loadedTrackId: string = ''): void {
    state.activePlaybackCollectionId = collectionId;
    this.ensureActivePlaybackCollectionValid(state);
    this.syncCurrentTrackSelection(state, '', loadedTrackId);
    this.notifyStateChanged();
    this.schedulePersist();
  }

  createPlaybackCustomPlaylist(state: LibraryState, name: string, loadedTrackId: string = ''): void {
    let result = createCustomPlaylist(state.customPlaylists, name);
    if (result.createdPlaylistId.length === 0) { this.showToast(t('import.playlist_name_required')); return; }
    state.customPlaylists = result.playlists;
    state.activePlaybackCollectionId = buildCustomPlaybackCollectionId(result.createdPlaylistId);
    this.syncCurrentTrackSelection(state, '', loadedTrackId);
    this.notifyStateChanged();
    this.schedulePersist();
    this.showToast(t('import.playlist_created'));
  }

  deletePlaybackCustomPlaylist(state: LibraryState, playlistId: string, loadedTrackId: string = ''): void {
    let result = removeCustomPlaylist(state.customPlaylists, playlistId);
    if (!result.removed) return;
    state.customPlaylists = result.playlists;
    this.ensureActivePlaybackCollectionValid(state);
    this.syncCurrentTrackSelection(state, '', loadedTrackId);
    this.notifyStateChanged();
    this.schedulePersist();
    this.showToast(t('import.playlist_deleted'));
  }

  toggleTrackInPlaybackCustomPlaylist(state: LibraryState, playlistId: string, trackId: string, loadedTrackId: string = ''): void {
    let result = toggleTrackInCustomPlaylist(state.customPlaylists, playlistId, trackId);
    state.customPlaylists = result.playlists;
    this.syncCurrentTrackSelection(state, '', loadedTrackId);
    this.notifyStateChanged();
    this.schedulePersist();
    this.showToast(result.included ? t('import.playlist_added') : t('import.playlist_removed'));
  }

  toggleTrackInPlayQueue(state: LibraryState, trackId: string, loadedTrackId: string = ''): void {
    let trackIndex = state.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (trackIndex < 0) return;
    let updatedTracks = state.localTracks.slice();
    let selectedTrack = copyTrack(updatedTracks[trackIndex]);
    selectedTrack.inPlayQueue = !selectedTrack.inPlayQueue;
    updatedTracks[trackIndex] = selectedTrack;
    state.localTracks = updatedTracks;
    if (selectedTrack.inPlayQueue) {
      this.syncCurrentTrackSelection(state, selectedTrack.id, loadedTrackId);
    } else {
      this.syncCurrentTrackSelection(state, '', loadedTrackId);
    }
    this.ensureActivePlaybackCollectionValid(state);
    this.notifyStateChanged();
    this.schedulePersist();
    this.showToast(selectedTrack.inPlayQueue
      ? t('import.queue_track_added', selectedTrack.title)
      : t('import.queue_track_removed', selectedTrack.title));
  }

  moveImportedTrackBefore(state: LibraryState, trackId: string, referenceTrackId: string): void {
    let nextTracks = moveTrackByReference(state.localTracks, trackId, referenceTrackId, false);
    if (nextTracks === state.localTracks) return;
    state.localTracks = nextTracks;
    this.notifyStateChanged();
    this.schedulePersist();
  }

  moveImportedTrackAfter(state: LibraryState, trackId: string, referenceTrackId: string): void {
    let nextTracks = moveTrackByReference(state.localTracks, trackId, referenceTrackId, true);
    if (nextTracks === state.localTracks) return;
    state.localTracks = nextTracks;
    this.notifyStateChanged();
    this.schedulePersist();
  }

  async removeImportedTracks(state: LibraryState, trackIds: string[], loadedTrackId: string = ''): Promise<RemoveImportResult> {
    let targetIds = trackIds.filter((trackId: string, index: number) => trackId.length > 0 && trackIds.indexOf(trackId) === index);
    if (targetIds.length === 0) return new RemoveImportResult(false);
    let removedTracks = state.localTracks.filter((item: MusicTrack) => targetIds.indexOf(item.id) >= 0);
    if (removedTracks.length === 0) return new RemoveImportResult(false);
    let shouldReleaseCurrent = removedTracks.some((track: MusicTrack) => track.id === loadedTrackId);
    state.localTracks = state.localTracks.filter((item: MusicTrack) => targetIds.indexOf(item.id) < 0);
    state.customPlaylists = removeTracksFromCustomPlaylists(state.customPlaylists, targetIds);
    state.recentTrackIds = state.recentTrackIds.filter((itemId: string) => targetIds.indexOf(itemId) < 0);
    if (targetIds.indexOf(state.renameTrackId) >= 0) { state.showRenameDialog = false; state.renameTrackId = ''; state.renameText = ''; }
    if (targetIds.indexOf(state.menuTrackId) >= 0) { state.showTrackMenu = false; state.menuTrackId = ''; }
    if (targetIds.indexOf(state.currentTrackId) >= 0) { state.currentTrackId = MINI_PLACEHOLDER_TRACK.id; }
    this.ensureActivePlaybackCollectionValid(state);
    this.syncCurrentTrackSelection(state, '', '');
    this.notifyStateChanged();
    this.schedulePersist();
    if (removedTracks.length === 1) this.showToast(t('import.track_removed', removedTracks[0].title));
    else this.showToast(t('import.batch_removed', `${removedTracks.length}`));
    return new RemoveImportResult(shouldReleaseCurrent);
  }

  toggleFavorite(state: LibraryState, trackId: string): void {
    let localIndex = state.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (localIndex >= 0) {
      let updatedTracks = state.localTracks.slice();
      let selectedTrack = copyTrack(updatedTracks[localIndex]);
      selectedTrack.isFavorite = !selectedTrack.isFavorite;
      updatedTracks[localIndex] = selectedTrack;
      state.localTracks = updatedTracks;
      this.ensureActivePlaybackCollectionValid(state);
      this.syncCurrentTrackSelection(state);
      this.notifyStateChanged();
      this.schedulePersist();
      this.showToast(updatedTracks[localIndex].isFavorite ? t('import.favorite_added') : t('import.favorite_removed'));
      if (trackId === state.currentTrackId && this.onAVSessionUpdateNeeded) {
        this.onAVSessionUpdateNeeded();
      }
    }
  }

  applyRename(state: LibraryState): void {
    let newTitle = state.renameText.trim();
    if (newTitle.length === 0) { this.showToast(t('import.name_required')); return; }
    let localIndex = state.localTracks.findIndex((track: MusicTrack) => track.id === state.renameTrackId);
    if (localIndex >= 0) {
      let updatedTracks = state.localTracks.slice();
      let updatedTrack = copyTrack(updatedTracks[localIndex]);
      updatedTrack.title = newTitle;
      updatedTracks[localIndex] = updatedTrack;
      state.localTracks = updatedTracks;
      this.notifyStateChanged();
      this.schedulePersist();
      this.showToast(t('import.name_changed'));
    }
    state.showRenameDialog = false;
    state.renameTrackId = '';
    state.renameText = '';
  }

  pushRecentTrack(state: LibraryState, trackId: string): void {
    let nextRecent = state.recentTrackIds.filter((id: string) => id !== trackId);
    nextRecent.unshift(trackId);
    state.recentTrackIds = nextRecent.slice(0, MAX_RECENT_TRACKS);
    this.notifyStateChanged();
    this.schedulePersist();
  }

  trackDurationText(state: LibraryState, track: MusicTrack, playbackDurationMs: number): string {
    if (track.id === state.currentTrackId && playbackDurationMs > 0) return formatDurationMs(playbackDurationMs);
    if (track.durationMs > 0) return formatDurationMs(track.durationMs);
    return '--:--';
  }

  currentTrackIsFavorite(state: LibraryState): boolean {
    let track = state.localTracks.find((t: MusicTrack) => t.id === state.currentTrackId);
    return track ? track.isFavorite : false;
  }

  resolveAdjacentTrackIds(state: LibraryState, trackId: string): string[] {
    let queueTracks = this.playQueueTracks(state);
    if (queueTracks.length === 0) return ['', ''];
    let index = queueTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (index < 0) return ['', ''];
    let prevIndex = (index + queueTracks.length - 1) % queueTracks.length;
    let nextIndex = (index + 1) % queueTracks.length;
    return [queueTracks[prevIndex].id, queueTracks[nextIndex].id];
  }

  playNextTrackIndex(state: LibraryState): number {
    let queueTracks = this.playQueueTracks(state);
    if (queueTracks.length === 0) return -1;
    let index = queueTracks.findIndex((track: MusicTrack) => track.id === state.currentTrackId);
    if (state.playMode === PlayMode.Shuffle) {
      let randomIndex = Math.floor(Math.random() * queueTracks.length);
      if (queueTracks.length > 1 && randomIndex === index) randomIndex = (randomIndex + 1) % queueTracks.length;
      return randomIndex;
    } else if (state.playMode === PlayMode.Loop) {
      return index >= 0 ? index : 0;
    } else {
      return index >= 0 ? (index + 1) % queueTracks.length : 0;
    }
  }

  playPreviousTrackIndex(state: LibraryState): number {
    let queueTracks = this.playQueueTracks(state);
    if (queueTracks.length === 0) return -1;
    let index = queueTracks.findIndex((track: MusicTrack) => track.id === state.currentTrackId);
    if (state.playMode === PlayMode.Shuffle) {
      let randomIndex = Math.floor(Math.random() * queueTracks.length);
      if (queueTracks.length > 1 && randomIndex === index) randomIndex = (randomIndex + queueTracks.length - 1) % queueTracks.length;
      return randomIndex;
    } else if (state.playMode === PlayMode.Loop) {
      return index >= 0 ? index : 0;
    } else {
      return index >= 0 ? (index + queueTracks.length - 1) % queueTracks.length : 0;
    }
  }
}
