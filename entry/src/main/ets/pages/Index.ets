import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { picker, fileUri } from '@kit.CoreFileKit';
import { relationalStore } from '@kit.ArkData';
import fs from '@ohos.file.fs';
import {
  APP_BUNDLE_NAME, APP_ENTRY_ABILITY_NAME, AUDIO_FILTERS, LISTENING_SEED_MS,
  MINI_PLACEHOLDER_TRACK
} from '../constants/AppConstants';
import {
  AppThemeAppearance, AppThemeMode, CollectionMode, CustomPlaylist, LibraryDimension,
  MainTab, BaiduPanEntry, MusicSourceConfig, MusicSourceQuality, MusicSourceTrack,
  MusicTrack, PlayMode, PlaybackCollectionSummary, SourceBoardItem
} from '../models/AppModels';
import { ExploreHallPage } from '../components/explore/ExploreHallPage';
import { HomeQueuePage } from '../components/home/HomeQueuePage';
import { PlaybackCollectionDrawer } from '../components/home/PlaybackCollectionDrawer';
import { ImportedTrackManagerPanel } from '../components/profile/ImportedTrackManagerPanel';
import { BaiduPanAuthPanel } from '../components/profile/BaiduPanAuthPanel';
import { BaiduPanImportPanel } from '../components/profile/BaiduPanImportPanel';
import { ProfilePageContent } from '../components/profile/ProfilePageContent';
import { ThemeModePanel } from '../components/profile/ThemeModePanel';
import { BottomNavigationBar } from '../components/shell/BottomNavigationBar';
import { MiniPlayerBar } from '../components/shell/MiniPlayerBar';
import { LyricsPanel } from '../components/shell/LyricsPanel';
import { SourceBrowserPanel } from '../components/source/SourceBrowserPanel';
import { SourceManagerPanel } from '../components/source/SourceManagerPanel';
import { SourceUpdateAlertDialog } from '../components/source/SourceUpdateAlertDialog';
import { CarPlayerBar } from '../components/car/CarPlayerBar';
import { CarTrackList } from '../components/car/CarTrackList';
import { currentTrack as selectCurrentTrack, playbackProgressRatio, totalListeningSummaryText } from '../utils/LibraryStateUtils';
import {
  albumPlaybackCollectionSummaries, allPlaybackCollectionSummary, artistPlaybackCollectionSummaries,
  customPlaybackCollectionSummaries, favoritePlaybackCollectionSummary, playbackCollectionSelectorSummaries
} from '../utils/PlaybackCollectionUtils';
import { buildImportedTrack, copyTrack, sanitizeFileName } from '../utils/TrackUtils';
import { filterSupportedExploreSources, sourceDisplayName, sourceQualityDisplayName } from '../utils/MusicSourceUtils';
import { appThemeModeLabel, appThemePalette } from '../utils/ThemeUtils';
import { t } from '../utils/I18nUtil';
import {
  ensureAppDatabase, persistAppState, persistAppStateSync, restorePersistedAppState,
  deleteMusicSourceScript as deletePersistedMusicSourceScript, readMusicSourceScript,
  appendPlaybackRecord, PlaybackRecordEntry, PersistableAppState
} from '../services/AppStatePersistenceService';
import { resolvePreferredSubSource } from '../services/CustomSourceCatalogService';
import { savePixelMapToFile } from '../services/TrackArtworkService';
import { PlaybackViewModel, PlaybackState } from '../viewmodels/PlaybackViewModel';
import { AppShellViewModel, AppShellState } from '../viewmodels/AppShellViewModel';
import { SourceViewModel, SourceState } from '../viewmodels/SourceViewModel';
import { ExploreViewModel, ExploreState } from '../viewmodels/ExploreViewModel';
import { LibraryViewModel, LibraryState } from '../viewmodels/LibraryViewModel';
import { BaiduPanViewModel, BaiduPanState } from '../viewmodels/BaiduPanViewModel';
import { LyricViewModel, LyricState } from '../viewmodels/LyricViewModel';
import { TrackMetadataViewModel, TrackMetadataState } from '../viewmodels/TrackMetadataViewModel';

@Entry
@Component
struct Index {
  private readonly pageBottomInset: number = 0;
  private readonly phoneBottomOverlayHeight: number = 180;
  @StorageProp('isCarMode') isCarMode: boolean = false;

  // ViewModel instances
  private playbackVm: PlaybackViewModel = new PlaybackViewModel();
  private shellVm: AppShellViewModel = new AppShellViewModel();
  private sourceVm: SourceViewModel = new SourceViewModel();
  private exploreVm: ExploreViewModel = new ExploreViewModel();
  private libraryVm: LibraryViewModel = new LibraryViewModel();
  private baiduPanVm: BaiduPanViewModel = new BaiduPanViewModel();
  private lyricVm: LyricViewModel = new LyricViewModel();
  private metadataVm: TrackMetadataViewModel = new TrackMetadataViewModel();

  // ViewModel states
  @State playback: PlaybackState = new PlaybackState();
  @State shell: AppShellState = new AppShellState();
  @State source: SourceState = new SourceState();
  @State explore: ExploreState = new ExploreState();
  @State library: LibraryState = new LibraryState();
  @State baiduPan: BaiduPanState = new BaiduPanState();
  @State lyric: LyricState = new LyricState();
  @State metadata: TrackMetadataState = new TrackMetadataState();

  // Additional UI-only state
  @State showImportedTrackManager: boolean = false;
  @State showThemeModePanel: boolean = false;
  @State isRestoringState: boolean = false;
  private hasInitializedState: boolean = false;
  private isPersistingState: boolean = false;
  private pendingPersistState: boolean = false;
  private appDatabase: relationalStore.RdbStore | null = null;

  private refreshExploreState(state: ExploreState = this.explore): void {
    let nextState = new ExploreState();
    nextState.activeSourceId = state.activeSourceId;
    nextState.activeSearchSource = state.activeSearchSource;
    nextState.sourceTracks = state.sourceTracks;
    nextState.sourceTracksLoading = state.sourceTracksLoading;
    nextState.sourceSearchKeyword = state.sourceSearchKeyword;
    nextState.sourceCurrentPage = state.sourceCurrentPage;
    nextState.sourceTotal = state.sourceTotal;
    nextState.sourceImportingTrackKeys = state.sourceImportingTrackKeys;
    nextState.sourceBoardList = state.sourceBoardList;
    nextState.sourceBoardsLoading = state.sourceBoardsLoading;
    nextState.activeBoardId = state.activeBoardId;
    nextState.exploreMode = state.exploreMode;
    nextState.showSourceBrowser = state.showSourceBrowser;
    this.explore = nextState;
  }

