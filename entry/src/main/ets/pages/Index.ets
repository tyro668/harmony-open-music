import { media } from '@kit.MediaKit';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { picker, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { relationalStore } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { avSession } from '@kit.AVSessionKit';
import fs from '@ohos.file.fs';
import audio from '@ohos.multimedia.audio';
import { util } from '@kit.ArkTS';

import {
  AUDIO_FILTERS,
  BUILTIN_BOARD_LIST,
  COLOR_PALETTE,
  DEFAULT_PLAYBACK_COLLECTION_ID,
  LISTENING_SEED_MS,
  MAX_RECENT_TRACKS,
  MINI_PLACEHOLDER_TRACK,
  ONLINE_DOWNLOAD_MAX_BYTES
} from '../constants/AppConstants';
import {
  AppThemeAppearance,
  AppThemeMode,
  CollectionMode,
  CustomPlaylist,
  LibraryDimension,
  MainTab,
  BaiduPanEntry,
  MusicSourceConfig,
  MusicSourceQuality,
  MusicSourceTrack,
  MusicTrack,
  PlayMode,
  PlaybackCollectionSummary,
  QuickJsLogPayload,
  SourceBoardItem,
  SourceUpdateAlertPayload
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
import { SourceBrowserPanel } from '../components/source/SourceBrowserPanel';
import { SourceManagerPanel } from '../components/source/SourceManagerPanel';
import { SourceUpdateAlertDialog } from '../components/source/SourceUpdateAlertDialog';
import { QuickJsEngineAdapter, QuickJsHostEvent } from '../utils/QuickJsEngine';
import { LX_PRELOAD_SCRIPT as USER_API_PRELOAD_SCRIPT } from '../utils/LxUserApiPreload';
import {
  currentTrack as selectCurrentTrack,
  moveTrackByReference,
  playbackProgressRatio,
  totalListeningHours,
  visibleTracks as selectVisibleTracks
} from '../utils/LibraryStateUtils';
import {
  albumPlaybackCollectionSummaries,
  allPlaybackCollectionSummary,
  artistPlaybackCollectionSummaries,
  buildCustomPlaybackCollectionId,
  customPlaybackCollectionSummaries,
  favoritePlaybackCollectionSummary,
  playbackCollectionSelectorSummaries,
  playbackCollectionExists,
  playbackCollectionSummaryById,
  playbackCollectionTracks,
  trackBelongsToPlaybackCollection
} from '../utils/PlaybackCollectionUtils';
import {
  buildBaiduPanOAuthAuthorizeUrl,
  baiduPanParentLabel,
  downloadBaiduPanAudio,
  fetchBaiduPanDirectory,
  normalizeBaiduPanPath,
  parseBaiduPanOAuthPayload,
  parentBaiduPanPath
} from '../services/BaiduPanService';
import {
  buildDownloadedTrack,
  buildImportedTrack,
  copyTrack,
  formatDurationMs,
  sanitizeFileName
} from '../utils/TrackUtils';
import {
  buildSourceTrackImportKey,
  filterSupportedExploreSources,
  isSupportedExploreSource,
  sourceDisplayName,
  sourceQualityDisplayName
} from '../utils/MusicSourceUtils';
import {
  appThemeModeLabel,
  appThemeModeToColorMode,
  appThemePalette,
  resolveAppThemeAppearance
} from '../utils/ThemeUtils';
import {
  activatePersistedReadUriPermissions,
  appendPlaybackRecord,
  deleteMusicSourceScript as deletePersistedMusicSourceScript,
  ensureAppDatabase,
  PlaybackRecordEntry,
  persistAppState as savePersistedAppState,
  persistAppStateSync as savePersistedAppStateSync,
  persistReadUriPermissions,
  readMusicSourceScript,
  restorePersistedAppState
} from '../services/AppStatePersistenceService';
import {
  createPendingMusicSource,
  removeSourceById,
  resolvePreferredSubSource,
  toggleSourceUpdateAlert,
  updateSourcePreferredQuality
} from '../services/CustomSourceCatalogService';
import {
  createCustomPlaylist,
  removeCustomPlaylist,
  removeTracksFromCustomPlaylists,
  toggleTrackInCustomPlaylist
} from '../services/CustomPlaylistService';
import { fetchBoardTrackPage, searchSourceTrackPage } from '../services/MusicSourceApiService';
import {
  buildQuickJsMusicUrlRequest,
  buildQuickJsSourceSetupScript,
  createQuickJsHttpRequestTask,
  handleJsEngineInitPayload,
  parseQuickJsMusicUrlResponse,
  resolveSourceTrackQuality
} from '../services/QuickJsSourceService';
import {
  applyPlaybackLiveViewUpdate,
  applyStoppedLiveViewUpdate,
  buildPlaybackCollectionQueueItems,
  buildPlaybackCollectionQueueTitle,
  createPlaybackLiveView,
  createPlaybackState,
  createPlaybackWantAgent,
  createSessionMetadata,
  startAudioBackgroundTask,
  stopAudioBackgroundTask
} from '../services/PlaybackPlatformService';
import {
  extractTrackDuration,
  extractTrackArtwork,
  releaseTrackArtwork as releaseExtractedTrackArtwork
} from '../services/TrackArtworkService';

class SourceImportTask {
  key: string;
  source: MusicSourceConfig;
  track: MusicSourceTrack;

  constructor(key: string, source: MusicSourceConfig, track: MusicSourceTrack) {
    this.key = key;
    this.source = source;
    this.track = track;
  }
}

@Entry
@Component
struct Index {
  private readonly pageBottomInset: number = 188;
  @State appThemeMode: AppThemeMode = AppThemeMode.Light;
  @State themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @State activeMainTab: MainTab = MainTab.Home;
  @State activeLibraryDimension: LibraryDimension = LibraryDimension.Song;
  @State collectionMode: CollectionMode = CollectionMode.Library;
  @State localTracks: Array<MusicTrack> = [];
  @State recentTrackIds: Array<string> = [];
  @State currentTrackId: string = MINI_PLACEHOLDER_TRACK.id;
  @State activePlaybackCollectionId: string = DEFAULT_PLAYBACK_COLLECTION_ID;
  @State playbackDrawerShowAlbumCollections: boolean = false;
  @State playbackDrawerShowArtistCollections: boolean = false;
  @State customPlaylists: CustomPlaylist[] = [];
  @State searchKeyword: string = '';
  @State showPlaybackCollectionDrawer: boolean = false;
  @State showBaiduPanImportPanel: boolean = false;
  @State showBaiduPanAuthPanel: boolean = false;
  @State showImportedTrackManager: boolean = false;
  @State showThemeModePanel: boolean = false;
  @State baiduPanAppKey: string = '';
  @State baiduPanAccessToken: string = '';
  @State baiduPanCurrentDir: string = '/';
  @State baiduPanEntries: BaiduPanEntry[] = [];
  @State baiduPanLoading: boolean = false;
  @State baiduPanAuthUrl: string = '';
  @State baiduPanImportingKeys: string[] = [];
  @State isPlaying: boolean = false;
  @State playButtonShowsPause: boolean = false;
  @State isPlayButtonTransitioning: boolean = false;
  @State discRotationAngle: number = 0;
  @State playButtonScale: number = 1;
  @State nextButtonScale: number = 1;
  @State playbackProgressMs: number = 0;
  @State playbackDurationMs: number = 0;
  @State isSeekingPlayback: boolean = false;
  @State seekPreviewMs: number = 0;
  @State totalListeningMs: number = LISTENING_SEED_MS;
  @State playMode: PlayMode = PlayMode.Sequential;
  @State showRenameDialog: boolean = false;
  @State renameTrackId: string = '';
  @State renameText: string = '';
  @State showTrackMenu: boolean = false;
  @State menuTrackId: string = '';
  @State musicSources: MusicSourceConfig[] = [];
  @State showSourceManager: boolean = false;
  @State showAddSourceDialog: boolean = false;
  @State addSourceLoading: boolean = false;
  @State sourceUrlInput: string = '';
  @State showSourceBrowser: boolean = false;
  @State activeSourceId: string = '';
  @State activeSearchSource: string = '';
  @State sourceTracks: MusicSourceTrack[] = [];
  @State sourceTracksLoading: boolean = false;
  @State sourceSearchKeyword: string = '';
  @State sourceCurrentPage: number = 1;
  @State sourceTotal: number = 0;
  @State sourceImportingTrackKeys: string[] = [];
  @State sourceBoardList: SourceBoardItem[] = [];
  @State sourceBoardsLoading: boolean = false;
  @State activeBoardId: string = '';
  @State exploreMode: string = 'board';
  @State showSourceUpdateAlertDialog: boolean = false;
  @State sourceUpdateAlertName: string = '';
  @State sourceUpdateAlertLog: string = '';
  @State sourceUpdateAlertUrl: string = '';
  @State trackArtworkIds: string[] = [];

  private jsEngineKey: string = '';
  private jsEngineSourceId: string = '';
  private jsEngineReady: boolean = false;
  private jsEngineLastError: string = '';
  private quickJsEngine: QuickJsEngineAdapter | null = null;
  private musicSourceScripts: Map<string, string> = new Map();
  private trackArtworkMap: Map<string, image.PixelMap> = new Map();
  private trackArtworkOwnerMap: Map<string, string> = new Map();
  private trackArtworkLoadingIds: Set<string> = new Set();
  private trackArtworkUnavailableIds: Set<string> = new Set();
  private trackDurationLoadingIds: Set<string> = new Set();
  private trackDurationUnavailableIds: Set<string> = new Set();

  private player: media.AVPlayer | null = null;
  private openedFile: fs.File | null = null;
  private openedRawFileName: string = '';
  private appDatabase: relationalStore.RdbStore | null = null;
  private playerSession: number = 0;
  private loadedTrackId: string = '';
  private autoPlayAfterPrepare: boolean = false;
  private pendingStartSeekMs: number = 0;
  private lastProgressSnapshotMs: number = 0;
  private isAudioInterrupted: boolean = false;
  private shouldResumeAfterInterrupt: boolean = false;
  private playerReleasedDuringInterrupt: boolean = false;
  private interruptedTrackId: string = '';
  private interruptedProgressMs: number = 0;
  private currentPlaybackRecordTrackId: string = '';
  private currentPlaybackRecordStartedAt: number = 0;
  private currentPlaybackRecordMs: number = 0;
  private discRotationTimer: number = -1;
  private hasInitializedState: boolean = false;
  private isRestoringState: boolean = false;
  private isPersistingState: boolean = false;
  private pendingPersistState: boolean = false;
  private liveView: liveViewManager.LiveView | null = null;
  private liveViewSequence: number = 0;
  private session: avSession.AVSession | null = null;
  private isBackgroundTaskRunning: boolean = false;
  private sourceImportQueue: SourceImportTask[] = [];
  private isProcessingSourceImportQueue: boolean = false;
  private baiduPanLastAuthMessage: string = '';
  private systemColorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  aboutToAppear(): void {
    this.applyThemeMode(this.appThemeMode, false);
    if (this.hasInitializedState) {
      return;
    }
    this.hasInitializedState = true;
    void this.initializeAppState();
  }

  aboutToDisappear(): void {
    this.flushPersistStateNow();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.pageContent()
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 168 })

      Column({ space: 8 }) {
        MiniPlayerBar({
          track: selectCurrentTrack(this.localTracks, this.currentTrackId),
          discRotationAngle: this.discRotationAngle,
          isPlaying: this.isPlaying,
          isPlayButtonTransitioning: this.isPlayButtonTransitioning,
          playButtonShowsPause: this.playButtonShowsPause,
          playButtonScale: this.playButtonScale,
          nextButtonScale: this.nextButtonScale,
          progressRatio: playbackProgressRatio(this.displayedPlaybackProgressMs(), this.playbackDurationMs),
          playbackProgressMs: this.displayedPlaybackProgressMs(),
          playbackDurationMs: this.playbackDurationMs,
          coveredTrackIds: this.trackArtworkIds,
          onPlayPause: () => {
            void this.handleMiniPlayPause();
          },
          onNext: () => {
            void this.playNextTrack();
          },
          onSeekChange: (value: number, mode: SliderChangeMode) => {
            this.handleMiniSeekChange(value, mode);
          },
          onPlayButtonTouch: (event: TouchEvent) => {
            this.handlePlayButtonTouch(event);
          },
          onNextButtonTouch: (event: TouchEvent) => {
            this.handleNextButtonTouch(event);
          },
          coverForTrack: (trackId: string) => this.trackArtworkForTrack(trackId)
        })
        BottomNavigationBar({
          activeMainTab: this.activeMainTab,
          onSelectTab: (tab: MainTab) => {
            this.activeMainTab = tab;
            if (tab === MainTab.Explore) {
              this.ensureExploreSourceReady(true);
            }
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 14 })

      if (this.showSourceUpdateAlertDialog) {
        SourceUpdateAlertDialog({
          name: this.sourceUpdateAlertName,
          log: this.sourceUpdateAlertLog,
          updateUrl: this.sourceUpdateAlertUrl,
          onClose: () => {
            this.showSourceUpdateAlertDialog = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().appBackground)
  }

  @Builder
  private pageContent() {
    if (this.activeMainTab === MainTab.Home) {
      this.homePage()
    } else if (this.activeMainTab === MainTab.Explore) {
      this.explorePage()
    } else {
      this.profilePage()
    }
  }

  @Builder
  private homePage() {
    Stack() {
      HomeQueuePage({
        tracks: this.playQueueTracks(),
        currentTrackId: this.currentTrackId,
        playMode: this.playMode,
        activeCollectionTitle: this.activePlaybackCollectionTitle(),
        showRenameDialog: this.showRenameDialog,
        renameText: this.renameText,
        bottomInset: this.pageBottomInset,
        coveredTrackIds: this.trackArtworkIds,
        onOpenPlaylistDrawer: () => {
          this.showPlaybackCollectionDrawer = true;
        },
        onSelectPlayMode: (mode: PlayMode) => {
          this.playMode = mode;
          this.schedulePersistState();
        },
        onTrackTap: (track: MusicTrack) => {
          void this.handleTrackTap(track);
        },
        onToggleFavorite: (trackId: string) => {
          this.toggleFavorite(trackId);
        },
        onOpenRename: (track: MusicTrack) => {
          this.renameTrackId = track.id;
          this.renameText = track.title;
          this.showRenameDialog = true;
        },
        onRenameTextChange: (value: string) => {
          this.renameText = value;
        },
        onCancelRename: () => {
          this.showRenameDialog = false;
          this.renameTrackId = '';
          this.renameText = '';
        },
        onConfirmRename: () => {
          this.applyRename();
        },
        trackDurationText: (track: MusicTrack) => this.trackDurationText(track),
        coverForTrack: (trackId: string) => this.trackArtworkForTrack(trackId)
      })

      if (this.showPlaybackCollectionDrawer) {
        PlaybackCollectionDrawer({
          activeCollectionId: this.activePlaybackCollectionId,
          allCollection: allPlaybackCollectionSummary(this.localTracks),
          favoriteCollection: favoritePlaybackCollectionSummary(this.localTracks),
          albumCollections: albumPlaybackCollectionSummaries(this.localTracks),
          artistCollections: artistPlaybackCollectionSummaries(this.localTracks),
          customCollections: customPlaybackCollectionSummaries(this.customPlaylists, this.localTracks),
          importedTracks: this.localTracks,
          customPlaylists: this.customPlaylists,
          showAlbumCollections: this.playbackDrawerShowAlbumCollections,
          showArtistCollections: this.playbackDrawerShowArtistCollections,
          onClose: () => {
            this.showPlaybackCollectionDrawer = false;
          },
          onSelectCollection: (collectionId: string) => {
            this.selectPlaybackCollection(collectionId);
          },
          onCreateCustomPlaylist: (name: string) => {
            this.createPlaybackCustomPlaylist(name);
          },
          onDeleteCustomPlaylist: (playlistId: string) => {
            this.deletePlaybackCustomPlaylist(playlistId);
          },
          onToggleAlbumCollections: (expanded: boolean) => {
            this.playbackDrawerShowAlbumCollections = expanded;
            this.schedulePersistState();
          },
          onToggleArtistCollections: (expanded: boolean) => {
            this.playbackDrawerShowArtistCollections = expanded;
            this.schedulePersistState();
          },
          onToggleTrackInCustomPlaylist: (playlistId: string, trackId: string) => {
            this.toggleTrackInPlaybackCustomPlaylist(playlistId, trackId);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private explorePage() {
    Stack() {
      ExploreHallPage({
        musicSources: this.musicSources,
        activeSourceId: this.activeSourceId,
        activeSearchSource: this.activeSearchSource,
        sourceTracks: this.sourceTracks,
        sourceTracksLoading: this.sourceTracksLoading,
        sourceSearchKeyword: this.sourceSearchKeyword,
        sourceCurrentPage: this.sourceCurrentPage,
        sourceTotal: this.sourceTotal,
        sourceBoardList: this.sourceBoardList,
        sourceBoardsLoading: this.sourceBoardsLoading,
        activeBoardId: this.activeBoardId,
        exploreMode: this.exploreMode,
        bottomInset: this.pageBottomInset,
        sourceImportingTrackKeys: this.sourceImportingTrackKeys,
        sourceQualitySnapshot: this.sourceQualitySnapshot(this.getActiveSource()),
        onGoToProfile: () => {
          this.activeMainTab = MainTab.Profile;
        },
        onSelectSource: (source: MusicSourceConfig) => {
          this.activeSourceId = source.id;
          this.sourceTracks = [];
          this.sourceSearchKeyword = '';
          this.sourceCurrentPage = 1;
          this.exploreMode = 'board';
          this.sourceTotal = 0;
          let supportedSources = filterSupportedExploreSources(source.musicSources);
          if (supportedSources.length === 0) {
            this.activeSearchSource = '';
            this.sourceBoardList = [];
            this.activeBoardId = '';
            return;
          }
          this.activeSearchSource = resolvePreferredSubSource(source, this.activeSearchSource);
          void this.fetchBoardList(source, this.activeSearchSource);
        },
        onSelectSubSource: (sourceCode: string) => {
          if (this.activeSearchSource === sourceCode) {
            return;
          }
          this.activeSearchSource = sourceCode;
          this.sourceTracks = [];
          this.sourceCurrentPage = 1;
          if (this.exploreMode === 'board') {
            let source = this.getExploreActiveSource();
            if (source) {
              void this.fetchBoardList(source, sourceCode);
            }
          } else if (this.sourceSearchKeyword.trim().length > 0) {
            let source = this.getExploreActiveSource();
            if (source) {
              void this.searchSourceTracks(source, this.sourceSearchKeyword, sourceCode, 1);
            }
          }
        },
        onSelectSourceQuality: (sourceCode: string, quality: string) => {
          let source = this.getExploreActiveSource();
          if (source) {
            this.updateMusicSourcePreferredQuality(source.id, sourceCode, quality);
          }
        },
        onToggleMode: () => {
          if (this.exploreMode === 'board') {
            this.exploreMode = 'search';
            return;
          }
          this.exploreMode = 'board';
          this.sourceSearchKeyword = '';
          let source = this.getExploreActiveSource();
          if (source && this.sourceBoardList.length === 0) {
            void this.fetchBoardList(source, this.activeSearchSource);
          } else if (this.activeBoardId.length > 0 && source) {
            this.sourceTracks = [];
            void this.fetchBoardTracks(source, this.activeSearchSource, this.activeBoardId, 1);
          }
        },
        onSearchKeywordChange: (value: string) => {
          this.sourceSearchKeyword = value;
        },
        onSearch: () => {
          let source = this.getExploreActiveSource();
          if (source) {
            this.exploreMode = 'search';
            void this.searchSourceTracks(source, this.sourceSearchKeyword, this.activeSearchSource, 1);
          }
        },
        onSelectBoard: (board: SourceBoardItem) => {
          if (this.activeBoardId === board.bangid && this.exploreMode === 'board') {
            return;
          }
          this.exploreMode = 'board';
          this.activeBoardId = board.bangid;
          this.sourceTracks = [];
          this.sourceCurrentPage = 1;
          let source = this.getExploreActiveSource();
          if (source) {
            void this.fetchBoardTracks(source, this.activeSearchSource, board.bangid, 1);
          }
        },
        onImportTrack: (track: MusicSourceTrack) => {
          let source = this.getExploreActiveSource();
          if (source) {
            this.enqueueSourceTrackImport(source, track);
          }
        },
        onLoadMore: () => {
          let source = this.getExploreActiveSource();
          if (source) {
            if (this.exploreMode === 'board') {
              void this.fetchBoardTracks(source, this.activeSearchSource, this.activeBoardId, this.sourceCurrentPage + 1);
            } else {
              void this.searchSourceTracks(source, this.sourceSearchKeyword, this.activeSearchSource, this.sourceCurrentPage + 1);
            }
          }
        },
        sourceTrackActionLabel: (track: MusicSourceTrack) => this.sourceTrackActionLabel(track),
        sourceTrackActionEnabled: (track: MusicSourceTrack) => this.sourceTrackActionEnabled(track)
      })
      

      if (this.showSourceManager) {
        SourceManagerPanel({
          musicSources: this.musicSources,
          addSourceLoading: this.addSourceLoading,
          sourceUrlInput: this.sourceUrlInput,
          onClose: () => {
            this.closeSourceManager();
          },
          onSourceUrlChange: (value: string) => {
            this.sourceUrlInput = value;
          },
          onAddFromFile: () => {
            void this.addMusicSourceFromFile();
          },
          onAddFromUrl: () => {
            void this.addMusicSourceFromUrl();
          },
          onToggleUpdateAlert: (sourceId: string) => {
            this.toggleMusicSourceAllowShowUpdateAlert(sourceId);
          },
          onRemoveSource: (sourceId: string) => {
            this.removeMusicSource(sourceId);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private profilePage() {
    Stack() {
      ProfilePageContent({
        totalHours: totalListeningHours(this.totalListeningMs),
        themeModeLabel: appThemeModeLabel(this.appThemeMode),
        musicSources: this.musicSources,
        importedTrackCount: this.localTracks.length,
        playQueueTrackCount: this.playQueueTracks().length,
        bottomInset: this.pageBottomInset,
        onImportLocal: () => {
          void this.importLocalMusic();
        },
        onOpenBaiduPanImport: () => {
          this.openBaiduPanImportPanel();
        },
        onOpenThemeMode: () => {
          this.showThemeModePanel = true;
        },
        onOpenImportedTrackManager: () => {
          this.showImportedTrackManager = true;
        },
        onOpenSourceManager: () => {
          this.showSourceManager = true;
        },
        onBrowseSource: (source: MusicSourceConfig) => {
          this.openSourceBrowser(source);
        },
        onOpenEqualizer: () => {
          this.showToast('均衡器调节将在下一版补充');
        }
      })

      if (this.showSourceManager) {
        SourceManagerPanel({
          musicSources: this.musicSources,
          addSourceLoading: this.addSourceLoading,
          sourceUrlInput: this.sourceUrlInput,
          onClose: () => {
            this.closeSourceManager();
          },
          onSourceUrlChange: (value: string) => {
            this.sourceUrlInput = value;
          },
          onAddFromFile: () => {
            void this.addMusicSourceFromFile();
          },
          onAddFromUrl: () => {
            void this.addMusicSourceFromUrl();
          },
          onToggleUpdateAlert: (sourceId: string) => {
            this.toggleMusicSourceAllowShowUpdateAlert(sourceId);
          },
          onRemoveSource: (sourceId: string) => {
            this.removeMusicSource(sourceId);
          }
        })
      }

      if (this.showThemeModePanel) {
        ThemeModePanel({
          currentMode: this.appThemeMode,
          onClose: () => {
            this.showThemeModePanel = false;
          },
          onSelectMode: (mode: AppThemeMode) => {
            this.applyThemeMode(mode, true);
            this.showThemeModePanel = false;
          }
        })
      }

      if (this.showImportedTrackManager) {
        ImportedTrackManagerPanel({
          tracks: this.localTracks,
          coveredTrackIds: this.trackArtworkIds,
          onClose: () => {
            this.showImportedTrackManager = false;
          },
          onMoveTrackBefore: (trackId: string, referenceTrackId: string) => {
            this.moveImportedTrackBefore(trackId, referenceTrackId);
          },
          onMoveTrackAfter: (trackId: string, referenceTrackId: string) => {
            this.moveImportedTrackAfter(trackId, referenceTrackId);
          },
          onToggleTrackInPlayQueue: (trackId: string) => {
            this.toggleTrackInPlayQueue(trackId);
          },
          onRemoveTrack: (trackId: string) => {
            void this.removeImportedTrack(trackId);
          },
          onRemoveTracks: (trackIds: string[]) => {
            void this.removeImportedTracks(trackIds);
          },
          coverForTrack: (trackId: string) => this.trackArtworkForTrack(trackId)
        })
      }

      if (this.showBaiduPanImportPanel) {
        BaiduPanImportPanel({
          appKey: this.baiduPanAppKey,
          accessToken: this.baiduPanAccessToken,
          currentDir: this.baiduPanCurrentDir,
          entries: this.baiduPanEntries,
          isLoading: this.baiduPanLoading,
          importingKeys: this.baiduPanImportingKeys,
          importedKeySnapshot: this.baiduPanImportedKeySnapshot(),
          onClose: () => {
            this.closeBaiduPanImportPanel();
          },
          onAppKeyChange: (value: string) => {
            if (value.trim() !== this.baiduPanAppKey.trim()) {
              this.baiduPanAccessToken = '';
              this.baiduPanEntries = [];
              this.baiduPanCurrentDir = '/';
              this.baiduPanAuthUrl = '';
            }
            this.baiduPanAppKey = value;
          },
          onOpenAuth: () => {
            this.openBaiduPanAuthPanel();
          },
          onRefresh: () => {
            void this.loadBaiduPanDirectory(this.baiduPanCurrentDir);
          },
          onEnterDirectory: (entry: BaiduPanEntry) => {
            void this.enterBaiduPanDirectory(entry);
          },
          onGoParent: () => {
            void this.goParentBaiduPanDirectory();
          },
          onImportEntry: (entry: BaiduPanEntry) => {
            void this.importBaiduPanEntry(entry);
          }
        })
      }

      if (this.showBaiduPanAuthPanel) {
        BaiduPanAuthPanel({
          appKey: this.baiduPanAppKey,
          authUrl: this.baiduPanAuthUrl,
          isAuthorizing: this.baiduPanAuthUrl.trim().length > 0,
          onClose: () => {
            this.closeBaiduPanAuthPanel();
          },
          onAppKeyChange: (value: string) => {
            if (value.trim() !== this.baiduPanAppKey.trim()) {
              this.baiduPanAppKey = value;
              this.baiduPanAccessToken = '';
              this.baiduPanEntries = [];
              this.baiduPanCurrentDir = '/';
              this.baiduPanAuthUrl = '';
            }
          },
          onStartAuth: () => {
            this.startBaiduPanAuth();
          },
          onObservedPayload: (payload: string) => {
            this.handleBaiduPanAuthPayload(payload);
          }
        })
      }

      if (this.showSourceBrowser) {
        SourceBrowserPanel({
          title: this.getActiveSource()?.name ?? '音源浏览',
          subSources: filterSupportedExploreSources(this.getActiveSource()?.musicSources ?? []),
          activeSearchSource: this.activeSearchSource,
          sourceSearchKeyword: this.sourceSearchKeyword,
          sourceTracks: this.sourceTracks,
          sourceTracksLoading: this.sourceTracksLoading,
          sourceTotal: this.sourceTotal,
          sourceCurrentPage: this.sourceCurrentPage,
          sourceImportingTrackKeys: this.sourceImportingTrackKeys,
          sourceQualitySnapshot: this.sourceQualitySnapshot(this.getActiveSource()),
          onClose: () => {
            this.closeSourceBrowser();
          },
          onSelectSubSource: (sourceCode: string) => {
            this.activeSearchSource = sourceCode;
            this.sourceTracks = [];
            if (this.sourceSearchKeyword.trim().length > 0) {
              let source = this.getActiveSource();
              if (source) {
                void this.searchSourceTracks(source, this.sourceSearchKeyword, sourceCode, 1);
              }
            }
          },
          onSelectQuality: (sourceCode: string, quality: string) => {
            let source = this.getActiveSource();
            if (source) {
              this.updateMusicSourcePreferredQuality(source.id, sourceCode, quality);
            }
          },
          onSearchKeywordChange: (value: string) => {
            this.sourceSearchKeyword = value;
          },
          onSearch: () => {
            let source = this.getActiveSource();
            if (source) {
              void this.searchSourceTracks(source, this.sourceSearchKeyword, this.activeSearchSource, 1);
            }
          },
          onLoadMore: () => {
            let source = this.getActiveSource();
            if (source) {
              void this.searchSourceTracks(source, this.sourceSearchKeyword, this.activeSearchSource, this.sourceCurrentPage + 1);
            }
          },
          onImportTrack: (track: MusicSourceTrack) => {
            let source = this.getActiveSource();
            if (source) {
              this.enqueueSourceTrackImport(source, track);
            }
          },
          sourceTrackActionLabel: (track: MusicSourceTrack) => this.sourceTrackActionLabel(track),
          sourceTrackActionEnabled: (track: MusicSourceTrack) => this.sourceTrackActionEnabled(track)
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  private visibleTracks(): Array<MusicTrack> {
    return selectVisibleTracks(this.localTracks, this.recentTrackIds, this.collectionMode, this.searchKeyword);
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private syncThemeStorage(): void {
    if (AppStorage.has('appThemeMode')) {
      AppStorage.set('appThemeMode', this.appThemeMode);
    } else {
      AppStorage.setOrCreate('appThemeMode', this.appThemeMode);
    }
    if (AppStorage.has('appThemeAppearance')) {
      AppStorage.set('appThemeAppearance', this.themeAppearance);
    } else {
      AppStorage.setOrCreate('appThemeAppearance', this.themeAppearance);
    }
  }

  private resolveSystemColorMode(): ConfigurationConstant.ColorMode {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } catch (error) {
      console.error(`resolve system color mode failed: ${JSON.stringify(error)}`);
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
  }

  private updateApplicationColorMode(mode: AppThemeMode): void {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.getApplicationContext().setColorMode(appThemeModeToColorMode(mode));
    } catch (error) {
      console.error(`apply app theme mode failed: ${JSON.stringify(error)}`);
    }
  }

  private applyThemeMode(mode: AppThemeMode, shouldPersist: boolean): void {
    this.appThemeMode = mode;
    this.updateApplicationColorMode(mode);
    this.systemColorMode = this.resolveSystemColorMode();
    this.themeAppearance = resolveAppThemeAppearance(mode, this.systemColorMode);
    this.syncThemeStorage();
    if (shouldPersist) {
      this.schedulePersistState();
    }
  }

  private currentTrack(): MusicTrack {
    return selectCurrentTrack(this.localTracks, this.currentTrackId);
  }

  private sourceQualitySnapshot(source: MusicSourceConfig | undefined): string {
    if (!source) {
      return '';
    }
    return source.musicSources
      .map((item: MusicSourceQuality) => `${item.source}:${item.preferredQuality ?? ''}:${item.qualitys.join(',')}`)
      .join('|');
  }

  private playQueueTracks(): Array<MusicTrack> {
    return playbackCollectionTracks(this.localTracks, this.customPlaylists, this.activePlaybackCollectionId);
  }

  private selectablePlaybackCollections(): PlaybackCollectionSummary[] {
    return playbackCollectionSelectorSummaries(this.localTracks, this.customPlaylists);
  }

  private activePlaybackCollectionTitle(): string {
    return playbackCollectionSummaryById(this.localTracks, this.customPlaylists, this.activePlaybackCollectionId).title;
  }

  private ensureActivePlaybackCollectionValid(): void {
    if (!playbackCollectionExists(this.localTracks, this.customPlaylists, this.activePlaybackCollectionId)) {
      this.activePlaybackCollectionId = DEFAULT_PLAYBACK_COLLECTION_ID;
    }
  }

  private selectPlaybackCollection(collectionId: string): void {
    this.activePlaybackCollectionId = collectionId;
    this.ensureActivePlaybackCollectionValid();
    this.syncCurrentTrackSelection();
    this.schedulePersistState();
  }

  private createPlaybackCustomPlaylist(name: string): void {
    let result = createCustomPlaylist(this.customPlaylists, name);
    if (result.createdPlaylistId.length === 0) {
      this.showToast('请输入播放列表名称');
      return;
    }
    this.customPlaylists = result.playlists;
    this.activePlaybackCollectionId = buildCustomPlaybackCollectionId(result.createdPlaylistId);
    this.syncCurrentTrackSelection();
    this.schedulePersistState();
    this.showToast('已创建自定义播放列表');
  }

  private deletePlaybackCustomPlaylist(playlistId: string): void {
    let result = removeCustomPlaylist(this.customPlaylists, playlistId);
    if (!result.removed) {
      return;
    }
    this.customPlaylists = result.playlists;
    this.ensureActivePlaybackCollectionValid();
    this.syncCurrentTrackSelection();
    this.schedulePersistState();
    this.showToast('已删除自定义播放列表');
  }

  private toggleTrackInPlaybackCustomPlaylist(playlistId: string, trackId: string): void {
    let result = toggleTrackInCustomPlaylist(this.customPlaylists, playlistId, trackId);
    this.customPlaylists = result.playlists;
    this.syncCurrentTrackSelection();
    this.schedulePersistState();
    this.showToast(result.included ? '已加入自定义播放列表' : '已从自定义播放列表移除');
  }

  private firstPlayQueueTrack(): MusicTrack | null {
    let queueTracks = this.playQueueTracks();
    return queueTracks.length > 0 ? queueTracks[0] : null;
  }

  private async refreshAVSessionQueue(): Promise<void> {
    if (!this.session) {
      return;
    }
    try {
      let collections = this.selectablePlaybackCollections();
      await this.session.setAVQueueTitle(buildPlaybackCollectionQueueTitle());
      await this.session.setAVQueueItems(
        buildPlaybackCollectionQueueItems(collections, this.activePlaybackCollectionId)
      );
    } catch (error) {
      console.error(`refresh AVSession queue failed: ${JSON.stringify(error)}`);
    }
  }

  private async handleAVSessionAssetSelection(assetId: string): Promise<void> {
    let targetCollection = this.selectablePlaybackCollections()
      .find((summary: PlaybackCollectionSummary) => summary.id === assetId);
    if (targetCollection) {
      await this.selectPlaybackCollectionForCar(targetCollection.id);
      return;
    }

    let targetTrack = this.localTracks.find((track: MusicTrack) => track.id === assetId);
    if (targetTrack) {
      await this.startTrackPlayback(targetTrack);
    }
  }

  private async selectPlaybackCollectionForCar(collectionId: string): Promise<void> {
    let queueTracks = playbackCollectionTracks(this.localTracks, this.customPlaylists, collectionId);
    if (queueTracks.length === 0) {
      this.showToast('所选列表当前没有可播放歌曲');
      return;
    }

    let previousCollectionId = this.activePlaybackCollectionId;
    this.activePlaybackCollectionId = collectionId;
    this.ensureActivePlaybackCollectionValid();
    this.syncCurrentTrackSelection(queueTracks[0].id);
    this.schedulePersistState();
    void this.refreshAVSessionQueue();

    let shouldKeepCurrentTrack = previousCollectionId === collectionId &&
      this.loadedTrackId.length > 0 &&
      trackBelongsToPlaybackCollection(
        this.loadedTrackId,
        this.localTracks,
        this.customPlaylists,
        this.activePlaybackCollectionId
      );
    if (shouldKeepCurrentTrack) {
      return;
    }
    await this.startTrackPlayback(queueTracks[0]);
  }

  private bindAVSessionAssetSelection(session: avSession.AVSession): void {
    try {
      session.on('playWithAssetId', (assetId: string) => {
        void this.handleAVSessionAssetSelection(assetId);
      });
    } catch (error) {
      console.warn(`register playWithAssetId failed: ${JSON.stringify(error)}`);
    }
  }

  private syncCurrentTrackSelection(preferredTrackId: string = ''): void {
    this.ensureActivePlaybackCollectionValid();
    let current = this.localTracks.find((track: MusicTrack) => track.id === this.currentTrackId);
    if (current) {
      let isCurrentLoaded = this.loadedTrackId === current.id;
      if (trackBelongsToPlaybackCollection(current.id, this.localTracks, this.customPlaylists, this.activePlaybackCollectionId) ||
        isCurrentLoaded) {
        return;
      }
    }

    if (preferredTrackId.length > 0) {
      let preferredTrack = this.localTracks.find((track: MusicTrack) => track.id === preferredTrackId);
      if (preferredTrack && trackBelongsToPlaybackCollection(
        preferredTrack.id,
        this.localTracks,
        this.customPlaylists,
        this.activePlaybackCollectionId
      )) {
        this.currentTrackId = preferredTrack.id;
        return;
      }
    }

    let firstTrack = this.firstPlayQueueTrack();
    this.currentTrackId = firstTrack ? firstTrack.id : MINI_PLACEHOLDER_TRACK.id;
  }

  private progressRatio(): number {
    return playbackProgressRatio(this.playbackProgressMs, this.playbackDurationMs);
  }

  private displayedPlaybackProgressMs(): number {
    return this.isSeekingPlayback ? this.seekPreviewMs : this.playbackProgressMs;
  }

  private clampSeekMs(value: number): number {
    let safeValue = Math.max(0, Math.floor(value));
    if (this.playbackDurationMs <= 0) {
      return safeValue;
    }
    return Math.min(safeValue, this.playbackDurationMs);
  }

  private setMiniPlayButtonState(showPause: boolean, transitioning: boolean): void {
    this.playButtonShowsPause = showPause;
    this.isPlayButtonTransitioning = transitioning;
  }

  private handlePlayButtonTouch(event: TouchEvent): void {
    this.playButtonScale = event.type === TouchType.Down ? 0.92 : 1;
  }

  private handleNextButtonTouch(event: TouchEvent): void {
    this.nextButtonScale = event.type === TouchType.Down ? 0.92 : 1;
  }

  private handleMiniSeekChange(value: number, mode: SliderChangeMode): void {
    let targetMs = this.clampSeekMs(value);
    if (mode === SliderChangeMode.Begin) {
      this.isSeekingPlayback = true;
      this.seekPreviewMs = targetMs;
      return;
    }
    if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click) {
      this.isSeekingPlayback = true;
      this.seekPreviewMs = targetMs;
      return;
    }
    if (mode === SliderChangeMode.End) {
      this.seekPreviewMs = targetMs;
      this.isSeekingPlayback = false;
      void this.seekCurrentTrack(targetMs);
    }
  }

  private async seekCurrentTrack(targetMs: number): Promise<void> {
    if (!this.player || this.playbackDurationMs <= 0) {
      return;
    }
    let state = this.player.state;
    if (state !== 'prepared' && state !== 'playing' && state !== 'paused' && state !== 'completed') {
      return;
    }
    let clampedTargetMs = this.clampSeekMs(targetMs);
    try {
      this.playbackProgressMs = clampedTargetMs;
      this.lastProgressSnapshotMs = clampedTargetMs;
      this.player.seek(clampedTargetMs);
      void this.updateMusicLiveView(this.isPlaying);
      void this.updateAVSessionState(this.isPlaying);
    } catch (error) {
      console.error(`seek failed: ${JSON.stringify(error)}`);
      this.showToast('调整播放进度失败');
    }
  }

  private async startMusicLiveView(track: MusicTrack): Promise<void> {
    try {
      let enabled = await liveViewManager.isLiveViewEnabled();
      if (!enabled) {
        console.info('live view is disabled');
        return;
      }
      this.liveViewSequence = 1;
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let clickAction = await createPlaybackWantAgent(context, 'com.opensource.metis.music', 'EntryAbility');
      this.liveView = createPlaybackLiveView(track, clickAction, this.liveViewSequence);
      await liveViewManager.startLiveView(this.liveView);
      console.info('startMusicLiveView succeeded');
    } catch (error) {
      console.error(`startMusicLiveView failed: ${JSON.stringify(error)}`);
    }
  }

  private async updateMusicLiveView(playing: boolean): Promise<void> {
    if (!this.liveView) {
      return;
    }
    try {
      this.liveViewSequence += 1;
      let track = this.currentTrack();
      let progress = this.playbackDurationMs > 0 ? Math.round(this.playbackProgressMs / this.playbackDurationMs * 100) : 0;
      this.liveView = applyPlaybackLiveViewUpdate(this.liveView, track, this.liveViewSequence, progress, playing);
      await liveViewManager.updateLiveView(this.liveView);
    } catch (error) {
      console.error(`updateMusicLiveView failed: ${JSON.stringify(error)}`);
    }
  }

  private async stopMusicLiveView(): Promise<void> {
    if (!this.liveView) {
      return;
    }
    try {
      this.liveViewSequence += 1;
      this.liveView = applyStoppedLiveViewUpdate(this.liveView, this.liveViewSequence);
      await liveViewManager.stopLiveView(this.liveView);
      this.liveView = null;
      console.info('stopMusicLiveView succeeded');
    } catch (error) {
      console.error(`stopMusicLiveView failed: ${JSON.stringify(error)}`);
      this.liveView = null;
    }
  }

  private async createAVSession(track: MusicTrack): Promise<void> {
    try {
      await this.destroyAVSession();
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let clickAction = await createPlaybackWantAgent(context, 'com.opensource.metis.music', 'EntryAbility');
      let session = await avSession.createAVSession(context, 'MusicPlayer', 'audio');
      this.session = session;
      await session.setAVMetadata(createSessionMetadata(track));
      await session.setLaunchAbility(clickAction);
      await this.refreshAVSessionQueue();

      session.on('play', () => {
        void this.resumeCurrentTrack();
      });
      session.on('pause', () => {
        void this.pauseCurrentTrack();
      });
      session.on('playNext', () => {
        void this.playNextTrack();
      });
      session.on('playPrevious', () => {
        void this.playPreviousTrack();
      });
      session.on('toggleFavorite', (assetId: string) => {
        this.toggleFavorite(assetId);
      });
      this.bindAVSessionAssetSelection(session);

      await session.activate();
      console.info('createAVSession succeeded');
    } catch (error) {
      console.error(`createAVSession failed: ${JSON.stringify(error)}`);
    }
  }

  private async updateAVSessionState(playing: boolean): Promise<void> {
    if (!this.session) {
      return;
    }
    try {
      await this.session.setAVPlaybackState(
        createPlaybackState(playing, this.playbackProgressMs, this.playbackDurationMs)
      );
    } catch (error) {
      console.error(`updateAVSessionState failed: ${JSON.stringify(error)}`);
    }
  }

  private async destroyAVSession(): Promise<void> {
    if (!this.session) {
      return;
    }
    try {
      await this.session.destroy();
      this.session = null;
      console.info('destroyAVSession succeeded');
    } catch (error) {
      console.error(`destroyAVSession failed: ${JSON.stringify(error)}`);
      this.session = null;
    }
  }

  private async startBackgroundTask(): Promise<void> {
    if (this.isBackgroundTaskRunning) {
      return;
    }
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let clickAction = await createPlaybackWantAgent(context, 'com.opensource.metis.music', 'EntryAbility');
      await startAudioBackgroundTask(context, clickAction);
      this.isBackgroundTaskRunning = true;
      console.info('startBackgroundTask succeeded');
    } catch (error) {
      console.error(`startBackgroundTask failed: ${JSON.stringify(error)}`);
    }
  }

  private async stopBackgroundTask(): Promise<void> {
    if (!this.isBackgroundTaskRunning) {
      return;
    }
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await stopAudioBackgroundTask(context);
      this.isBackgroundTaskRunning = false;
      console.info('stopBackgroundTask succeeded');
    } catch (error) {
      console.error(`stopBackgroundTask failed: ${JSON.stringify(error)}`);
    }
  }

  private startDiscRotation(): void {
    if (this.discRotationTimer >= 0) {
      return;
    }
    this.discRotationTimer = setInterval(() => {
      this.discRotationAngle += 2;
    }, 30) as number;
  }

  private stopDiscRotation(): void {
    if (this.discRotationTimer < 0) {
      return;
    }
    clearInterval(this.discRotationTimer);
    this.discRotationTimer = -1;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1800
      });
    } catch (error) {
      console.error(`show toast failed: ${JSON.stringify(error)}`);
    }
  }

  private handleSourceConsoleLog(payloadJson: string): void {
    try {
      let payload = JSON.parse(payloadJson) as QuickJsLogPayload;
      let message = payload && typeof payload.log === 'string' ? payload.log : payloadJson;
      if (payload.type === 'warn') {
        console.warn(`[source-script] ${message}`);
      } else if (payload.type === 'error') {
        console.error(`[source-script] ${message}`);
      } else {
        console.info(`[source-script] ${message}`);
      }
    } catch (error) {
      console.info(`[source-script] ${payloadJson}`);
      console.error(`parse source log payload failed: ${JSON.stringify(error)}`);
    }
  }

  private handleSourceUpdateAlert(payloadJson: string): void {
    try {
      let payload = JSON.parse(payloadJson) as SourceUpdateAlertPayload;
      let activeSource = this.musicSources.find((source: MusicSourceConfig) => source.id === this.jsEngineSourceId);
      if (activeSource && activeSource.allowShowUpdateAlert === false) {
        return;
      }
      this.sourceUpdateAlertName = payload && typeof payload.name === 'string' && payload.name.length > 0
        ? payload.name
        : (activeSource?.name || '音源');
      this.sourceUpdateAlertLog = payload && typeof payload.log === 'string' && payload.log.length > 0
        ? payload.log
        : '脚本发来了一个更新提醒';
      this.sourceUpdateAlertUrl = payload && typeof payload.updateUrl === 'string' ? payload.updateUrl : '';
      this.showSourceUpdateAlertDialog = true;
    } catch (error) {
      console.error(`parse source update alert failed: ${JSON.stringify(error)}`);
    }
  }

  private closeSourceManager(): void {
    this.showSourceManager = false;
    this.showAddSourceDialog = false;
  }

  private closeSourceBrowser(): void {
    this.showSourceBrowser = false;
    this.sourceTracks = [];
    this.sourceSearchKeyword = '';
  }

  private clearExploreResults(): void {
    this.sourceTracks = [];
    this.sourceTotal = 0;
    this.sourceCurrentPage = 1;
    this.sourceBoardList = [];
    this.activeBoardId = '';
    this.sourceBoardsLoading = false;
    this.sourceTracksLoading = false;
  }

  private ensureExploreSourceReady(triggerFetch: boolean): MusicSourceConfig | undefined {
    if (this.musicSources.length === 0) {
      this.activeSourceId = '';
      this.activeSearchSource = '';
      this.clearExploreResults();
      return undefined;
    }

    let source = this.musicSources.find((item: MusicSourceConfig) => item.id === this.activeSourceId) ?? this.musicSources[0];
    if (this.activeSourceId !== source.id) {
      this.activeSourceId = source.id;
    }

    let supportedSources = filterSupportedExploreSources(source.musicSources);
    if (supportedSources.length === 0) {
      this.activeSearchSource = '';
      this.clearExploreResults();
      return source;
    }

    let nextSearchSource = resolvePreferredSubSource(source, this.activeSearchSource);
    let shouldRefreshBoards = this.activeSearchSource !== nextSearchSource || this.sourceBoardList.length === 0 || this.activeBoardId.length === 0;
    this.activeSearchSource = nextSearchSource;
    if (triggerFetch && this.exploreMode === 'board' && shouldRefreshBoards && !this.sourceBoardsLoading) {
      void this.fetchBoardList(source, nextSearchSource);
    }
    return source;
  }

  private openSourceBrowser(source: MusicSourceConfig): void {
    this.activeSourceId = source.id;
    this.sourceTracks = [];
    this.sourceSearchKeyword = '';
    this.sourceCurrentPage = 1;
    let supportedSources = filterSupportedExploreSources(source.musicSources);
    this.activeSearchSource = supportedSources.length > 0 ? resolvePreferredSubSource(source, this.activeSearchSource) : '';
    this.showSourceBrowser = true;
  }

  private async initializeAppState(): Promise<void> {
    this.isRestoringState = true;
    try {
      await this.restorePersistedState();
      await this.activatePersistedUriPermissions();
    } catch (error) {
      console.error(`initialize app state failed: ${JSON.stringify(error)}`);
    } finally {
      this.isRestoringState = false;
      this.syncTrackMetadataCaches();
    }
  }

  private async ensureAppDatabaseStore(): Promise<relationalStore.RdbStore> {
    if (this.appDatabase !== null) {
      return this.appDatabase;
    }
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.appDatabase = await ensureAppDatabase(this.appDatabase, context);
      return this.appDatabase;
    } catch (error) {
      console.error(`ensure app database failed: ${JSON.stringify(error)}`);
      throw new Error('ensure app database failed');
    }
  }

  private async getMusicSourceScript(sourceId: string): Promise<string> {
    let store = await this.ensureAppDatabaseStore();
    return await readMusicSourceScript(store, this.musicSourceScripts, sourceId);
  }

  private async deleteMusicSourceScript(sourceId: string): Promise<void> {
    let store = await this.ensureAppDatabaseStore();
    await deletePersistedMusicSourceScript(store, this.musicSourceScripts, sourceId);
  }

  private async restorePersistedState(): Promise<void> {
    let store = await this.ensureAppDatabaseStore();
    let restoredState = await restorePersistedAppState(store);
    this.localTracks = restoredState.localTracks;
    this.recentTrackIds = restoredState.recentTrackIds;
    this.currentTrackId = restoredState.currentTrackId;
    this.collectionMode = restoredState.collectionMode;
    this.totalListeningMs = restoredState.totalListeningMs;
    this.playMode = restoredState.playMode;
    this.applyThemeMode(restoredState.appThemeMode, false);
    this.customPlaylists = restoredState.customPlaylists;
    this.activePlaybackCollectionId = restoredState.activePlaybackCollectionId;
    this.playbackDrawerShowAlbumCollections = restoredState.playbackDrawerShowAlbumCollections;
    this.playbackDrawerShowArtistCollections = restoredState.playbackDrawerShowArtistCollections;
    this.baiduPanAppKey = restoredState.baiduPanAppKey;
    this.baiduPanAccessToken = restoredState.baiduPanAccessToken;
    this.baiduPanCurrentDir = restoredState.baiduPanCurrentDir;
    this.musicSources = restoredState.musicSources;
    this.musicSourceScripts = restoredState.musicSourceScripts;
    this.ensureActivePlaybackCollectionValid();
    this.syncCurrentTrackSelection();
  }

  private trackArtworkForTrack(trackId: string): image.PixelMap | null {
    let ownerTrackId = this.trackArtworkOwnerMap.get(trackId) ?? trackId;
    return this.trackArtworkMap.get(ownerTrackId) ?? null;
  }

  private normalizedArtworkAlbum(track: MusicTrack): string {
    let album = track.album.trim().toLowerCase();
    if (album.length === 0 || album === '网络导入') {
      return '';
    }
    return album;
  }

  private normalizedArtworkFolder(track: MusicTrack): string {
    let folder = track.folder.trim().toLowerCase();
    if (folder.length === 0 || folder === '在线下载' || folder === 'downloads') {
      return '';
    }
    return folder;
  }

  private canShareArtworkBetweenTracks(track: MusicTrack, candidate: MusicTrack): boolean {
    let trackAlbum = this.normalizedArtworkAlbum(track);
    let candidateAlbum = this.normalizedArtworkAlbum(candidate);
    if (trackAlbum.length > 0 && candidateAlbum.length > 0) {
      return trackAlbum === candidateAlbum;
    }

    let trackFolder = this.normalizedArtworkFolder(track);
    let candidateFolder = this.normalizedArtworkFolder(candidate);
    return trackAlbum.length === 0 &&
      candidateAlbum.length === 0 &&
      trackFolder.length > 0 &&
      trackFolder === candidateFolder;
  }

  private findReusableArtworkOwner(track: MusicTrack): string {
    for (let index = 0; index < this.localTracks.length; index++) {
      let candidate = this.localTracks[index];
      if (candidate.id === track.id) {
        continue;
      }
      if (!this.canShareArtworkBetweenTracks(track, candidate)) {
        continue;
      }
      let candidateOwnerId = this.trackArtworkOwnerMap.get(candidate.id) ?? candidate.id;
      if (this.trackArtworkMap.has(candidateOwnerId)) {
        return candidateOwnerId;
      }
    }
    return '';
  }

  private refreshAlbumArtworkAliases(): void {
    this.localTracks.forEach((track: MusicTrack) => {
      if (this.trackArtworkMap.has(track.id)) {
        this.trackArtworkOwnerMap.set(track.id, track.id);
        return;
      }
      let ownerId = this.findReusableArtworkOwner(track);
      if (ownerId.length > 0) {
        this.trackArtworkOwnerMap.set(track.id, ownerId);
        this.trackArtworkUnavailableIds.delete(track.id);
        return;
      }
      this.trackArtworkOwnerMap.delete(track.id);
    });
  }

  private syncTrackMetadataCaches(): void {
    this.syncTrackArtworkCache();
    this.syncTrackDurationCache();
  }

  private refreshTrackArtworkIds(): void {
    this.trackArtworkIds = this.localTracks.filter((track: MusicTrack) => this.trackArtworkForTrack(track.id) !== null)
      .map((track: MusicTrack) => track.id);
  }

  private syncTrackArtworkCache(): void {
    let activeTrackIds = this.localTracks.map((track: MusicTrack) => track.id);

    Array.from(this.trackArtworkMap.keys()).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) {
        void this.releaseCachedTrackArtwork(trackId);
      }
    });

    Array.from(this.trackArtworkOwnerMap.keys()).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) {
        this.trackArtworkOwnerMap.delete(trackId);
      }
    });

    Array.from(this.trackArtworkLoadingIds).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) {
        this.trackArtworkLoadingIds.delete(trackId);
      }
    });

    Array.from(this.trackArtworkUnavailableIds).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) {
        this.trackArtworkUnavailableIds.delete(trackId);
      }
    });

    this.refreshAlbumArtworkAliases();
    this.refreshTrackArtworkIds();

    this.localTracks.forEach((track: MusicTrack) => {
      let hasPlayableFile = track.filePath.length > 0 || track.sourceUri.length > 0;
      if (!hasPlayableFile || this.trackArtworkForTrack(track.id) !== null || this.trackArtworkLoadingIds.has(track.id) ||
        this.trackArtworkUnavailableIds.has(track.id)) {
        return;
      }
      void this.loadTrackArtwork(track);
    });
  }

  private syncTrackDurationCache(): void {
    let activeTrackIds = this.localTracks.map((track: MusicTrack) => track.id);

    Array.from(this.trackDurationLoadingIds).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) {
        this.trackDurationLoadingIds.delete(trackId);
      }
    });

    Array.from(this.trackDurationUnavailableIds).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) {
        this.trackDurationUnavailableIds.delete(trackId);
      }
    });

    this.localTracks.forEach((track: MusicTrack) => {
      let hasPlayableFile = track.filePath.length > 0 || track.sourceUri.length > 0;
      if (!hasPlayableFile || track.durationMs > 0 || this.trackDurationLoadingIds.has(track.id) ||
        this.trackDurationUnavailableIds.has(track.id)) {
        return;
      }
      void this.loadTrackDuration(track);
    });
  }

  private async loadTrackDuration(track: MusicTrack): Promise<void> {
    this.trackDurationLoadingIds.add(track.id);
    try {
      let durationMs = await extractTrackDuration(track);
      if (!this.localTracks.some((item: MusicTrack) => item.id === track.id)) {
        return;
      }
      if (durationMs <= 0) {
        this.trackDurationUnavailableIds.add(track.id);
        return;
      }
      this.trackDurationUnavailableIds.delete(track.id);
      this.cacheTrackDuration(track.id, durationMs, true);
    } finally {
      this.trackDurationLoadingIds.delete(track.id);
    }
  }

  private cacheTrackDuration(trackId: string, durationMs: number, shouldPersist: boolean): void {
    if (durationMs <= 0) {
      return;
    }
    let localIndex = this.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (localIndex < 0) {
      return;
    }
    let currentTrack = this.localTracks[localIndex];
    if (currentTrack.durationMs === durationMs) {
      return;
    }
    let updatedTracks = this.localTracks.slice();
    let updatedTrack = copyTrack(currentTrack);
    updatedTrack.durationMs = durationMs;
    updatedTracks[localIndex] = updatedTrack;
    this.localTracks = updatedTracks;
    this.trackDurationUnavailableIds.delete(trackId);
    if (shouldPersist) {
      this.schedulePersistState();
    }
  }

  private async loadTrackArtwork(track: MusicTrack): Promise<void> {
    this.trackArtworkLoadingIds.add(track.id);
    try {
      let pixelMap = await extractTrackArtwork(track);
      if (!this.localTracks.some((item: MusicTrack) => item.id === track.id)) {
        await releaseExtractedTrackArtwork(pixelMap);
        return;
      }
      if (pixelMap === null) {
        this.refreshAlbumArtworkAliases();
        this.refreshTrackArtworkIds();
        if (this.trackArtworkForTrack(track.id) !== null) {
          return;
        }
        this.trackArtworkUnavailableIds.add(track.id);
        return;
      }
      let previous = this.trackArtworkMap.get(track.id);
      this.trackArtworkMap.set(track.id, pixelMap);
      this.trackArtworkOwnerMap.set(track.id, track.id);
      this.trackArtworkUnavailableIds.delete(track.id);
      this.refreshAlbumArtworkAliases();
      this.refreshTrackArtworkIds();
      await releaseExtractedTrackArtwork(previous);
    } finally {
      this.trackArtworkLoadingIds.delete(track.id);
    }
  }

  private async releaseCachedTrackArtwork(trackId: string): Promise<void> {
    let pixelMap = this.trackArtworkMap.get(trackId);
    this.trackArtworkMap.delete(trackId);
    Array.from(this.trackArtworkOwnerMap.entries()).forEach((entry: [string, string]) => {
      let ownerTrackId = entry[0];
      let mappedOwnerId = entry[1];
      if (ownerTrackId === trackId || mappedOwnerId === trackId) {
        this.trackArtworkOwnerMap.delete(ownerTrackId);
      }
    });
    this.trackArtworkLoadingIds.delete(trackId);
    this.trackArtworkUnavailableIds.delete(trackId);
    this.refreshAlbumArtworkAliases();
    this.refreshTrackArtworkIds();
    await releaseExtractedTrackArtwork(pixelMap);
  }

  private async persistUriPermissions(uris: Array<string>): Promise<void> {
    let persisted = await persistReadUriPermissions(uris);
    if (!persisted) {
      this.showToast('已导入歌曲，但系统未保存文件授权');
    }
  }

  private async activatePersistedUriPermissions(): Promise<void> {
    let trackUris = this.localTracks.filter((track: MusicTrack) => track.sourceUri.length > 0)
      .map((track: MusicTrack) => track.sourceUri);
    if (trackUris.length === 0) {
      return;
    }
    await activatePersistedReadUriPermissions(trackUris);
  }

  private schedulePersistState(): void {
    if (this.isRestoringState || !this.hasInitializedState) {
      return;
    }
    if (this.session) {
      void this.refreshAVSessionQueue();
    }
    void this.persistState();
  }

  private flushPersistStateNow(): void {
    if (this.isRestoringState || !this.hasInitializedState || this.appDatabase === null) {
      this.schedulePersistState();
      return;
    }
    try {
      savePersistedAppStateSync(this.appDatabase, {
        localTracks: this.localTracks,
        recentTrackIds: this.recentTrackIds,
        currentTrackId: this.currentTrackId,
        collectionMode: this.collectionMode,
        totalListeningMs: this.totalListeningMs,
        playMode: this.playMode,
        appThemeMode: this.appThemeMode,
        customPlaylists: this.customPlaylists,
        activePlaybackCollectionId: this.activePlaybackCollectionId,
        playbackDrawerShowAlbumCollections: this.playbackDrawerShowAlbumCollections,
        playbackDrawerShowArtistCollections: this.playbackDrawerShowArtistCollections,
        baiduPanAppKey: this.baiduPanAppKey,
        baiduPanAccessToken: this.baiduPanAccessToken,
        baiduPanCurrentDir: this.baiduPanCurrentDir,
        musicSources: this.musicSources
      }, this.musicSourceScripts);
      this.pendingPersistState = false;
    } catch (error) {
      console.error(`flush persist state failed: ${JSON.stringify(error)}`);
      this.schedulePersistState();
    }
  }

  private async persistState(): Promise<void> {
    if (this.isPersistingState) {
      this.pendingPersistState = true;
      return;
    }
    this.isPersistingState = true;
    try {
      do {
        this.pendingPersistState = false;
        let store = await this.ensureAppDatabaseStore();
        await savePersistedAppState(store, {
          localTracks: this.localTracks,
          recentTrackIds: this.recentTrackIds,
          currentTrackId: this.currentTrackId,
          collectionMode: this.collectionMode,
          totalListeningMs: this.totalListeningMs,
          playMode: this.playMode,
          appThemeMode: this.appThemeMode,
          customPlaylists: this.customPlaylists,
          activePlaybackCollectionId: this.activePlaybackCollectionId,
          playbackDrawerShowAlbumCollections: this.playbackDrawerShowAlbumCollections,
          playbackDrawerShowArtistCollections: this.playbackDrawerShowArtistCollections,
          baiduPanAppKey: this.baiduPanAppKey,
          baiduPanAccessToken: this.baiduPanAccessToken,
          baiduPanCurrentDir: this.baiduPanCurrentDir,
          musicSources: this.musicSources
        }, this.musicSourceScripts);
      } while (this.pendingPersistState);
    } catch (error) {
      console.error(`persist state failed: ${JSON.stringify(error)}`);
    } finally {
      this.isPersistingState = false;
    }
  }

  private baiduPanEntryImportKey(entry: BaiduPanEntry): string {
    return `baidupan:${entry.fsId}`;
  }

  private baiduPanImportedKeySnapshot(): string {
    return this.localTracks
      .map((track: MusicTrack) => track.sourceImportKey ?? '')
      .filter((value: string) => value.startsWith('baidupan:'))
      .join('|');
  }

  private openBaiduPanImportPanel(): void {
    this.showBaiduPanImportPanel = true;
    if (this.baiduPanAccessToken.trim().length > 0 && !this.baiduPanLoading) {
      void this.loadBaiduPanDirectory(this.baiduPanCurrentDir);
    }
  }

  private closeBaiduPanImportPanel(): void {
    this.showBaiduPanImportPanel = false;
    this.schedulePersistState();
  }

  private openBaiduPanAuthPanel(): void {
    this.showBaiduPanAuthPanel = true;
    if (this.baiduPanAppKey.trim().length > 0 && this.baiduPanAuthUrl.trim().length === 0) {
      this.startBaiduPanAuth();
    }
  }

  private closeBaiduPanAuthPanel(): void {
    this.showBaiduPanAuthPanel = false;
    this.baiduPanAuthUrl = '';
    this.baiduPanLastAuthMessage = '';
    this.schedulePersistState();
  }

  private startBaiduPanAuth(): void {
    let appKey = this.baiduPanAppKey.trim();
    if (appKey.length === 0) {
      this.showToast('请先输入百度开放平台 AppKey');
      return;
    }
    this.baiduPanAuthUrl = buildBaiduPanOAuthAuthorizeUrl(appKey, `${Date.now()}`);
    this.baiduPanLastAuthMessage = '';
    this.schedulePersistState();
  }

  private handleBaiduPanAuthPayload(payload: string): void {
    let result = parseBaiduPanOAuthPayload(payload);
    if (result.accessToken.length > 0) {
      let accessTokenChanged = result.accessToken !== this.baiduPanAccessToken.trim();
      this.baiduPanAccessToken = result.accessToken;
      this.baiduPanEntries = [];
      this.baiduPanCurrentDir = '/';
      this.baiduPanAuthUrl = '';
      this.showBaiduPanAuthPanel = false;
      this.baiduPanLastAuthMessage = '';
      this.schedulePersistState();
      this.showToast(accessTokenChanged ? '百度网盘授权成功' : '百度网盘授权已恢复');
      void this.loadBaiduPanDirectory('/');
      return;
    }
    if (result.errorMessage.length === 0 || result.errorMessage === this.baiduPanLastAuthMessage) {
      return;
    }
    this.baiduPanLastAuthMessage = result.errorMessage;
    this.showToast(`百度授权失败: ${result.errorMessage}`);
  }

  private async loadBaiduPanDirectory(targetDir: string): Promise<void> {
    let accessToken = this.baiduPanAccessToken.trim();
    if (accessToken.length === 0) {
      this.showToast('请先完成百度网盘授权');
      return;
    }
    this.baiduPanLoading = true;
    try {
      let normalizedDir = normalizeBaiduPanPath(targetDir);
      let entries = await fetchBaiduPanDirectory(accessToken, normalizedDir);
      this.baiduPanCurrentDir = normalizedDir;
      this.baiduPanEntries = entries;
      this.schedulePersistState();
    } catch (error) {
      let message = error instanceof Error ? error.message : String(error);
      console.error(`load baidu pan directory failed: ${message}`);
      this.showToast(message.length > 0 ? message : '读取百度网盘目录失败');
    } finally {
      this.baiduPanLoading = false;
    }
  }

  private async enterBaiduPanDirectory(entry: BaiduPanEntry): Promise<void> {
    if (!entry.isDirectory) {
      return;
    }
    await this.loadBaiduPanDirectory(entry.path);
  }

  private async goParentBaiduPanDirectory(): Promise<void> {
    await this.loadBaiduPanDirectory(parentBaiduPanPath(this.baiduPanCurrentDir));
  }

  private async importBaiduPanEntry(entry: BaiduPanEntry): Promise<void> {
    if (entry.isDirectory) {
      await this.enterBaiduPanDirectory(entry);
      return;
    }
    let importKey = this.baiduPanEntryImportKey(entry);
    if (this.baiduPanImportingKeys.indexOf(importKey) >= 0) {
      return;
    }
    let alreadyImported = this.localTracks.some((track: MusicTrack) => track.sourceImportKey === importKey);
    if (alreadyImported) {
      this.showToast(`「${entry.name}」已导入`);
      return;
    }

    let accessToken = this.baiduPanAccessToken.trim();
    if (accessToken.length === 0) {
      this.showToast('请先完成百度网盘授权');
      return;
    }

    this.baiduPanImportingKeys = this.baiduPanImportingKeys.concat([importKey]);
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let downloadDirectory = `${context.filesDir}/downloads`;
      try {
        if (!fs.accessSync(downloadDirectory)) {
          fs.mkdirSync(downloadDirectory, true);
        }
      } catch (_) {
        // directory may already exist
      }

      let targetFileName = `${Date.now()}-${sanitizeFileName(entry.name)}`;
      let targetPath = `${downloadDirectory}/${targetFileName}`;
      let audioBuffer = await downloadBaiduPanAudio(accessToken, entry.path);

      if (fs.accessSync(targetPath)) {
        fs.unlinkSync(targetPath);
      }
      let outputFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try {
        fs.writeSync(outputFile.fd, audioBuffer);
      } finally {
        fs.closeSync(outputFile);
      }

      let importedTrack = buildDownloadedTrack(targetPath, `https://pan.baidu.com${entry.path}`, this.localTracks.length);
      let folderLabel = baiduPanParentLabel(entry.path);
      importedTrack.folder = folderLabel;
      importedTrack.album = folderLabel;
      importedTrack.sourceImportKey = importKey;

      let hasImportedTrack = this.localTracks.some((track: MusicTrack) => track.sourceImportKey === importKey);
      if (!hasImportedTrack) {
        this.localTracks = this.localTracks.concat([importedTrack]);
        this.syncTrackMetadataCaches();
      }
      this.schedulePersistState();
      this.showToast(`已从百度网盘导入「${entry.name}」`);
    } catch (error) {
      let message = error instanceof Error ? error.message : String(error);
      console.error(`import baidu pan entry failed: ${message}`);
      this.showToast(message.length > 0 ? message : '百度网盘导入失败');
    } finally {
      this.baiduPanImportingKeys = this.baiduPanImportingKeys.filter((key: string) => key !== importKey);
    }
  }

  private async importLocalMusic(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 50;
      options.fileSuffixFilters = AUDIO_FILTERS;
      let documentPicker = new picker.DocumentViewPicker(context);
      let uris = await documentPicker.select(options);
      if (!uris || uris.length === 0) {
        return;
      }

      let mergedTracks = this.localTracks.slice();
      let importedCount = 0;
      let newUris: Array<string> = [];
      uris.forEach((uri: string) => {
        let duplicated = mergedTracks.some((track: MusicTrack) => track.sourceUri === uri);
        if (!duplicated) {
          mergedTracks.push(buildImportedTrack(uri, mergedTracks.length));
          importedCount += 1;
          newUris.push(uri);
        }
      });

      this.localTracks = mergedTracks;
      this.syncTrackMetadataCaches();
      this.collectionMode = CollectionMode.Library;
      this.activeLibraryDimension = LibraryDimension.Song;
      this.activeMainTab = MainTab.Home;
      this.syncCurrentTrackSelection();
      await this.persistUriPermissions(newUris);
      this.schedulePersistState();
      if (importedCount > 0) {
        this.showToast(`已导入 ${importedCount} 首本地音乐`);
      } else {
        this.showToast('这些歌曲已经在列表里了');
      }
    } catch (error) {
      console.error(`import local music failed: ${JSON.stringify(error)}`);
      this.showToast('导入失败，请重新选择文件');
    }
  }

  private resetQuickJsEngine(): void {
    if (this.quickJsEngine !== null) {
      this.quickJsEngine.dispose();
      this.quickJsEngine = null;
    }
    this.jsEngineReady = false;
    this.jsEngineLastError = '';
    this.jsEngineSourceId = '';
    this.jsEngineKey = '';
  }

  private getQuickJsEngine(): QuickJsEngineAdapter {
    if (this.quickJsEngine === null) {
      this.quickJsEngine = new QuickJsEngineAdapter(
        createQuickJsHttpRequestTask,
        async (event: QuickJsHostEvent): Promise<void> => {
          await this.handleQuickJsHostEvent(event.action, event.payloadJson);
        }
      );
    }
    return this.quickJsEngine;
  }

  private async handleQuickJsHostEvent(action: string, payloadJson: string): Promise<void> {
    if (action === 'showUpdateAlert') {
      this.handleSourceUpdateAlert(payloadJson);
      return;
    }
    if (action === 'log') {
      this.handleSourceConsoleLog(payloadJson);
      return;
    }
    console.warn(`Unhandled QuickJS host event: ${action}`);
  }

  private handleJsEngineInit(data: Record<string, Object>): void {
    let initOutcome = handleJsEngineInitPayload(this.musicSources, this.jsEngineSourceId, data);
    if (initOutcome.ready && initOutcome.didUpdateSources) {
      this.musicSources = initOutcome.musicSources;
      this.schedulePersistState();
    }
    if (!initOutcome.ready) {
      console.error(`JS engine init failed: ${initOutcome.errorMessage}`);
    }
    this.jsEngineReady = initOutcome.ready;
    this.jsEngineLastError = initOutcome.errorMessage;
  }

  private async loadSourceIntoJsEngine(source: MusicSourceConfig): Promise<boolean> {
    if (this.jsEngineSourceId === source.id && this.jsEngineReady) {
      return true;
    }

    this.jsEngineReady = false;
    this.jsEngineLastError = '';
    this.jsEngineSourceId = '';
    this.jsEngineKey = `key_${Date.now()}_${Math.floor(Math.random() * 100000)}`;

    try {
      let script = await this.getMusicSourceScript(source.id);
      if (script.length === 0) {
        throw new Error('source script not found');
      }
      let setupScript = buildQuickJsSourceSetupScript(this.jsEngineKey, source, script, USER_API_PRELOAD_SCRIPT);
      let initPayloadJson = await this.getQuickJsEngine().loadSource(this.jsEngineKey, setupScript);
      this.jsEngineSourceId = source.id;
      this.handleJsEngineInit(JSON.parse(initPayloadJson) as Record<string, Object>);

      if (!this.jsEngineReady) {
        let errMsg = this.jsEngineLastError.length > 0 ? this.jsEngineLastError : 'source init returned not ready';
        this.resetQuickJsEngine();
        this.jsEngineLastError = errMsg;
        return false;
      }
      return true;
    } catch (error) {
      let errMsg = error instanceof Error ? error.message : String(error);
      console.error(`loadSourceIntoJsEngine failed: ${errMsg}`);
      this.resetQuickJsEngine();
      this.jsEngineLastError = errMsg;
      return false;
    }
  }

  private async requestMusicUrlFromEngine(source: MusicSourceConfig, track: MusicSourceTrack, quality: string): Promise<string> {
    let loaded = await this.loadSourceIntoJsEngine(source);
    if (!loaded) {
      throw new Error(this.jsEngineLastError || 'JS engine not ready');
    }

    let requestKey = `musicUrl_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    let responsePayloadJson = await this.getQuickJsEngine().dispatch(
      this.jsEngineKey,
      'request',
      buildQuickJsMusicUrlRequest(requestKey, track, quality)
    );
    return parseQuickJsMusicUrlResponse(responsePayloadJson);
  }

  private processAndAddSource(scriptContent: string): MusicSourceConfig | null {
    try {
      let result = createPendingMusicSource(scriptContent, this.musicSources);
      if (!result.source) {
        this.showToast(result.errorMessage);
        return null;
      }
      this.musicSourceScripts.set(result.source.id, scriptContent);
      this.musicSources = this.musicSources.concat([result.source]);
      this.showAddSourceDialog = false;
      this.schedulePersistState();
      return result.source;
    } catch (error) {
      let errMsg = error instanceof Error ? error.message : '导入失败，请选择有效的 lx-music 音源脚本';
      this.showToast(errMsg);
      return null;
    }
  }

  private async validateAndActivateSource(source: MusicSourceConfig): Promise<boolean> {
    let loaded = await this.loadSourceIntoJsEngine(source);
    if (!loaded) {
      this.removeMusicSource(source.id, false);
      this.showToast(`音源「${source.name}」加载失败：${this.jsEngineLastError}`);
      return false;
    }
    if (this.activeMainTab === MainTab.Explore || this.musicSources.length === 1) {
      this.ensureExploreSourceReady(this.activeMainTab === MainTab.Explore);
    }
    this.schedulePersistState();
    this.showToast(`已添加音源「${source.name}」`);
    return true;
  }

  private async importAndValidateSourceScript(scriptContent: string): Promise<boolean> {
    let source = this.processAndAddSource(scriptContent);
    if (!source) {
      return false;
    }
    return await this.validateAndActivateSource(source);
  }

  private async importMusicSourceScriptFromUrl(url: string): Promise<string> {
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (response.responseCode !== 200) {
        throw new Error(`下载失败，HTTP 状态码: ${response.responseCode}`);
      }
      let scriptContent = response.result as string;
      if (!scriptContent || scriptContent.length === 0) {
        throw new Error('下载的脚本内容为空');
      }
      return scriptContent;
    } finally {
      httpRequest.destroy();
    }
  }

  private async readMusicSourceScriptFromFile(uri: string): Promise<string> {
    let fileUriObj = new fileUri.FileUri(uri);
    let file = fs.openSync(fileUriObj.path, fs.OpenMode.READ_ONLY);
    try {
      let buf = new ArrayBuffer(128 * 1024);
      let readLen = fs.readSync(file.fd, buf);
      let decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buf, 0, readLen));
    } finally {
      fs.closeSync(file);
    }
  }

  private async addMusicSourceFromFile(): Promise<void> {
    this.addSourceLoading = true;
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['脚本|.js'];
      let documentPicker = new picker.DocumentViewPicker(context);
      let uris = await documentPicker.select(options);
      if (!uris || uris.length === 0) {
        this.addSourceLoading = false;
        return;
      }
      let scriptContent = await this.readMusicSourceScriptFromFile(uris[0]);
      await this.importAndValidateSourceScript(scriptContent);
    } catch (error) {
      console.error(`add music source from file failed: ${JSON.stringify(error)}`);
      this.showToast('导入失败，请选择有效的 lx-music 音源脚本');
    } finally {
      this.addSourceLoading = false;
    }
  }

  private async addMusicSourceFromUrl(): Promise<void> {
    let url = this.sourceUrlInput.trim();
    if (url.length === 0) {
      this.showToast('请输入音源脚本 URL');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      this.showToast('请输入有效的 http/https URL');
      return;
    }
    this.addSourceLoading = true;
    try {
      let scriptContent = await this.importMusicSourceScriptFromUrl(url);
      if (await this.importAndValidateSourceScript(scriptContent)) {
        this.sourceUrlInput = '';
      }
    } catch (error) {
      console.error(`add music source from url failed: ${JSON.stringify(error)}`);
      let errMsg = error instanceof Error ? error.message : '从 URL 导入失败，请检查网络和地址是否正确';
      this.showToast(errMsg);
    } finally {
      this.addSourceLoading = false;
    }
  }

  private toggleMusicSourceAllowShowUpdateAlert(sourceId: string): void {
    let updateResult = toggleSourceUpdateAlert(this.musicSources, sourceId);
    this.musicSources = updateResult.sources;
    if (updateResult.updated) {
      this.schedulePersistState();
    }
  }

  private updateMusicSourcePreferredQuality(sourceId: string, sourceCode: string, quality: string): void {
    let updateResult = updateSourcePreferredQuality(this.musicSources, sourceId, sourceCode, quality);
    if (!updateResult.updated) {
      return;
    }
    this.musicSources = updateResult.sources;
    this.schedulePersistState();
    this.showToast(`${sourceDisplayName(sourceCode)} 默认音质已切换为 ${sourceQualityDisplayName(quality)}`);
  }

  private removeMusicSource(sourceId: string, showToast: boolean = true): void {
    let removeResult = removeSourceById(this.musicSources, sourceId);
    if (!removeResult.updated) {
      return;
    }
    this.musicSources = removeResult.sources;
    if (this.activeSourceId === sourceId) {
      this.activeSourceId = '';
      this.closeSourceBrowser();
    }
    if (this.musicSources.length === 0) {
      this.activeSearchSource = '';
      this.clearExploreResults();
    } else if (this.activeMainTab === MainTab.Explore) {
      this.ensureExploreSourceReady(true);
    }
    if (this.jsEngineSourceId === sourceId) {
      this.resetQuickJsEngine();
    }
    void this.deleteMusicSourceScript(sourceId).catch((error: Object) => {
      console.error(`delete music source script failed: ${JSON.stringify(error)}`);
    });
    this.schedulePersistState();
    if (showToast) {
      this.showToast('已删除音源');
    }
  }

  private async fetchBoardList(source: MusicSourceConfig, subSource: string): Promise<void> {
    this.sourceBoardsLoading = true;
    this.sourceBoardList = [];
    this.activeBoardId = '';
    this.sourceTracks = [];
    this.sourceTotal = 0;
    if (!isSupportedExploreSource(subSource)) {
      this.sourceBoardsLoading = false;
      return;
    }
    let boards = BUILTIN_BOARD_LIST[subSource];
    if (!boards || boards.length === 0) {
      this.sourceBoardsLoading = false;
      return;
    }
    // Filter to only boards relevant to sources the user's config declares
    let hasSource = source.musicSources.some((s: MusicSourceQuality) => s.source === subSource);
    if (!hasSource) {
      this.sourceBoardsLoading = false;
      return;
    }
    this.sourceBoardList = boards;
    this.sourceBoardsLoading = false;
    if (boards.length > 0) {
      this.activeBoardId = boards[0].bangid;
      void this.fetchBoardTracks(source, subSource, boards[0].bangid, 1);
    }
  }

  private async fetchBoardTracks(_source: MusicSourceConfig, subSource: string, bangid: string, page: number): Promise<void> {
    if (!isSupportedExploreSource(subSource)) {
      this.showToast(`暂不支持浏览 ${sourceDisplayName(subSource)} 榜单`);
      return;
    }
    this.sourceTracksLoading = true;
    try {
      let result = await fetchBoardTrackPage(subSource, bangid, page);
      this.sourceTotal = result.total;
      if (page === 1) {
        this.sourceTracks = result.tracks;
      } else {
        this.sourceTracks = this.sourceTracks.concat(result.tracks);
      }
      this.sourceCurrentPage = result.page;
    } catch (error) {
      let errMessage = error instanceof Error ? error.message : String(error);
      console.error(`fetch board tracks failed: source=${subSource}, bangid=${bangid}, page=${page}, error=${errMessage}`);
      if (page === 1) {
        this.sourceTracks = [];
      }
      this.showToast(`获取榜单歌曲失败: ${errMessage}`);
    } finally {
      this.sourceTracksLoading = false;
    }
  }

  private async searchSourceTracks(_source: MusicSourceConfig, keyword: string, searchSource: string, page: number): Promise<void> {
    if (keyword.trim().length === 0) {
      this.showToast('请输入搜索关键词');
      return;
    }
    if (!isSupportedExploreSource(searchSource)) {
      this.showToast(`暂不支持搜索 ${sourceDisplayName(searchSource)}`);
      return;
    }
    this.sourceTracksLoading = true;
    try {
      let result = await searchSourceTrackPage(keyword, searchSource, page);
      this.sourceTotal = result.total;
      if (page === 1) {
        this.sourceTracks = result.tracks;
      } else {
        this.sourceTracks = this.sourceTracks.concat(result.tracks);
      }
      this.sourceCurrentPage = result.page;
    } catch (error) {
      let errMessage = error instanceof Error ? error.message : String(error);
      console.error(`search source tracks failed: source=${searchSource}, keyword=${keyword}, page=${page}, error=${errMessage}`);
      this.showToast(`搜索失败: ${errMessage}`);
    } finally {
      this.sourceTracksLoading = false;
    }
  }

  private sourceTrackImportKey(track: MusicSourceTrack): string {
    return buildSourceTrackImportKey(track);
  }

  private isSourceTrackQueued(track: MusicSourceTrack): boolean {
    return this.sourceImportingTrackKeys.indexOf(this.sourceTrackImportKey(track)) >= 0;
  }

  private findImportedSourceTrack(track: MusicSourceTrack): MusicTrack | undefined {
    let importKey = this.sourceTrackImportKey(track);
    return this.localTracks.find((item: MusicTrack) => {
      if ((item.sourceImportKey ?? '') === importKey) {
        return true;
      }
      return item.folder === 'downloads' && item.title === track.name && item.artist === track.singer && item.album === track.album;
    });
  }

  private sourceTrackActionLabel(track: MusicSourceTrack): string {
    if (this.findImportedSourceTrack(track)) {
      return '已导入';
    }
    if (this.isSourceTrackQueued(track)) {
      return '导入中';
    }
    return '导入';
  }

  private sourceTrackActionEnabled(track: MusicSourceTrack): boolean {
    return this.sourceTrackActionLabel(track) === '导入';
  }

  private enqueueSourceTrackImport(source: MusicSourceConfig, track: MusicSourceTrack): void {
    if (this.findImportedSourceTrack(track)) {
      this.showToast(`「${track.name}」已导入`);
      return;
    }
    let importKey = this.sourceTrackImportKey(track);
    if (this.sourceImportingTrackKeys.indexOf(importKey) >= 0) {
      return;
    }
    this.sourceImportQueue.push(new SourceImportTask(importKey, source, track));
    this.sourceImportingTrackKeys = this.sourceImportingTrackKeys.concat([importKey]);
    this.showToast(`已加入导入队列: 「${track.name}」`);
    void this.processSourceImportQueue();
  }

  private async processSourceImportQueue(): Promise<void> {
    if (this.isProcessingSourceImportQueue) {
      return;
    }
    this.isProcessingSourceImportQueue = true;
    try {
      while (this.sourceImportQueue.length > 0) {
        let task = this.sourceImportQueue.shift();
        if (!task) {
          continue;
        }
        await this.importSourceTrack(task.source, task.track, task.key);
      }
    } finally {
      this.isProcessingSourceImportQueue = false;
    }
  }

  private async fetchSourceTrackPic(track: MusicSourceTrack): Promise<string> {
    if (track.pic.length > 0) {
      return track.pic;
    }
    let picHttp = http.createHttp();
    try {
      if (track.source === 'kw' && track.songmid.length > 0) {
        let picResponse = await picHttp.request(
          `http://artistpicserver.kuwo.cn/pic.web?corp=kuwo&type=rid_pic&pictype=500&size=500&rid=${track.songmid}`,
          {
            method: http.RequestMethod.GET,
            expectDataType: http.HttpDataType.STRING,
            readTimeout: 8000,
            connectTimeout: 5000
          }
        );
        if (picResponse.responseCode === 200) {
          let picUrl = (picResponse.result as string).trim();
          if (picUrl.startsWith('http')) {
            return picUrl;
          }
        }
      }
      if (track.source === 'kg' && track.hash.length > 0) {
        let escapeName = `${track.singer} - ${track.name}.mp3`.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
        let escapeSongmid = track.songmid.replace(/"/g, '\\"');
        let escapeAlbumId = track.albumId.replace(/"/g, '\\"');
        let escapeHash = track.hash.replace(/"/g, '\\"');
        let kgBodyStr = `{"appid":1001,"area_code":"1","behavior":"play","clientver":"9020","need_hash_offset":1,"relate":1,"resource":[{"album_audio_id":"${escapeSongmid}","album_id":"${escapeAlbumId}","hash":"${escapeHash}","id":0,"name":"${escapeName}","type":"audio"}],"token":"","userid":2626431536,"vip":1}`;
        let kgResponse = await picHttp.request(
          'http://media.store.kugou.com/v1/get_res_privilege',
          {
            method: http.RequestMethod.POST,
            expectDataType: http.HttpDataType.STRING,
            readTimeout: 8000,
            connectTimeout: 5000,
            header: {
              'KG-RC': '1',
              'KG-THash': 'expand_search_manager.cpp:852736169:451',
              'User-Agent': 'KuGou2012-9020-ExpandSearchManager',
              'Content-Type': 'application/json'
            } as Record<string, string>,
            extraData: kgBodyStr
          }
        );
        if (kgResponse.responseCode === 200) {
          let kgResult = JSON.parse(kgResponse.result as string) as Record<string, Object>;
          let errorCode = kgResult['error_code'] as number;
          if (errorCode === 0) {
            let dataArr = kgResult['data'] as Record<string, Object>[];
            if (dataArr && dataArr.length > 0) {
              let info = dataArr[0]['info'] as Record<string, Object>;
              if (info) {
                let imgUrl = info['image'] as string || '';
                let imgSizes = info['imgsize'] as number[];
                if (imgUrl.length > 0 && imgSizes && imgSizes.length > 0) {
                  imgUrl = imgUrl.replace('{size}', `${imgSizes[0]}`);
                }
                if (imgUrl.length > 0 && imgUrl.startsWith('http')) {
                  return imgUrl;
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // pic fetch is best-effort, don't block import
    } finally {
      picHttp.destroy();
    }
    return '';
  }

  private async importSourceTrack(source: MusicSourceConfig, track: MusicSourceTrack, importKey: string): Promise<void> {
    try {
      let existingTrack = this.findImportedSourceTrack(track);
      if (existingTrack) {
        if ((existingTrack.sourceImportKey ?? '').length === 0) {
          let existingTrackId = existingTrack.id;
          let localIndex = this.localTracks.findIndex((item: MusicTrack) => item.id === existingTrackId);
          if (localIndex >= 0) {
            let updatedTracks = this.localTracks.slice();
            let updatedTrack = copyTrack(updatedTracks[localIndex]);
            updatedTrack.sourceImportKey = importKey;
            updatedTracks[localIndex] = updatedTrack;
            this.localTracks = updatedTracks;
            this.schedulePersistState();
          }
        }
        return;
      }

      let quality = resolveSourceTrackQuality(source, track);
      let musicUrl = await this.requestMusicUrlFromEngine(source, track, quality);
      if (!musicUrl || musicUrl.length === 0) {
        throw new Error('empty music url from JS engine');
      }

      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let downloadDir = `${context.filesDir}/downloads`;
      try {
        if (!fs.accessSync(downloadDir)) {
          fs.mkdirSync(downloadDir, true);
        }
      } catch (_) {
        // directory may already exist
      }
      let safeFileName = `${Date.now()}-${track.name.replace(/[\/\\:*?"<>|]/g, '_')}.mp3`;
      let targetPath = `${downloadDir}/${safeFileName}`;

      let downloadHttp = http.createHttp();
      try {
        let downloadResponse = await downloadHttp.request(musicUrl, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          readTimeout: 60000,
          connectTimeout: 15000,
          usingCache: false,
          maxLimit: ONLINE_DOWNLOAD_MAX_BYTES,
          header: { 'User-Agent': 'Mozilla/5.0 (HarmonyOS Music Player)' } as Record<string, string>
        });
        if (downloadResponse.responseCode < 200 || downloadResponse.responseCode >= 300) {
          throw new Error(`download failed: http ${downloadResponse.responseCode}`);
        }
        let audioBuffer = downloadResponse.result as ArrayBuffer;
        if (!(audioBuffer instanceof ArrayBuffer) || audioBuffer.byteLength === 0) {
          throw new Error('empty audio buffer');
        }
        let outputFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
        try {
          fs.writeSync(outputFile.fd, audioBuffer);
        } finally {
          fs.closeSync(outputFile);
        }
      } finally {
        downloadHttp.destroy();
      }

      let trackPic = await this.fetchSourceTrackPic(track);

      let importedTrack: MusicTrack = {
        id: `source-${Date.now()}`,
        title: track.name,
        artist: track.singer,
        album: track.album,
        durationMs: track.duration > 0 ? track.duration * 1000 : 0,
        folder: 'downloads',
        sourceUri: '',
        filePath: targetPath,
        rawFileName: '',
        accentColor: COLOR_PALETTE[this.localTracks.length % COLOR_PALETTE.length],
        pic: trackPic,
        isFavorite: false,
        isImported: true,
        inPlayQueue: true,
        playCount: 0,
        lastPlayedAt: 0,
        sourceImportKey: importKey
      };

      let alreadyExists = this.findImportedSourceTrack(track);
      if (!alreadyExists) {
        this.localTracks = this.localTracks.concat([importedTrack]);
        this.syncTrackMetadataCaches();
      }
      this.schedulePersistState();
      this.showToast(`已导入「${track.name}」`);
    } catch (error) {
      let errMessage = (error instanceof Error) ? error.message : String(error);
      console.error(`import source track failed: ${errMessage}`);
      this.showToast(`导入失败: ${errMessage}`);
    } finally {
      this.sourceImportingTrackKeys = this.sourceImportingTrackKeys.filter((key: string) => key !== importKey);
    }
  }

  private getActiveSource(): MusicSourceConfig | undefined {
    return this.musicSources.find((s: MusicSourceConfig) => s.id === this.activeSourceId);
  }

  private getExploreActiveSource(): MusicSourceConfig | undefined {
    return this.ensureExploreSourceReady(this.exploreMode === 'board' && this.sourceBoardList.length === 0 && !this.sourceBoardsLoading);
  }

  private async handleTrackTap(track: MusicTrack): Promise<void> {
    let isLoadedTrack = this.loadedTrackId === track.id;
    this.currentTrackId = track.id;
    this.pushRecentTrack(track.id);
    if (!track.isImported) {
      this.isPlaying = false;
      this.setMiniPlayButtonState(false, false);
      this.playbackProgressMs = 0;
      this.playbackDurationMs = 0;
      this.showToast('当前歌曲暂不可播放，请先导入本地音乐');
      return;
    }

    if (this.player && isLoadedTrack && this.isPlaying) {
      await this.pauseCurrentTrack();
      return;
    }

    if (this.player && isLoadedTrack && !this.isPlaying && this.player.state === 'paused') {
      await this.resumeCurrentTrack();
      return;
    }

    await this.startTrackPlayback(track);
  }

  private async handleMiniPlayPause(): Promise<void> {
    let track = this.currentTrack();
    let queueTracks = this.playQueueTracks();
    let isLoadedTrack = this.loadedTrackId === track.id;
    if ((!track.isImported || track.inPlayQueue === false) && !isLoadedTrack) {
      if (queueTracks.length === 0) {
        this.showToast('播放列表为空，请先在“我的”页把歌曲加入播放列表');
        return;
      }
      await this.startTrackPlayback(queueTracks[0]);
      return;
    }

    if (this.isPlaying && isLoadedTrack) {
      await this.pauseCurrentTrack();
    } else if (this.player && isLoadedTrack && this.player.state === 'paused') {
      await this.resumeCurrentTrack();
    } else {
      await this.startTrackPlayback(track);
    }
  }

  private async shufflePlayAll(): Promise<void> {
    let queueTracks = this.playQueueTracks();
    if (queueTracks.length === 0) {
      this.showToast('播放列表为空，请先在“我的”页把歌曲加入播放列表');
      return;
    }
    let randomIndex = Math.floor(Math.random() * queueTracks.length);
    await this.startTrackPlayback(queueTracks[randomIndex]);
  }

  private async playNextTrack(): Promise<void> {
    let queueTracks = this.playQueueTracks();
    if (queueTracks.length === 0) {
      this.showToast('当前播放列表为空');
      return;
    }
    let index = queueTracks.findIndex((track: MusicTrack) => track.id === this.currentTrackId);
    if (this.playMode === PlayMode.Shuffle) {
      let randomIndex = Math.floor(Math.random() * queueTracks.length);
      if (queueTracks.length > 1 && randomIndex === index) {
        randomIndex = (randomIndex + 1) % queueTracks.length;
      }
      await this.startTrackPlayback(queueTracks[randomIndex]);
    } else if (this.playMode === PlayMode.Loop) {
      let currentIndex = index >= 0 ? index : 0;
      await this.startTrackPlayback(queueTracks[currentIndex]);
    } else {
      let nextIndex = index >= 0 ? (index + 1) % queueTracks.length : 0;
      await this.startTrackPlayback(queueTracks[nextIndex]);
    }
  }

  private async playPreviousTrack(): Promise<void> {
    let queueTracks = this.playQueueTracks();
    if (queueTracks.length === 0) {
      this.showToast('当前播放列表为空');
      return;
    }
    let index = queueTracks.findIndex((track: MusicTrack) => track.id === this.currentTrackId);
    if (this.playMode === PlayMode.Shuffle) {
      let randomIndex = Math.floor(Math.random() * queueTracks.length);
      if (queueTracks.length > 1 && randomIndex === index) {
        randomIndex = (randomIndex + queueTracks.length - 1) % queueTracks.length;
      }
      await this.startTrackPlayback(queueTracks[randomIndex]);
    } else if (this.playMode === PlayMode.Loop) {
      let currentIndex = index >= 0 ? index : 0;
      await this.startTrackPlayback(queueTracks[currentIndex]);
    } else {
      let previousIndex = index >= 0 ? (index + queueTracks.length - 1) % queueTracks.length : 0;
      await this.startTrackPlayback(queueTracks[previousIndex]);
    }
  }

  private toggleTrackInPlayQueue(trackId: string): void {
    let trackIndex = this.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (trackIndex < 0) {
      return;
    }
    let updatedTracks = this.localTracks.slice();
    let selectedTrack = copyTrack(updatedTracks[trackIndex]);
    selectedTrack.inPlayQueue = !selectedTrack.inPlayQueue;
    updatedTracks[trackIndex] = selectedTrack;
    this.localTracks = updatedTracks;

    if (selectedTrack.inPlayQueue) {
      this.syncCurrentTrackSelection(selectedTrack.id);
    } else {
      this.syncCurrentTrackSelection();
    }
    this.ensureActivePlaybackCollectionValid();

    this.schedulePersistState();
    this.showToast(selectedTrack.inPlayQueue ?
      `已将「${selectedTrack.title}」加入播放列表` :
      `已将「${selectedTrack.title}」移出播放列表`);
  }

  private moveImportedTrackBefore(trackId: string, referenceTrackId: string): void {
    let nextTracks = moveTrackByReference(this.localTracks, trackId, referenceTrackId, false);
    if (nextTracks === this.localTracks) {
      return;
    }
    this.localTracks = nextTracks;
    this.schedulePersistState();
  }

  private moveImportedTrackAfter(trackId: string, referenceTrackId: string): void {
    let nextTracks = moveTrackByReference(this.localTracks, trackId, referenceTrackId, true);
    if (nextTracks === this.localTracks) {
      return;
    }
    this.localTracks = nextTracks;
    this.schedulePersistState();
  }

  private deleteManagedTrackFile(track: MusicTrack): void {
    if (track.sourceUri.length > 0 || track.filePath.length === 0) {
      return;
    }
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (!track.filePath.startsWith(context.filesDir)) {
        return;
      }
      if (fs.accessSync(track.filePath)) {
        fs.unlinkSync(track.filePath);
      }
    } catch (error) {
      console.error(`delete managed track file failed: ${JSON.stringify(error)}`);
    }
  }

  private async removeImportedTrack(trackId: string): Promise<void> {
    await this.removeImportedTracks([trackId]);
  }

  private async removeImportedTracks(trackIds: string[]): Promise<void> {
    let targetIds = trackIds.filter((trackId: string, index: number) =>
      trackId.length > 0 && trackIds.indexOf(trackId) === index
    );
    if (targetIds.length === 0) {
      return;
    }

    let removedTracks = this.localTracks.filter((item: MusicTrack) => targetIds.indexOf(item.id) >= 0);
    if (removedTracks.length === 0) {
      return;
    }

    let shouldReleaseCurrent = removedTracks.some((track: MusicTrack) => track.id === this.loadedTrackId);
    if (shouldReleaseCurrent) {
      await this.releasePlayer();
      this.playbackProgressMs = 0;
      this.playbackDurationMs = 0;
    }

    this.localTracks = this.localTracks.filter((item: MusicTrack) => targetIds.indexOf(item.id) < 0);
    this.customPlaylists = removeTracksFromCustomPlaylists(this.customPlaylists, targetIds);
    this.syncTrackMetadataCaches();
    this.recentTrackIds = this.recentTrackIds.filter((itemId: string) => targetIds.indexOf(itemId) < 0);
    if (targetIds.indexOf(this.renameTrackId) >= 0) {
      this.showRenameDialog = false;
      this.renameTrackId = '';
      this.renameText = '';
    }
    if (targetIds.indexOf(this.menuTrackId) >= 0) {
      this.showTrackMenu = false;
      this.menuTrackId = '';
    }
    if (targetIds.indexOf(this.currentTrackId) >= 0) {
      this.currentTrackId = MINI_PLACEHOLDER_TRACK.id;
    }

    removedTracks.forEach((track: MusicTrack) => {
      this.deleteManagedTrackFile(track);
    });

    this.ensureActivePlaybackCollectionValid();
    this.syncCurrentTrackSelection();
    this.schedulePersistState();

    if (removedTracks.length === 1) {
      this.showToast(`已移除「${removedTracks[0].title}」`);
    } else {
      this.showToast(`已批量移除 ${removedTracks.length} 首歌曲`);
    }
  }

  private toggleFavorite(trackId: string): void {
    let localIndex = this.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (localIndex >= 0) {
      let updatedTracks = this.localTracks.slice();
      let selectedTrack = copyTrack(updatedTracks[localIndex]);
      selectedTrack.isFavorite = !selectedTrack.isFavorite;
      updatedTracks[localIndex] = selectedTrack;
      this.localTracks = updatedTracks;
      this.ensureActivePlaybackCollectionValid();
      this.syncCurrentTrackSelection();
      this.schedulePersistState();
      this.showToast(updatedTracks[localIndex].isFavorite ? '已加入收藏' : '已取消收藏');
    }
  }

  private trackDurationText(track: MusicTrack): string {
    if (track.id === this.currentTrackId && this.playbackDurationMs > 0) {
      return formatDurationMs(this.playbackDurationMs);
    }
    if (track.durationMs > 0) {
      return formatDurationMs(track.durationMs);
    }
    return '--:--';
  }

  private applyRename(): void {
    let newTitle = this.renameText.trim();
    if (newTitle.length === 0) {
      this.showToast('名称不能为空');
      return;
    }
    let localIndex = this.localTracks.findIndex((track: MusicTrack) => track.id === this.renameTrackId);
    if (localIndex >= 0) {
      let updatedTracks = this.localTracks.slice();
      let updatedTrack = copyTrack(updatedTracks[localIndex]);
      updatedTrack.title = newTitle;
      updatedTracks[localIndex] = updatedTrack;
      this.localTracks = updatedTracks;
      this.schedulePersistState();
      this.showToast('已修改歌曲名称');
    }
    this.showRenameDialog = false;
    this.renameTrackId = '';
    this.renameText = '';
  }

  private pushRecentTrack(trackId: string): void {
    let nextRecent = this.recentTrackIds.filter((id: string) => id !== trackId);
    nextRecent.unshift(trackId);
    this.recentTrackIds = nextRecent.slice(0, MAX_RECENT_TRACKS);
    this.schedulePersistState();
  }

  private beginPlaybackRecord(trackId: string): void {
    if (trackId.length === 0) {
      return;
    }
    this.currentPlaybackRecordTrackId = trackId;
    this.currentPlaybackRecordStartedAt = Date.now();
    this.currentPlaybackRecordMs = 0;
  }

  private async flushCurrentPlaybackRecord(): Promise<void> {
    let trackId = this.currentPlaybackRecordTrackId;
    let startedAt = this.currentPlaybackRecordStartedAt;
    let listenedMs = Math.floor(this.currentPlaybackRecordMs);

    this.currentPlaybackRecordTrackId = '';
    this.currentPlaybackRecordStartedAt = 0;
    this.currentPlaybackRecordMs = 0;

    if (trackId.length === 0 || startedAt <= 0 || listenedMs < 1000) {
      return;
    }

    let track = this.localTracks.find((item: MusicTrack) => item.id === trackId);
    if (!track) {
      return;
    }

    try {
      let store = await this.ensureAppDatabaseStore();
      let record: PlaybackRecordEntry = {
        id: `${trackId}_${startedAt}_${Date.now()}`,
        trackId: track.id,
        trackTitle: track.title,
        trackArtist: track.artist,
        trackAlbum: track.album,
        trackSourceImportKey: track.sourceImportKey ?? '',
        startedAt: startedAt,
        endedAt: Date.now(),
        listenedMs: listenedMs
      };
      await appendPlaybackRecord(store, record);
      this.schedulePersistState();
    } catch (error) {
      console.error(`append playback record failed: ${JSON.stringify(error)}`);
    }
  }

  private async startTrackPlayback(track: MusicTrack, resumePositionMs: number = 0, countAsPlay: boolean = true): Promise<void> {
    this.resetAudioInterruptState();
    this.currentTrackId = track.id;
    this.pushRecentTrack(track.id);
    this.playbackProgressMs = 0;
    this.playbackDurationMs = 0;
    this.isSeekingPlayback = false;
    this.seekPreviewMs = 0;
    this.lastProgressSnapshotMs = 0;
    this.setMiniPlayButtonState(true, true);
    this.schedulePersistState();
    void this.startMusicLiveView(track);
    void this.createAVSession(track);

    await this.releasePlayer();
    this.autoPlayAfterPrepare = true;
    this.pendingStartSeekMs = this.clampSeekMs(resumePositionMs);
    this.setMiniPlayButtonState(true, true);

    try {
      let player = await media.createAVPlayer();
      let sessionId = this.playerSession + 1;
      this.playerSession = sessionId;
      this.player = player;
      this.loadedTrackId = track.id;
      this.registerPlayerCallbacks(player, sessionId);
      await this.attachTrackSource(player, track);
      if (countAsPlay) {
        this.markTrackPlayed(track.id);
      }
    } catch (error) {
      console.error(`start playback failed: ${JSON.stringify(error)}`);
      await this.releasePlayer();
      this.setMiniPlayButtonState(false, false);
      this.showToast('这首歌曲暂时无法播放，请尝试其他文件');
    }
  }

  private async restartTrackPlayerAfterInterrupt(track: MusicTrack, resumePositionMs: number): Promise<void> {
    this.resetAudioInterruptState();
    this.currentTrackId = track.id;
    this.playbackProgressMs = this.clampSeekMs(resumePositionMs);
    this.playbackDurationMs = 0;
    this.isSeekingPlayback = false;
    this.seekPreviewMs = 0;
    this.lastProgressSnapshotMs = this.playbackProgressMs;
    this.setMiniPlayButtonState(true, true);
    this.schedulePersistState();

    await this.releasePlayer();
    this.autoPlayAfterPrepare = true;
    this.pendingStartSeekMs = this.clampSeekMs(resumePositionMs);
    this.setMiniPlayButtonState(true, true);

    try {
      let player = await media.createAVPlayer();
      let sessionId = this.playerSession + 1;
      this.playerSession = sessionId;
      this.player = player;
      this.loadedTrackId = track.id;
      this.registerPlayerCallbacks(player, sessionId);
      await this.attachTrackSource(player, track);
    } catch (error) {
      console.error(`restart interrupt playback failed: ${JSON.stringify(error)}`);
      await this.releasePlayer();
      this.setMiniPlayButtonState(false, false);
      this.showToast('恢复播放失败，请返回应用后重试');
    }
  }

  private async attachTrackSource(player: media.AVPlayer, track: MusicTrack): Promise<void> {
    try {
      console.info(`attachTrackSource start: trackId=${track.id}, raw=${track.rawFileName}, sourceUri=${track.sourceUri}, filePath=${track.filePath}`);
      if (track.rawFileName.length > 0) {
        let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        let rawFileDescriptor = await context.resourceManager.getRawFd(track.rawFileName);
        this.openedRawFileName = track.rawFileName;
        player.fdSrc = rawFileDescriptor;
        return;
      }
      let playablePath = this.resolveTrackPlayablePath(track);
      try {
        let file = fs.openSync(playablePath, fs.OpenMode.READ_ONLY);
        let stat = fs.statSync(file.fd);
        this.openedFile = file;
        player.fdSrc = {
          fd: file.fd,
          offset: 0,
          length: stat.size
        };
        console.info(`attachTrackSource using fdSrc: trackId=${track.id}, path=${playablePath}, length=${stat.size}`);
        return;
      } catch (fdError) {
        if (!this.canUseSandboxUri(track, playablePath)) {
          throw new Error(`open track file failed: ${String(fdError)}`);
        }
        let sandboxUri = fileUri.getUriFromPath(playablePath);
        player.url = sandboxUri;
        console.info(`attachTrackSource fallback to sandbox uri: trackId=${track.id}, uri=${sandboxUri}`);
      }
    } catch (error) {
      console.error(`attach track source failed: ${JSON.stringify(error)}`);
      throw new Error('attach track source failed');
    }
  }

  private resolveTrackPlayablePath(track: MusicTrack): string {
    if (track.filePath.length > 0) {
      return track.filePath;
    }
    if (track.sourceUri.length > 0) {
      return new fileUri.FileUri(track.sourceUri).path;
    }
    throw new Error('track source path is empty');
  }

  private canUseSandboxUri(track: MusicTrack, playablePath: string): boolean {
    if (track.sourceUri.length > 0) {
      return false;
    }
    if (track.filePath.length === 0) {
      return false;
    }
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return playablePath.startsWith(context.filesDir);
  }

  private registerPlayerCallbacks(player: media.AVPlayer, sessionId: number): void {
    player.on('stateChange', async (state: string) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      console.info(`player state changed: session=${sessionId}, state=${state}, loadedTrackId=${this.loadedTrackId}`);
      if (state === 'initialized') {
        try {
          await player.prepare();
        } catch (error) {
          console.error(`prepare failed: ${JSON.stringify(error)}`);
          this.showToast('播放器准备失败');
        }
      } else if (state === 'prepared') {
        this.playbackDurationMs = player.duration > 0 ? player.duration : this.playbackDurationMs;
        this.cacheTrackDuration(this.loadedTrackId, this.playbackDurationMs, true);
        if (this.pendingStartSeekMs > 0) {
          let resumeAtMs = this.clampSeekMs(this.pendingStartSeekMs);
          this.pendingStartSeekMs = 0;
          this.playbackProgressMs = resumeAtMs;
          this.lastProgressSnapshotMs = resumeAtMs;
          try {
            player.seek(resumeAtMs);
          } catch (error) {
            console.error(`prepare seek failed: ${JSON.stringify(error)}`);
          }
        }
        if (this.autoPlayAfterPrepare) {
          this.autoPlayAfterPrepare = false;
          try {
            await player.play();
          } catch (error) {
            console.error(`play failed: ${JSON.stringify(error)}`);
            this.showToast('开始播放失败');
          }
        }
      } else if (state === 'playing') {
        this.resetAudioInterruptState();
        this.isPlaying = true;
        this.setMiniPlayButtonState(true, false);
        if (this.currentPlaybackRecordTrackId.length === 0) {
          this.beginPlaybackRecord(this.loadedTrackId);
        }
        this.startDiscRotation();
        void this.updateMusicLiveView(true);
        void this.startBackgroundTask();
        void this.updateAVSessionState(true);
      } else if (state === 'paused') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        void this.flushCurrentPlaybackRecord();
        void this.updateMusicLiveView(false);
        void this.updateAVSessionState(false);
      } else if (state === 'completed') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        this.playbackProgressMs = this.playbackDurationMs;
        void this.flushCurrentPlaybackRecord();
        void this.stopMusicLiveView();
        void this.stopBackgroundTask();
        void this.destroyAVSession();
        void this.playNextTrack();
      } else if (state === 'released') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        void this.flushCurrentPlaybackRecord();
        if (this.isAudioInterrupted || this.shouldResumeAfterInterrupt) {
          this.playerReleasedDuringInterrupt = true;
          void this.updateMusicLiveView(false);
          void this.updateAVSessionState(false);
          return;
        }
        void this.stopMusicLiveView();
        void this.stopBackgroundTask();
        void this.destroyAVSession();
      } else if (state === 'error') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        void this.flushCurrentPlaybackRecord();
        if (this.isAudioInterrupted || this.shouldResumeAfterInterrupt) {
          this.playerReleasedDuringInterrupt = true;
          void this.updateMusicLiveView(false);
          void this.updateAVSessionState(false);
          return;
        }
        void this.stopMusicLiveView();
        void this.stopBackgroundTask();
        void this.destroyAVSession();
        this.showToast('播放器发生错误');
      }
    });

    player.on('timeUpdate', (time: number) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      if (time >= this.lastProgressSnapshotMs && time - this.lastProgressSnapshotMs < 5000) {
        let listenedDelta = time - this.lastProgressSnapshotMs;
        this.totalListeningMs += listenedDelta;
        this.currentPlaybackRecordMs += listenedDelta;
      }
      this.lastProgressSnapshotMs = time;
      this.playbackProgressMs = time;
      // 每5秒更新一次LiveView进度
      if (time % 5000 < 100) {
        void this.updateMusicLiveView(this.isPlaying);
      }
    });

    player.on('seekDone', (time: number) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      let actualTime = player.currentTime >= 0 ? player.currentTime : time;
      this.playbackProgressMs = actualTime;
      this.lastProgressSnapshotMs = actualTime;
      if (!this.isSeekingPlayback) {
        void this.updateMusicLiveView(this.isPlaying);
        void this.updateAVSessionState(this.isPlaying);
      }
    });

    player.on('durationUpdate', (duration: number) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      this.playbackDurationMs = duration;
      this.cacheTrackDuration(this.loadedTrackId, duration, true);
    });

    player.on('audioInterrupt', (interruptEvent: audio.InterruptEvent) => {
      this.handlePlayerAudioInterrupt(interruptEvent, sessionId);
    });

    player.on('error', (error: BusinessError) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      if (this.isAudioInterrupted || this.shouldResumeAfterInterrupt || this.playerReleasedDuringInterrupt) {
        console.info(`player error ignored during audio interrupt: ${error.code}, ${error.message}`);
        return;
      }
      console.error(`player error: ${error.code}, ${error.message}`);
      this.showToast('音频文件格式暂不支持');
    });
  }

  private markTrackPlayed(trackId: string): void {
    let trackIndex = this.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (trackIndex < 0) {
      return;
    }
    let updated = this.localTracks.slice();
    let selectedTrack = copyTrack(updated[trackIndex]);
    selectedTrack.playCount = selectedTrack.playCount + 1;
    selectedTrack.lastPlayedAt = Date.now();
    updated[trackIndex] = selectedTrack;
    this.localTracks = updated;
    this.schedulePersistState();
  }

  private resetAudioInterruptState(clearResumeIntent: boolean = true): void {
    this.isAudioInterrupted = false;
    this.playerReleasedDuringInterrupt = false;
    if (!clearResumeIntent) {
      return;
    }
    this.shouldResumeAfterInterrupt = false;
    this.interruptedTrackId = '';
    this.interruptedProgressMs = 0;
  }

  private shouldPauseForAudioInterrupt(interruptEvent: audio.InterruptEvent): boolean {
    return interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
      interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP ||
      interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_MUTE;
  }

  private shouldResumeForAudioInterrupt(interruptEvent: audio.InterruptEvent): boolean {
    return interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME ||
      interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_NONE ||
      interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_UNDUCK ||
      interruptEvent.hintType === audio.InterruptHint.INTERRUPT_HINT_UNMUTE;
  }

  private handlePlayerAudioInterrupt(interruptEvent: audio.InterruptEvent, sessionId: number): void {
    if (sessionId !== this.playerSession) {
      return;
    }
    console.info(
      `audio interrupt: session=${sessionId}, eventType=${interruptEvent.eventType}, hintType=${interruptEvent.hintType}, forceType=${interruptEvent.forceType}`
    );
    if (interruptEvent.eventType === audio.InterruptType.INTERRUPT_TYPE_BEGIN) {
      this.isAudioInterrupted = true;
      this.playerReleasedDuringInterrupt = false;
      let wasPlaying = (this.player?.state === 'playing') || this.isPlaying || this.autoPlayAfterPrepare;
      if (wasPlaying) {
        this.shouldResumeAfterInterrupt = true;
        this.interruptedTrackId = this.loadedTrackId.length > 0 ? this.loadedTrackId : this.currentTrackId;
        this.interruptedProgressMs = this.playbackProgressMs;
      }
      if (this.shouldPauseForAudioInterrupt(interruptEvent)) {
        if (this.player && this.player.state === 'playing') {
          void this.pauseCurrentTrack();
        } else {
          this.isPlaying = false;
          this.setMiniPlayButtonState(false, false);
          this.stopDiscRotation();
          void this.updateMusicLiveView(false);
          void this.updateAVSessionState(false);
        }
      }
      return;
    }

    if (interruptEvent.eventType === audio.InterruptType.INTERRUPT_TYPE_END) {
      let shouldResume = this.shouldResumeAfterInterrupt && this.shouldResumeForAudioInterrupt(interruptEvent);
      this.isAudioInterrupted = false;
      if (!shouldResume) {
        this.shouldResumeAfterInterrupt = false;
        this.playerReleasedDuringInterrupt = false;
        this.interruptedTrackId = '';
        this.interruptedProgressMs = 0;
        return;
      }
      void this.resumeAfterAudioInterrupt();
    }
  }

  private async resumeAfterAudioInterrupt(): Promise<void> {
    let resumeTrackId = this.interruptedTrackId.length > 0 ? this.interruptedTrackId : this.loadedTrackId;
    let resumeProgressMs = this.interruptedProgressMs;
    this.shouldResumeAfterInterrupt = false;
    this.interruptedTrackId = '';
    this.interruptedProgressMs = 0;
    if (resumeTrackId.length === 0) {
      this.playerReleasedDuringInterrupt = false;
      return;
    }

    let track = this.localTracks.find((item: MusicTrack) => item.id === resumeTrackId);
    if (!track || !track.isImported) {
      this.playerReleasedDuringInterrupt = false;
      return;
    }

    if (this.player && this.loadedTrackId === resumeTrackId) {
      let state = this.player.state;
      if (state === 'playing') {
        this.playerReleasedDuringInterrupt = false;
        return;
      }
      if (state === 'paused' || state === 'prepared' || state === 'completed') {
        if (resumeProgressMs > 0 && Math.abs(this.playbackProgressMs - resumeProgressMs) > 1500) {
          try {
            let resumeAtMs = this.clampSeekMs(resumeProgressMs);
            this.playbackProgressMs = resumeAtMs;
            this.lastProgressSnapshotMs = resumeAtMs;
            this.player.seek(resumeAtMs);
          } catch (error) {
            console.error(`resume interrupt seek failed: ${JSON.stringify(error)}`);
          }
        }
        this.playerReleasedDuringInterrupt = false;
        await this.resumeCurrentTrack();
        return;
      }
    }

    this.playerReleasedDuringInterrupt = false;
    await this.restartTrackPlayerAfterInterrupt(track, resumeProgressMs);
  }

  private async pauseCurrentTrack(): Promise<void> {
    if (!this.player) {
      return;
    }
    this.setMiniPlayButtonState(false, true);
    try {
      await this.player.pause();
      this.isPlaying = false;
      this.setMiniPlayButtonState(false, false);
    } catch (error) {
      console.error(`pause failed: ${JSON.stringify(error)}`);
      this.setMiniPlayButtonState(true, false);
    }
  }

  private async resumeCurrentTrack(): Promise<void> {
    if (!this.player) {
      return;
    }
    this.setMiniPlayButtonState(true, true);
    try {
      await this.player.play();
      this.isPlaying = true;
      this.setMiniPlayButtonState(true, false);
    } catch (error) {
      console.error(`resume failed: ${JSON.stringify(error)}`);
      this.setMiniPlayButtonState(false, false);
    }
  }

  private async releasePlayer(): Promise<void> {
    await this.flushCurrentPlaybackRecord();
    this.resetAudioInterruptState();
    let existingPlayer = this.player;
    let existingFile = this.openedFile;
    let existingRawFileName = this.openedRawFileName;
    this.player = null;
    this.openedFile = null;
    this.openedRawFileName = '';
    this.loadedTrackId = '';
    this.isPlaying = false;
    this.isSeekingPlayback = false;
    this.seekPreviewMs = 0;
    this.setMiniPlayButtonState(false, false);
    this.autoPlayAfterPrepare = false;
    this.pendingStartSeekMs = 0;
    this.lastProgressSnapshotMs = 0;
    this.stopDiscRotation();
    if (existingPlayer) {
      try {
        await existingPlayer.release();
      } catch (error) {
        console.error(`release existing player failed: ${JSON.stringify(error)}`);
      }
    }
    if (existingFile) {
      try {
        fs.closeSync(existingFile);
      } catch (error) {
        console.error(`close file failed: ${JSON.stringify(error)}`);
      }
    }
    if (existingRawFileName.length > 0) {
      try {
        let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        context.resourceManager.closeRawFdSync(existingRawFileName);
      } catch (error) {
        console.error(`close raw file failed: ${JSON.stringify(error)}`);
      }
    }
  }
}