  private refreshLibraryState(): void {
    let nextState = new LibraryState();
    nextState.localTracks = this.library.localTracks;
    nextState.recentTrackIds = this.library.recentTrackIds;
    nextState.currentTrackId = this.library.currentTrackId;
    nextState.activePlaybackCollectionId = this.library.activePlaybackCollectionId;
    nextState.playbackDrawerShowAlbumCollections = this.library.playbackDrawerShowAlbumCollections;
    nextState.playbackDrawerShowArtistCollections = this.library.playbackDrawerShowArtistCollections;
    nextState.customPlaylists = this.library.customPlaylists;
    nextState.collectionMode = this.library.collectionMode;
    nextState.activeLibraryDimension = this.library.activeLibraryDimension;
    nextState.searchKeyword = this.library.searchKeyword;
    nextState.showPlaybackCollectionDrawer = this.library.showPlaybackCollectionDrawer;
    nextState.showRenameDialog = this.library.showRenameDialog;
    nextState.renameTrackId = this.library.renameTrackId;
    nextState.renameText = this.library.renameText;
    nextState.showTrackMenu = this.library.showTrackMenu;
    nextState.menuTrackId = this.library.menuTrackId;
    nextState.totalListeningMs = this.library.totalListeningMs;
    nextState.playMode = this.library.playMode;
    nextState.activeMainTab = this.library.activeMainTab;
    this.library = nextState;
  }

  aboutToAppear(): void {
    this.bindAllViewModels();
    this.shellVm.applyThemeMode(this.shell, this.shell.appThemeMode, false);
    if (this.hasInitializedState) return;
    this.hasInitializedState = true;
    void this.initializeAppState();
    void this.shellVm.ensureIdleAVSession();
  }

  aboutToDisappear(): void {
    this.flushPersistStateNow();
  }

  private bindAllViewModels(): void {
    let showToast = (msg: string) => this.showToast(msg);
    let schedulePersist = () => this.schedulePersistState();
    let getContext = () => this.getUIContext().getHostContext() as common.UIAbilityContext;

    this.playbackVm.bindDependencies(showToast, schedulePersist, getContext);
    this.shellVm.bindDependencies(showToast, schedulePersist, getContext);
    this.sourceVm.bindDependencies(showToast, schedulePersist, getContext);
    this.exploreVm.bindDependencies(showToast, schedulePersist, getContext);
    this.libraryVm.bindDependencies(showToast, schedulePersist, getContext);
    this.baiduPanVm.bindDependencies(showToast, schedulePersist, getContext);
    this.lyricVm.bindDependencies(showToast, schedulePersist, getContext);
    this.metadataVm.bindDependencies(showToast, schedulePersist, getContext);

    // Cross-ViewModel callbacks
    this.playbackVm.onPlaybackStateChanged = (playing: boolean) => {
      this.shellVm.updateAVSessionState(playing, this.playback.playbackProgressMs, this.playback.playbackDurationMs, this.library.playMode, this.libraryVm.currentTrackIsFavorite(this.library));
      this.shellVm.updateMusicLiveView(playing, this.currentTrack(), this.playback.playbackProgressMs, this.playback.playbackDurationMs, this.lyricVm.currentLyricPreviewText(this.lyric), this.lyricVm.currentLyricSecondaryText(this.lyric));
      if (playing) void this.shellVm.startBackgroundTask();
    };
    this.playbackVm.onTrackSwitched = (trackId: string) => {
      this.libraryVm.pushRecentTrack(this.library, trackId);
      let track = this.library.localTracks.find((t: MusicTrack) => t.id === trackId);
      if (track) void this.lyricVm.loadTrackLyrics(this.lyric, track);
    };
    this.playbackVm.onProgressUpdated = (progressMs: number, durationMs: number) => {
      if (this.lyricVm.updateLyricIndex(this.lyric, progressMs)) {
        void this.shellVm.updateMusicLiveView(this.playback.isPlaying, this.currentTrack(), progressMs, durationMs, this.lyricVm.currentLyricPreviewText(this.lyric), this.lyricVm.currentLyricSecondaryText(this.lyric));
      }
    };
    this.playbackVm.onPlaybackCompleted = () => { void this.playNextTrack(); };
    this.playbackVm.onDurationCached = (trackId: string, durationMs: number) => { this.cacheTrackDuration(trackId, durationMs); };
    this.playbackVm.onPlaybackRecordFlush = (trackId: string, startedAt: number, listenedMs: number) => {
      void this.commitPlaybackRecord(trackId, startedAt, listenedMs);
    };
    this.playbackVm.onResumeAfterAudioInterrupt = (trackId: string, progressMs: number) => {
      let track = this.library.localTracks.find((t: MusicTrack) => t.id === trackId);
      if (track) {
        void this.playbackVm.restartTrackPlayerAfterInterrupt(this.playback, track, progressMs);
      }
    };

    this.shellVm.onResumeCurrentTrack = () => void this.playbackVm.resumeCurrentTrack(this.playback);
    this.shellVm.onPauseCurrentTrack = () => void this.playbackVm.pauseCurrentTrack(this.playback);
    this.shellVm.onPlayNextTrack = () => void this.playNextTrack();
    this.shellVm.onPlayPreviousTrack = () => void this.playPreviousTrack();
    this.shellVm.onSeekCurrentTrack = (ms: number) => void this.playbackVm.seekCurrentTrack(this.playback, ms);
    this.shellVm.onToggleFavorite = (assetId: string) => this.libraryVm.toggleFavorite(this.library, assetId);
    this.shellVm.onSetPlayMode = (mode: PlayMode) => {
      this.library.playMode = mode;
      this.refreshLibraryState();
      this.schedulePersistState();
    };
    this.shellVm.onRefreshAVSessionQueue = () => { void this.shellVm.refreshAVSessionQueue(this.library.localTracks, this.library.customPlaylists, this.library.activePlaybackCollectionId); };
    this.shellVm.onRequestTrackArtwork = (trackId: string) => this.metadataVm.trackArtworkForTrack(trackId);

    this.sourceVm.onGetMusicSourceScript = (sourceId: string) => this.getMusicSourceScript(sourceId);
    this.sourceVm.onDeleteMusicSourceScript = (sourceId: string) => this.deleteMusicSourceScript(sourceId);
    this.sourceVm.onGetActiveSourceForUpdateAlert = () => this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.sourceVm.getJsEngineSourceId());
    this.sourceVm.onShowSourceUpdateAlert = (name: string, log: string, url: string) => {
      this.source.sourceUpdateAlertName = name; this.source.sourceUpdateAlertLog = log; this.source.sourceUpdateAlertUrl = url; this.source.showSourceUpdateAlertDialog = true;
    };

    this.exploreVm.onRequestMusicUrl = (source, track, quality) => this.sourceVm.requestMusicUrlFromEngine(this.source, source, track, quality);
    this.exploreVm.onStateChanged = (state: ExploreState) => { this.refreshExploreState(state); };
    this.exploreVm.onGetLocalTracks = () => this.library.localTracks;
    this.exploreVm.onLocalTracksChanged = (tracks) => { this.library.localTracks = tracks; this.refreshLibraryState(); };
    this.exploreVm.onSyncTrackMetadataCaches = () => { this.metadataVm.syncTrackMetadataCaches(this.metadata, this.library.localTracks, this.library.currentTrackId); };

    this.baiduPanVm.onGetLocalTracks = () => this.library.localTracks;
    this.baiduPanVm.onLocalTracksChanged = (tracks) => { this.library.localTracks = tracks; this.refreshLibraryState(); };
    this.baiduPanVm.onSyncTrackMetadataCaches = () => { this.metadataVm.syncTrackMetadataCaches(this.metadata, this.library.localTracks, this.library.currentTrackId); };

    this.libraryVm.onStateChanged = () => { this.refreshLibraryState(); };
    this.libraryVm.onAVSessionUpdateNeeded = () => { void this.shellVm.updateAVSessionState(this.playback.isPlaying, this.playback.playbackProgressMs, this.playback.playbackDurationMs, this.library.playMode, this.libraryVm.currentTrackIsFavorite(this.library)); };

    this.metadataVm.onCurrentTrackArtworkLoaded = async (trackId: string) => {
      let pixelMap = this.metadataVm.trackArtworkForTrack(trackId);
      if (!pixelMap) return;
      let cachePath = this.resolveCoverCachePath(trackId);
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let coverDir = `${context.cacheDir}/covers`;
      try {
        if (!fs.accessSync(coverDir)) {
          fs.mkdirSync(coverDir, true);
        }
        await savePixelMapToFile(pixelMap, cachePath);
        this.shellVm.setCoverArtFilePath(cachePath);
        if (trackId === this.library.currentTrackId) {
          await this.updateSessionCoverArt(trackId);
          await this.shellVm.updateMusicLiveView(this.playback.isPlaying, this.currentTrack(), this.playback.playbackProgressMs, this.playback.playbackDurationMs, this.lyricVm.currentLyricPreviewText(this.lyric), this.lyricVm.currentLyricSecondaryText(this.lyric));
        }
      } catch (error) {
        console.error(`save track artwork failed: ${JSON.stringify(error)}`);
      }
    };
  }

  private currentTrack(): MusicTrack {
    return selectCurrentTrack(this.library.localTracks, this.library.currentTrackId);
  }

  private resolveCoverCachePath(trackId: string): string {
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return `${context.cacheDir}/covers/${trackId}.jpg`;
  }

  private async updateSessionCoverArt(trackId: string): Promise<void> {
    let track = this.library.localTracks.find((t: MusicTrack) => t.id === trackId);
    if (!track) return;
    let navIds = this.libraryVm.resolveAdjacentTrackIds(this.library, trackId);
    await this.shellVm.updateAVSessionCoverArt(track, this.playback.playbackDurationMs, this.libraryVm.currentTrackIsFavorite(this.library), this.library.playMode, this.lyricVm.currentLyricMetadataText(this.lyric), this.lyricVm.currentLyricContentText(this.lyric), this.lyricVm.currentLyricSecondaryText(this.lyric), navIds[0], navIds[1]);
  }

  private theme() {
    return appThemePalette(this.shell.themeAppearance);
  }

  // --- Lifecycle & Persistence ---
  private async initializeAppState(): Promise<void> {
    this.isRestoringState = true;
    try { await this.restorePersistedState(); } catch (error) { console.error(`initialize app state failed: ${JSON.stringify(error)}`); }
    finally { this.isRestoringState = false; }
    this.metadataVm.syncTrackMetadataCaches(this.metadata, this.library.localTracks, this.library.currentTrackId);
  }

  private async ensureAppDatabaseStore(): Promise<relationalStore.RdbStore> {
    if (this.appDatabase !== null) return this.appDatabase;
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.appDatabase = await ensureAppDatabase(this.appDatabase, context);
    return this.appDatabase;
  }

  private async getMusicSourceScript(sourceId: string): Promise<string> {
    let store = await this.ensureAppDatabaseStore();
    return await readMusicSourceScript(store, this.sourceVm.getMusicSourceScripts(), sourceId);
  }

  private async deleteMusicSourceScript(sourceId: string): Promise<void> {
    let store = await this.ensureAppDatabaseStore();
    await deletePersistedMusicSourceScript(store, this.sourceVm.getMusicSourceScripts(), sourceId);
  }

  private async restorePersistedState(): Promise<void> {
    let store = await this.ensureAppDatabaseStore();
    let restoredState = await restorePersistedAppState(store);
    this.library.localTracks = restoredState.localTracks;
    this.library.recentTrackIds = restoredState.recentTrackIds;
    this.library.currentTrackId = restoredState.currentTrackId;
    this.library.collectionMode = restoredState.collectionMode;
    this.library.totalListeningMs = restoredState.totalListeningMs;
    this.library.playMode = restoredState.playMode;
    this.shellVm.applyThemeMode(this.shell, restoredState.appThemeMode, false);
    this.library.customPlaylists = restoredState.customPlaylists;
    this.library.activePlaybackCollectionId = restoredState.activePlaybackCollectionId;
    this.library.playbackDrawerShowAlbumCollections = restoredState.playbackDrawerShowAlbumCollections;
    this.library.playbackDrawerShowArtistCollections = restoredState.playbackDrawerShowArtistCollections;
    this.baiduPan.baiduPanAppKey = restoredState.baiduPanAppKey;
    this.baiduPan.baiduPanAccessToken = restoredState.baiduPanAccessToken;
    this.baiduPan.baiduPanCurrentDir = restoredState.baiduPanCurrentDir;
    this.source.musicSources = restoredState.musicSources;
    this.sourceVm.setMusicSourceScripts(restoredState.musicSourceScripts);
    this.libraryVm.ensureActivePlaybackCollectionValid(this.library);
    this.libraryVm.syncCurrentTrackSelection(this.library, '', this.playback.loadedTrackId);
    this.refreshLibraryState();
    this.refreshExploreState();
  }

  private schedulePersistState(): void {
    if (this.isRestoringState || !this.hasInitializedState) return;
    if (this.shellVm.hasSession()) void this.shellVm.refreshAVSessionQueue(this.library.localTracks, this.library.customPlaylists, this.library.activePlaybackCollectionId);
    void this.persistState();
  }

  private flushPersistStateNow(): void {
    if (this.isRestoringState || !this.hasInitializedState || this.appDatabase === null) { this.schedulePersistState(); return; }
    try {
      persistAppStateSync(this.appDatabase, this.buildPersistedSnapshot(), this.sourceVm.getMusicSourceScripts());
      this.pendingPersistState = false;
    } catch (_) { this.schedulePersistState(); }
  }

  private async persistState(): Promise<void> {
    if (this.isPersistingState) { this.pendingPersistState = true; return; }
    this.isPersistingState = true;
    try {
      do {
        this.pendingPersistState = false;
        let store = await this.ensureAppDatabaseStore();
        await persistAppState(store, this.buildPersistedSnapshot(), this.sourceVm.getMusicSourceScripts());
      } while (this.pendingPersistState);
    } catch (error) { console.error(`persist state failed: ${JSON.stringify(error)}`); }
    finally { this.isPersistingState = false; }
  }

  private buildPersistedSnapshot(): PersistableAppState {
    return {
      localTracks: this.library.localTracks, recentTrackIds: this.library.recentTrackIds,
      currentTrackId: this.library.currentTrackId, collectionMode: this.library.collectionMode,
      totalListeningMs: this.library.totalListeningMs, playMode: this.library.playMode,
      appThemeMode: this.shell.appThemeMode, customPlaylists: this.library.customPlaylists,
      activePlaybackCollectionId: this.library.activePlaybackCollectionId,
      playbackDrawerShowAlbumCollections: this.library.playbackDrawerShowAlbumCollections,
      playbackDrawerShowArtistCollections: this.library.playbackDrawerShowArtistCollections,
      baiduPanAppKey: this.baiduPan.baiduPanAppKey, baiduPanAccessToken: this.baiduPan.baiduPanAccessToken,
      baiduPanCurrentDir: this.baiduPan.baiduPanCurrentDir, musicSources: this.source.musicSources
    };
  }

  private async commitPlaybackRecord(trackId: string, startedAt: number, listenedMs: number): Promise<void> {
    let normalizedListeningMs = Math.max(0, Math.floor(listenedMs));
    if (trackId.length === 0 || startedAt <= 0 || normalizedListeningMs < 1000) {
      return;
    }

    this.library.totalListeningMs += normalizedListeningMs;
    this.refreshLibraryState();
    this.schedulePersistState();

    let track = this.library.localTracks.find((item: MusicTrack) => item.id === trackId);
    let endedAt = Math.max(Date.now(), startedAt + normalizedListeningMs);
    let record: PlaybackRecordEntry = {
      id: `playback_${trackId}_${startedAt}`,
      trackId: trackId,
      trackTitle: track?.title ?? '',
      trackArtist: track?.artist ?? '',
      trackAlbum: track?.album ?? '',
      trackSourceImportKey: track?.sourceImportKey ?? '',
      startedAt: startedAt,
      endedAt: endedAt,
      listenedMs: normalizedListeningMs
    };

    try {
      let store = await this.ensureAppDatabaseStore();
      await appendPlaybackRecord(store, record);
    } catch (error) {
      console.error(`append playback record failed: ${JSON.stringify(error)}`);
    }
  }

  private cacheTrackDuration(trackId: string, durationMs: number): void {
    if (durationMs <= 0) return;
    let localIndex: number = this.library.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (localIndex < 0) return;
    if (this.library.localTracks[localIndex].durationMs === durationMs) return;
    let updatedTracks: MusicTrack[] = this.library.localTracks.slice();
    let updatedTrack: MusicTrack = copyTrack(updatedTracks[localIndex]);
    updatedTrack.durationMs = durationMs;
    updatedTracks[localIndex] = updatedTrack;
    this.library.localTracks = updatedTracks;
    this.refreshLibraryState();
    this.schedulePersistState();
  }

  private showToast(message: string): void {
    try { this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 }); } catch (_) {}
  }

  // --- Playback navigation ---
  private async playNextTrack(): Promise<void> {
    let queueTracks = this.libraryVm.playQueueTracks(this.library);
    if (queueTracks.length === 0) { this.showToast(t('playback.queue_empty')); return; }
    let index = this.libraryVm.playNextTrackIndex(this.library);
    if (index >= 0) await this.startTrackPlayback(queueTracks[index]);
  }

  private async playPreviousTrack(): Promise<void> {
    let queueTracks = this.libraryVm.playQueueTracks(this.library);
    if (queueTracks.length === 0) { this.showToast(t('playback.queue_empty')); return; }
    let index = this.libraryVm.playPreviousTrackIndex(this.library);
    if (index >= 0) await this.startTrackPlayback(queueTracks[index]);
  }

  private async startTrackPlayback(track: MusicTrack): Promise<void> {
    this.library.currentTrackId = track.id;
    this.refreshLibraryState();
    let cachePath = this.resolveCoverCachePath(track.id);
    if (fs.accessSync(cachePath)) {
      this.shellVm.setCoverArtFilePath(cachePath);
    } else {
      this.shellVm.setCoverArtFilePath('');
    }
    await this.playbackVm.startTrackPlayback(this.playback, track, this.library.localTracks);
    let navIds = this.libraryVm.resolveAdjacentTrackIds(this.library, track.id);
    await this.shellVm.createAVSession(track, this.playback.playbackDurationMs, this.libraryVm.currentTrackIsFavorite(this.library), this.library.playMode, this.lyricVm.currentLyricMetadataText(this.lyric), this.lyricVm.currentLyricContentText(this.lyric), this.lyricVm.currentLyricSecondaryText(this.lyric), navIds[0], navIds[1]);
    await this.shellVm.startMusicLiveView(track, this.lyricVm.currentLyricPreviewText(this.lyric), this.lyricVm.currentLyricSecondaryText(this.lyric));
  }

  private async handleTrackTap(track: MusicTrack): Promise<void> {
    let isLoadedTrack = this.playbackVm.isPlayerForTrack(this.playback, track.id);
    this.library.currentTrackId = track.id;
    this.refreshLibraryState();
    this.libraryVm.pushRecentTrack(this.library, track.id);
    if (!track.isImported) { this.showToast(t('playback.cannot_play_import')); return; }
    if (this.playbackVm.isPlayerForTrack(this.playback, track.id) && this.playback.isPlaying) { await this.playbackVm.pauseCurrentTrack(this.playback); return; }
    if (this.playbackVm.isPlayerForTrack(this.playback, track.id) && this.playbackVm.isPlayerPaused()) { await this.playbackVm.resumeCurrentTrack(this.playback); return; }
    await this.startTrackPlayback(track);
  }

  private async handleMiniPlayPause(): Promise<void> {
    let track = this.currentTrack();
    let queueTracks = this.libraryVm.playQueueTracks(this.library);
    if (this.playbackVm.isPlayerForTrack(this.playback, track.id) && this.playback.isPlaying) { await this.playbackVm.pauseCurrentTrack(this.playback); }
    else if (this.playbackVm.isPlayerForTrack(this.playback, track.id) && this.playbackVm.isPlayerPaused()) { await this.playbackVm.resumeCurrentTrack(this.playback); }
    else if (queueTracks.length > 0) { await this.startTrackPlayback(queueTracks[0]); }
  }

  private async importLocalMusic(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 50;
      options.fileSuffixFilters = AUDIO_FILTERS;
      let documentPicker = new picker.DocumentViewPicker(context);
      let uris = await documentPicker.select(options);
      if (!uris || uris.length === 0) return;
      let importDir = `${context.filesDir}/imports`;
      try { if (!fs.accessSync(importDir)) fs.mkdirSync(importDir, true); } catch (_) {}
      let mergedTracks = this.library.localTracks.slice();
      let importedCount = 0;
      for (let uri of uris) {
        let uriObj = new fileUri.FileUri(uri);
        let targetPath = `${importDir}/${Date.now()}-${sanitizeFileName(uriObj.name)}`;
        let duplicated = mergedTracks.some((track: MusicTrack) => track.sourceUri === uri || track.filePath === targetPath);
        if (duplicated) continue;
        try {
          let srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
          try { let dstFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY); try { fs.copyFileSync(srcFile.fd, dstFile.fd); } finally { fs.closeSync(dstFile); } } finally { fs.closeSync(srcFile); }
          mergedTracks.push(buildImportedTrack(uri, mergedTracks.length, targetPath));
          importedCount += 1;
        } catch (_) {}
      }
      this.library.localTracks = mergedTracks;
      this.metadataVm.syncTrackMetadataCaches(this.metadata, this.library.localTracks, this.library.currentTrackId);
      this.library.collectionMode = CollectionMode.Library;
      this.library.activeLibraryDimension = LibraryDimension.Song;
      this.library.activeMainTab = MainTab.Home;
      this.libraryVm.syncCurrentTrackSelection(this.library, '', this.playback.loadedTrackId);
      this.refreshLibraryState();
      this.schedulePersistState();
      this.showToast(importedCount > 0 ? t('import.success_count', `${importedCount}`) : t('import.already_exists'));
    } catch (_) { this.showToast(t('import.fail_retry')); }
  }

  // --- Build ---
  build() {
    if (this.isCarMode) { this.carLayout() } else { this.phoneLayout() }
  }

  @Builder private carLayout() {
    Column() {
      CarTrackList({
        tracks: this.libraryVm.playQueueTracks(this.library),
        currentTrackId: this.library.currentTrackId,
        coveredTrackIds: this.metadata.trackArtworkIds,
        title: this.libraryVm.activePlaybackCollectionTitle(this.library),
        onTrackTap: (track: MusicTrack) => { void this.startTrackPlayback(track); },
        coverForTrack: (trackId: string) => this.metadataVm.trackArtworkForTrack(trackId)
      })
      CarPlayerBar({
        track: this.currentTrack(),
        isPlaying: this.playback.isPlaying,
        playbackProgressMs: this.playbackVm.displayedPlaybackProgressMs(this.playback),
        playbackDurationMs: this.playback.playbackDurationMs,
        playMode: this.library.playMode,
        coveredTrackIds: this.metadata.trackArtworkIds,
        onPlayPause: () => { void this.handleMiniPlayPause(); },
        onPrevious: () => { void this.playPreviousTrack(); },
        onNext: () => { void this.playNextTrack(); },
        onSeekChange: (value: number, mode: SliderChangeMode) => { this.playbackVm.handleMiniSeekChange(this.playback, value, mode, this.playback.playbackDurationMs); },
        onSelectPlayMode: () => {
          if (this.library.playMode === PlayMode.Sequential) this.library.playMode = PlayMode.Shuffle;
          else if (this.library.playMode === PlayMode.Shuffle) this.library.playMode = PlayMode.Loop;
          else this.library.playMode = PlayMode.Sequential;
          void this.shellVm.updateAVSessionState(this.playback.isPlaying, this.playback.playbackProgressMs, this.playback.playbackDurationMs, this.library.playMode, this.libraryVm.currentTrackIsFavorite(this.library));
        },
        coverForTrack: (trackId: string) => this.metadataVm.trackArtworkForTrack(trackId)
      })
    }.width('100%').height('100%').backgroundColor(this.theme().appBackground)
  }

  @Builder private phoneLayout() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 0 }) {
        Column() {
          this.pageContent()
        }
        .width('100%')
        .layoutWeight(1)

        Column() {
          MiniPlayerBar({
            isDocked: true,
            track: this.currentTrack(), discRotationAngle: this.playback.discRotationAngle, isPlaying: this.playback.isPlaying,
            isPlayButtonTransitioning: this.playback.isPlayButtonTransitioning, playButtonShowsPause: this.playback.playButtonShowsPause,
            playButtonScale: this.playback.playButtonScale, nextButtonScale: this.playback.nextButtonScale,
            progressRatio: playbackProgressRatio(this.playbackVm.displayedPlaybackProgressMs(this.playback), this.playback.playbackDurationMs),
            playbackProgressMs: this.playbackVm.displayedPlaybackProgressMs(this.playback), playbackDurationMs: this.playback.playbackDurationMs,
            currentLyricText: this.lyricVm.currentLyricPreviewText(this.lyric), secondaryLyricText: this.lyricVm.currentLyricSecondaryText(this.lyric),
            isLoadingLyrics: this.lyric.isLoadingLyrics, coveredTrackIds: this.metadata.trackArtworkIds,
            onPlayPause: () => { void this.handleMiniPlayPause(); },
            onNext: () => { void this.playNextTrack(); },
            onSeekChange: (value: number, mode: SliderChangeMode) => { this.playbackVm.handleMiniSeekChange(this.playback, value, mode, this.playback.playbackDurationMs); },
            onPlayButtonTouch: (event: TouchEvent) => { this.playbackVm.handlePlayButtonTouch(this.playback, event); },
            onNextButtonTouch: (event: TouchEvent) => { this.playbackVm.handleNextButtonTouch(this.playback, event); },
            onTapTrackInfo: () => { this.lyric.showLyricsPanel = !this.lyric.showLyricsPanel; },
            coverForTrack: (trackId: string) => this.metadataVm.trackArtworkForTrack(trackId)
          })

          Row()
            .width('100%')
            .height(1)
            .backgroundColor(this.theme().divider)

          BottomNavigationBar({
            isDocked: true,
            activeMainTab: this.library.activeMainTab,
            onSelectTab: (tab: MainTab) => {
              this.library.activeMainTab = tab;
              this.refreshLibraryState();
              if (tab === MainTab.Explore) this.exploreVm.ensureExploreSourceReady(this.source, this.explore, true);
            }
          })
        }
        .width('100%')
        .backgroundColor(this.theme().floatingSurface)
        .backdropBlur(this.shell.themeAppearance === AppThemeAppearance.Dark ? 30 : 12)
        .borderRadius({ topLeft: 14, topRight: 14, bottomLeft: 0, bottomRight: 0 })
        .border({
          width: 1,
          color: this.theme().floatingSurfaceBorder
        })
        .shadow({
          radius: this.shell.themeAppearance === AppThemeAppearance.Dark ? 10 : 14,
          color: this.theme().floatingSurfaceShadow,
          offsetX: 0,
          offsetY: 6
        })
      }
      .width('100%')
      .height('100%')

      if (this.lyric.showLyricsPanel) {
        Column() {
          LyricsPanel({ lyrics: this.lyric.currentLyrics, currentIndex: this.lyric.currentLyricIndex, currentTimeMs: this.playback.playbackProgressMs, isLoading: this.lyric.isLoadingLyrics, onClose: () => { this.lyric.showLyricsPanel = false; } })
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: this.phoneBottomOverlayHeight })
        .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
      }
      if (this.source.showSourceUpdateAlertDialog) {
        SourceUpdateAlertDialog({ name: this.source.sourceUpdateAlertName, log: this.source.sourceUpdateAlertLog, updateUrl: this.source.sourceUpdateAlertUrl, onClose: () => { this.source.showSourceUpdateAlertDialog = false; } })
      }
    }.width('100%').height('100%').backgroundColor(this.theme().appBackground)
  }

  @Builder private pageContent() {
    if (this.library.activeMainTab === MainTab.Home) this.homePage()
    else if (this.library.activeMainTab === MainTab.Explore) this.explorePage()
    else this.profilePage()
  }

  @Builder private homePage() {
    Stack() {
      HomeQueuePage({
        tracks: this.libraryVm.filteredPlayQueueTracks(this.library), currentTrackId: this.library.currentTrackId,
        playMode: this.library.playMode, activeCollectionTitle: this.libraryVm.activePlaybackCollectionTitle(this.library),
        showRenameDialog: this.library.showRenameDialog, renameText: this.library.renameText,
        searchKeyword: this.library.searchKeyword, bottomInset: this.pageBottomInset, coveredTrackIds: this.metadata.trackArtworkIds,
        onOpenPlaylistDrawer: () => { this.library.showPlaybackCollectionDrawer = true; this.refreshLibraryState(); },
        onSelectPlayMode: (mode: PlayMode) => { this.library.playMode = mode; this.refreshLibraryState(); this.schedulePersistState(); },
        onSearchKeywordChange: (value: string) => { this.library.searchKeyword = value; this.refreshLibraryState(); },
        onSearch: () => {},
        onTrackTap: (track: MusicTrack) => { void this.handleTrackTap(track); },
        onToggleFavorite: (trackId: string) => { this.libraryVm.toggleFavorite(this.library, trackId); },
        onOpenRename: (track: MusicTrack) => { this.library.renameTrackId = track.id; this.library.renameText = track.title; this.library.showRenameDialog = true; this.refreshLibraryState(); },
        onRenameTextChange: (value: string) => { this.library.renameText = value; this.refreshLibraryState(); },
        onCancelRename: () => { this.library.showRenameDialog = false; this.library.renameTrackId = ''; this.library.renameText = ''; this.refreshLibraryState(); },
        onConfirmRename: () => { this.libraryVm.applyRename(this.library); },
        trackDurationText: (track: MusicTrack) => this.libraryVm.trackDurationText(this.library, track, this.playback.playbackDurationMs),
        coverForTrack: (trackId: string) => this.metadataVm.trackArtworkForTrack(trackId)
      })
      if (this.library.showPlaybackCollectionDrawer) {
        PlaybackCollectionDrawer({
          activeCollectionId: this.library.activePlaybackCollectionId,
          allCollection: allPlaybackCollectionSummary(this.library.localTracks),
          favoriteCollection: favoritePlaybackCollectionSummary(this.library.localTracks),
          albumCollections: albumPlaybackCollectionSummaries(this.library.localTracks),
          artistCollections: artistPlaybackCollectionSummaries(this.library.localTracks),
          customCollections: customPlaybackCollectionSummaries(this.library.customPlaylists, this.library.localTracks),
          importedTracks: this.library.localTracks, customPlaylists: this.library.customPlaylists,
          showAlbumCollections: this.library.playbackDrawerShowAlbumCollections,
          showArtistCollections: this.library.playbackDrawerShowArtistCollections,
          onClose: () => { this.library.showPlaybackCollectionDrawer = false; this.refreshLibraryState(); },
          onSelectCollection: (collectionId: string) => { this.libraryVm.selectPlaybackCollection(this.library, collectionId, this.playback.loadedTrackId); },
          onCreateCustomPlaylist: (name: string) => { this.libraryVm.createPlaybackCustomPlaylist(this.library, name, this.playback.loadedTrackId); },
          onDeleteCustomPlaylist: (playlistId: string) => { this.libraryVm.deletePlaybackCustomPlaylist(this.library, playlistId, this.playback.loadedTrackId); },
          onToggleAlbumCollections: (expanded: boolean) => { this.library.playbackDrawerShowAlbumCollections = expanded; this.refreshLibraryState(); this.schedulePersistState(); },
          onToggleArtistCollections: (expanded: boolean) => { this.library.playbackDrawerShowArtistCollections = expanded; this.refreshLibraryState(); this.schedulePersistState(); },
          onToggleTrackInCustomPlaylist: (playlistId: string, trackId: string) => { this.libraryVm.toggleTrackInPlaybackCustomPlaylist(this.library, playlistId, trackId, this.playback.loadedTrackId); }
        })
      }
    }.width('100%').height('100%')
  }

  @Builder private explorePage() {
    Stack() {
      ExploreHallPage({
        musicSources: this.source.musicSources, activeSourceId: this.explore.activeSourceId,
        activeSearchSource: this.explore.activeSearchSource, sourceTracks: this.explore.sourceTracks,
        sourceTracksLoading: this.explore.sourceTracksLoading, sourceSearchKeyword: this.explore.sourceSearchKeyword,
        sourceCurrentPage: this.explore.sourceCurrentPage, sourceTotal: this.explore.sourceTotal,
        sourceBoardList: this.explore.sourceBoardList, sourceBoardsLoading: this.explore.sourceBoardsLoading,
        activeBoardId: this.explore.activeBoardId, exploreMode: this.explore.exploreMode,
        bottomInset: this.pageBottomInset, sourceImportingTrackKeys: this.explore.sourceImportingTrackKeys,
        sourceQualitySnapshot: '',
        onGoToProfile: () => { this.library.activeMainTab = MainTab.Profile; this.refreshLibraryState(); },
        onSelectSource: (source: MusicSourceConfig) => {
          this.explore.activeSourceId = source.id;
          this.explore.sourceTracks = [];
          this.explore.sourceSearchKeyword = '';
          this.explore.sourceCurrentPage = 1;
          this.explore.exploreMode = 'board';
          this.explore.sourceTotal = 0;
          let supported = filterSupportedExploreSources(source.musicSources);
          if (supported.length === 0) {
            this.explore.activeSearchSource = '';
            this.explore.sourceBoardList = [];
            this.explore.activeBoardId = '';
            this.refreshExploreState();
            return;
          }
          this.explore.activeSearchSource = resolvePreferredSubSource(source, this.explore.activeSearchSource);
          this.refreshExploreState();
          void this.exploreVm.fetchBoardList(source, this.explore.activeSearchSource, this.explore);
        },
        onSelectSubSource: (sourceCode: string) => {
          this.explore.activeSearchSource = sourceCode;
          this.explore.sourceTracks = [];
          this.explore.sourceCurrentPage = 1;
          this.refreshExploreState();
          let source = this.exploreVm.ensureExploreSourceReady(this.source, this.explore, false);
          if (source) {
            if (this.explore.exploreMode === 'board') void this.exploreVm.fetchBoardList(source, sourceCode, this.explore);
            else if (this.explore.sourceSearchKeyword.trim().length > 0) void this.exploreVm.searchSourceTracks(this.explore.sourceSearchKeyword, sourceCode, 1, this.explore);
          }
        },
        onSelectSourceQuality: (sourceCode: string, quality: string) => { let source = this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.explore.activeSourceId); if (source) this.sourceVm.updateMusicSourcePreferredQuality(this.source, source.id, sourceCode, quality); },
        onToggleMode: () => {
          this.explore.exploreMode = this.explore.exploreMode === 'board' ? 'search' : 'board';
          if (this.explore.exploreMode === 'board') {
            this.refreshExploreState();
            this.exploreVm.ensureExploreSourceReady(this.source, this.explore, true);
          } else {
            this.explore.sourceSearchKeyword = '';
            this.refreshExploreState();
          }
        },
        onSearchKeywordChange: (value: string) => { this.explore.sourceSearchKeyword = value; this.refreshExploreState(); },
        onSearch: () => {
          let source = this.exploreVm.ensureExploreSourceReady(this.source, this.explore, false);
          if (source) {
            this.explore.exploreMode = 'search';
            this.refreshExploreState();
            void this.exploreVm.searchSourceTracks(this.explore.sourceSearchKeyword, this.explore.activeSearchSource, 1, this.explore);
          }
        },
        onSelectBoard: (board: SourceBoardItem) => {
          this.explore.exploreMode = 'board';
          this.explore.activeBoardId = board.bangid;
          this.explore.sourceTracks = [];
          this.explore.sourceCurrentPage = 1;
          this.refreshExploreState();
          let source = this.exploreVm.ensureExploreSourceReady(this.source, this.explore, false);
          if (source) void this.exploreVm.fetchBoardTracks(this.explore.activeSearchSource, board.bangid, 1, this.explore);
        },
        onImportTrack: (track: MusicSourceTrack) => { let source = this.exploreVm.ensureExploreSourceReady(this.source, this.explore, false); if (source) this.exploreVm.enqueueSourceTrackImport(source, track, this.explore); },
        onLoadMore: () => { let source = this.exploreVm.ensureExploreSourceReady(this.source, this.explore, false); if (source) { if (this.explore.exploreMode === 'board') void this.exploreVm.fetchBoardTracks(this.explore.activeSearchSource, this.explore.activeBoardId, this.explore.sourceCurrentPage + 1, this.explore); else void this.exploreVm.searchSourceTracks(this.explore.sourceSearchKeyword, this.explore.activeSearchSource, this.explore.sourceCurrentPage + 1, this.explore); } },
        sourceTrackActionLabel: (track: MusicSourceTrack) => this.exploreVm.sourceTrackActionLabel(track, this.library.localTracks, this.explore.sourceImportingTrackKeys),
        sourceTrackActionEnabled: (track: MusicSourceTrack) => this.exploreVm.sourceTrackActionEnabled(track, this.library.localTracks, this.explore.sourceImportingTrackKeys)
      })
      if (this.source.showSourceManager) {
        SourceManagerPanel({
          musicSources: this.source.musicSources, addSourceLoading: this.source.addSourceLoading, sourceUrlInput: this.source.sourceUrlInput,
          onClose: () => { this.sourceVm.closeSourceManager(this.source); },
          onSourceUrlChange: (value: string) => { this.source.sourceUrlInput = value; },
          onAddFromFile: () => { void this.sourceVm.addMusicSourceFromFile(this.source); },
          onAddFromUrl: () => { void this.sourceVm.addMusicSourceFromUrl(this.source); },
          onToggleUpdateAlert: (sourceId: string) => { this.sourceVm.toggleMusicSourceAllowShowUpdateAlert(this.source, sourceId); },
          onRemoveSource: (sourceId: string) => { this.sourceVm.removeMusicSource(this.source, sourceId); }
        })
      }
    }.width('100%').height('100%')
  }

  @Builder private profilePage() {
    Stack() {
      ProfilePageContent({
        totalListeningText: totalListeningSummaryText(this.library.totalListeningMs), themeModeLabel: appThemeModeLabel(this.shell.appThemeMode),
        musicSources: this.source.musicSources, importedTrackCount: this.library.localTracks.length,
        playQueueTrackCount: this.libraryVm.playQueueTracks(this.library).length, bottomInset: this.pageBottomInset,
        onImportLocal: () => { void this.importLocalMusic(); },
        onOpenBaiduPanImport: () => { this.baiduPanVm.openBaiduPanImportPanel(this.baiduPan); },
        onOpenThemeMode: () => { this.showThemeModePanel = true; },
        onOpenImportedTrackManager: () => { this.showImportedTrackManager = true; },
        onOpenSourceManager: () => { this.source.showSourceManager = true; },
        onBrowseSource: (source: MusicSourceConfig) => { this.exploreVm.openSourceBrowser(source, this.explore); },
        onOpenEqualizer: () => { this.showToast(t('playback.equalizer_coming')); }
      })
      if (this.source.showSourceManager) {
        SourceManagerPanel({
          musicSources: this.source.musicSources, addSourceLoading: this.source.addSourceLoading, sourceUrlInput: this.source.sourceUrlInput,
          onClose: () => { this.sourceVm.closeSourceManager(this.source); },
          onSourceUrlChange: (value: string) => { this.source.sourceUrlInput = value; },
          onAddFromFile: () => { void this.sourceVm.addMusicSourceFromFile(this.source); },
          onAddFromUrl: () => { void this.sourceVm.addMusicSourceFromUrl(this.source); },
          onToggleUpdateAlert: (sourceId: string) => { this.sourceVm.toggleMusicSourceAllowShowUpdateAlert(this.source, sourceId); },
          onRemoveSource: (sourceId: string) => { this.sourceVm.removeMusicSource(this.source, sourceId); }
        })
      }
      if (this.showThemeModePanel) {
        ThemeModePanel({ currentMode: this.shell.appThemeMode, onClose: () => { this.showThemeModePanel = false; }, onSelectMode: (mode: AppThemeMode) => { this.shellVm.applyThemeMode(this.shell, mode, true); this.showThemeModePanel = false; } })
      }
      if (this.showImportedTrackManager) {
        ImportedTrackManagerPanel({
          tracks: this.library.localTracks, coveredTrackIds: this.metadata.trackArtworkIds, isRepairingLyrics: this.lyric.lyricRepairingTrackIds.length > 0,
          onClose: () => { this.showImportedTrackManager = false; },
          onRepairMissingLyrics: () => { void this.lyricVm.repairMissingImportedTrackLyrics(this.lyric, this.library.localTracks); },
          onMoveTrackBefore: (trackId: string, referenceTrackId: string) => { this.libraryVm.moveImportedTrackBefore(this.library, trackId, referenceTrackId); },
          onMoveTrackAfter: (trackId: string, referenceTrackId: string) => { this.libraryVm.moveImportedTrackAfter(this.library, trackId, referenceTrackId); },
          onToggleTrackInPlayQueue: (trackId: string) => { this.libraryVm.toggleTrackInPlayQueue(this.library, trackId, this.playback.loadedTrackId); },
          onRemoveTrack: (trackId: string) => { void this.libraryVm.removeImportedTracks(this.library, [trackId], this.playback.loadedTrackId); },
          onRemoveTracks: (trackIds: string[]) => { void this.libraryVm.removeImportedTracks(this.library, trackIds, this.playback.loadedTrackId); },
          coverForTrack: (trackId: string) => this.metadataVm.trackArtworkForTrack(trackId)
        })
      }
      if (this.baiduPan.showBaiduPanImportPanel) {
        BaiduPanImportPanel({
          appKey: this.baiduPan.baiduPanAppKey, accessToken: this.baiduPan.baiduPanAccessToken,
          currentDir: this.baiduPan.baiduPanCurrentDir, entries: this.baiduPan.baiduPanEntries,
          isLoading: this.baiduPan.baiduPanLoading, importingKeys: this.baiduPan.baiduPanImportingKeys,
          importedKeySnapshot: this.baiduPanVm.baiduPanImportedKeySnapshot(this.library.localTracks),
          onClose: () => { this.baiduPanVm.closeBaiduPanImportPanel(this.baiduPan); },
          onAppKeyChange: (value: string) => { if (value.trim() !== this.baiduPan.baiduPanAppKey.trim()) { this.baiduPan.baiduPanAccessToken = ''; this.baiduPan.baiduPanEntries = []; this.baiduPan.baiduPanCurrentDir = '/'; this.baiduPan.baiduPanAuthUrl = ''; } this.baiduPan.baiduPanAppKey = value; },
          onOpenAuth: () => { this.baiduPanVm.openBaiduPanAuthPanel(this.baiduPan); },
          onRefresh: () => { void this.baiduPanVm.loadBaiduPanDirectory(this.baiduPan, this.baiduPan.baiduPanCurrentDir); },
          onEnterDirectory: (entry: BaiduPanEntry) => { void this.baiduPanVm.enterBaiduPanDirectory(this.baiduPan, entry); },
          onGoParent: () => { void this.baiduPanVm.goParentBaiduPanDirectory(this.baiduPan); },
          onImportEntry: (entry: BaiduPanEntry) => { void this.baiduPanVm.importBaiduPanEntry(this.baiduPan, entry); }
        })
      }
      if (this.baiduPan.showBaiduPanAuthPanel) {
        BaiduPanAuthPanel({
          appKey: this.baiduPan.baiduPanAppKey, authUrl: this.baiduPan.baiduPanAuthUrl,
          isAuthorizing: this.baiduPan.baiduPanAuthUrl.trim().length > 0,
          onClose: () => { this.baiduPanVm.closeBaiduPanAuthPanel(this.baiduPan); },
          onAppKeyChange: (value: string) => { if (value.trim() !== this.baiduPan.baiduPanAppKey.trim()) { this.baiduPan.baiduPanAppKey = value; this.baiduPan.baiduPanAccessToken = ''; this.baiduPan.baiduPanEntries = []; this.baiduPan.baiduPanCurrentDir = '/'; this.baiduPan.baiduPanAuthUrl = ''; } },
          onStartAuth: () => { this.baiduPanVm.startBaiduPanAuth(this.baiduPan); },
          onObservedPayload: (payload: string) => { this.baiduPanVm.handleBaiduPanAuthPayload(this.baiduPan, payload); }
        })
      }
      if (this.explore.showSourceBrowser) {
        SourceBrowserPanel({
          title: this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.explore.activeSourceId)?.name ?? t('source.browser_title'),
          subSources: filterSupportedExploreSources(this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.explore.activeSourceId)?.musicSources ?? []),
          activeSearchSource: this.explore.activeSearchSource, sourceSearchKeyword: this.explore.sourceSearchKeyword,
          sourceTracks: this.explore.sourceTracks, sourceTracksLoading: this.explore.sourceTracksLoading,
          sourceTotal: this.explore.sourceTotal, sourceCurrentPage: this.explore.sourceCurrentPage,
          sourceImportingTrackKeys: this.explore.sourceImportingTrackKeys, sourceQualitySnapshot: '',
          onClose: () => { this.exploreVm.closeSourceBrowser(this.explore); },
          onSelectSubSource: (sourceCode: string) => {
            this.explore.activeSearchSource = sourceCode;
            this.explore.sourceTracks = [];
            this.refreshExploreState();
            if (this.explore.sourceSearchKeyword.trim().length > 0) {
              let source = this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.explore.activeSourceId);
              if (source) void this.exploreVm.searchSourceTracks(this.explore.sourceSearchKeyword, sourceCode, 1, this.explore);
            }
          },
          onSelectQuality: (sourceCode: string, quality: string) => { let source = this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.explore.activeSourceId); if (source) this.sourceVm.updateMusicSourcePreferredQuality(this.source, source.id, sourceCode, quality); },
          onSearchKeywordChange: (value: string) => { this.explore.sourceSearchKeyword = value; this.refreshExploreState(); },
          onSearch: () => { let source = this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.explore.activeSourceId); if (source) void this.exploreVm.searchSourceTracks(this.explore.sourceSearchKeyword, this.explore.activeSearchSource, 1, this.explore); },
          onLoadMore: () => { let source = this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.explore.activeSourceId); if (source) void this.exploreVm.searchSourceTracks(this.explore.sourceSearchKeyword, this.explore.activeSearchSource, this.explore.sourceCurrentPage + 1, this.explore); },
          onImportTrack: (track: MusicSourceTrack) => { let source = this.source.musicSources.find((s: MusicSourceConfig) => s.id === this.explore.activeSourceId); if (source) this.exploreVm.enqueueSourceTrackImport(source, track, this.explore); },
          sourceTrackActionLabel: (track: MusicSourceTrack) => this.exploreVm.sourceTrackActionLabel(track, this.library.localTracks, this.explore.sourceImportingTrackKeys),
          sourceTrackActionEnabled: (track: MusicSourceTrack) => this.exploreVm.sourceTrackActionEnabled(track, this.library.localTracks, this.explore.sourceImportingTrackKeys)
        })
      }
    }.width('100%').height('100%')
  }
}
