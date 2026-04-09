import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { picker, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { avSession } from '@kit.AVSessionKit';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';

import {
  AUDIO_FILTERS,
  BUILTIN_BOARD_LIST,
  COLOR_PALETTE,
  LISTENING_SEED_MS,
  MAX_RECENT_TRACKS,
  MINI_PLACEHOLDER_TRACK,
  ONLINE_DOWNLOAD_MAX_BYTES
} from '../constants/AppConstants';
import {
  CollectionMode,
  LibraryDimension,
  MainTab,
  MusicSourceConfig,
  MusicSourceQuality,
  MusicSourceTrack,
  MusicTrack,
  PlayMode,
  QuickJsLogPayload,
  SourceBoardItem,
  SourceUpdateAlertPayload
} from '../models/AppModels';
import { ExploreHallPage } from '../components/explore/ExploreHallPage';
import { HomeQueuePage } from '../components/home/HomeQueuePage';
import { ImportedTrackManagerPanel } from '../components/profile/ImportedTrackManagerPanel';
import { ProfilePageContent } from '../components/profile/ProfilePageContent';
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
  onlineDownloadFailureToast as buildOnlineDownloadFailureToast,
  playbackProgressRatio,
  playQueueTracks as selectPlayQueueTracks,
  totalListeningHours,
  visibleTracks as selectVisibleTracks
} from '../utils/LibraryStateUtils';
import {
  buildDownloadedTrack,
  buildImportedTrack,
  copyTrack,
  fileNameFromUrl,
  formatDurationMs,
  originFromUrl
} from '../utils/TrackUtils';
import {
  buildSourceTrackImportKey,
  filterSupportedExploreSources,
  isSupportedExploreSource,
  sourceDisplayName
} from '../utils/MusicSourceUtils';
import {
  activatePersistedReadUriPermissions,
  deleteMusicSourceScript as deletePersistedMusicSourceScript,
  ensureAppPreferences,
  persistAppState as savePersistedAppState,
  persistReadUriPermissions,
  readMusicSourceScript,
  restorePersistedAppState
} from '../services/AppStatePersistenceService';
import {
  createPendingMusicSource,
  removeSourceById,
  resolvePreferredSubSource,
  toggleSourceUpdateAlert
} from '../services/CustomSourceCatalogService';
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
  createPlaybackLiveView,
  createPlaybackState,
  createPlaybackWantAgent,
  createSessionMetadata,
  startAudioBackgroundTask,
  stopAudioBackgroundTask
} from '../services/PlaybackPlatformService';
import {
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
  @State activeMainTab: MainTab = MainTab.Home;
  @State activeLibraryDimension: LibraryDimension = LibraryDimension.Song;
  @State collectionMode: CollectionMode = CollectionMode.Library;
  @State localTracks: Array<MusicTrack> = [];
  @State recentTrackIds: Array<string> = [];
  @State currentTrackId: string = MINI_PLACEHOLDER_TRACK.id;
  @State searchKeyword: string = '';
  @State showOnlineDownloadPanel: boolean = false;
  @State showImportedTrackManager: boolean = false;
  @State onlineDownloadUrl: string = '';
  @State onlineDownloadReferer: string = 'https://music.163.com/';
  @State onlineDownloadCookie: string = '';
  @State onlineDownloadUserAgent: string = 'Mozilla/5.0 (HarmonyOS Local Music Player)';
  @State isDownloadingOnlineTrack: boolean = false;
  @State onlineDownloadReceivedBytes: number = 0;
  @State onlineDownloadTotalBytes: number = 0;
  @State onlineDownloadTargetFileName: string = '';
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
  private trackArtworkLoadingIds: Set<string> = new Set();
  private trackArtworkUnavailableIds: Set<string> = new Set();

  private player: media.AVPlayer | null = null;
  private openedFile: fs.File | null = null;
  private openedRawFileName: string = '';
  private appPreferences: preferences.Preferences | null = null;
  private playerSession: number = 0;
  private loadedTrackId: string = '';
  private autoPlayAfterPrepare: boolean = false;
  private lastProgressSnapshotMs: number = 0;
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

  aboutToAppear(): void {
    if (this.hasInitializedState) {
      return;
    }
    this.hasInitializedState = true;
    void this.initializeAppState();
  }

  aboutToDisappear(): void {
    this.schedulePersistState();
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
    .backgroundColor('#050505')
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
    HomeQueuePage({
      tracks: this.playQueueTracks(),
      currentTrackId: this.currentTrackId,
      playMode: this.playMode,
      showRenameDialog: this.showRenameDialog,
      renameText: this.renameText,
      bottomInset: this.pageBottomInset,
      coveredTrackIds: this.trackArtworkIds,
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
        musicSources: this.musicSources,
        importedTrackCount: this.localTracks.length,
        playQueueTrackCount: this.playQueueTracks().length,
        bottomInset: this.pageBottomInset,
        onImportLocal: () => {
          void this.importLocalMusic();
        },
        onOpenOnlineDownload: () => {
          this.activeMainTab = MainTab.Home;
          this.collectionMode = CollectionMode.Library;
          this.showOnlineDownloadPanel = true;
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

  private currentTrack(): MusicTrack {
    return selectCurrentTrack(this.localTracks, this.currentTrackId);
  }

  private playQueueTracks(): Array<MusicTrack> {
    return selectPlayQueueTracks(this.localTracks);
  }

  private firstPlayQueueTrack(): MusicTrack | null {
    let queueTracks = this.playQueueTracks();
    return queueTracks.length > 0 ? queueTracks[0] : null;
  }

  private syncCurrentTrackSelection(preferredTrackId: string = ''): void {
    let current = this.localTracks.find((track: MusicTrack) => track.id === this.currentTrackId);
    if (current) {
      let isCurrentLoaded = this.loadedTrackId === current.id;
      if (current.inPlayQueue !== false || isCurrentLoaded) {
        return;
      }
    }

    if (preferredTrackId.length > 0) {
      let preferredTrack = this.localTracks.find((track: MusicTrack) => track.id === preferredTrackId);
      if (preferredTrack && preferredTrack.inPlayQueue !== false) {
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
      let session = await avSession.createAVSession(context, 'MusicPlayer', 'audio');
      this.session = session;
      await session.setAVMetadata(createSessionMetadata(track));

      session.on('play', () => {
        void this.resumeCurrentTrack();
      });
      session.on('pause', () => {
        void this.pauseCurrentTrack();
      });
      session.on('playNext', () => {
        void this.playNextTrack();
      });

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
      this.discRotationAngle = (this.discRotationAngle + 8) % 360;
    }, 120) as number;
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
      this.syncTrackArtworkCache();
    }
  }

  private async ensurePreferences(): Promise<preferences.Preferences> {
    if (this.appPreferences !== null) {
      return this.appPreferences;
    }
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.appPreferences = await ensureAppPreferences(this.appPreferences, context);
      return this.appPreferences;
    } catch (error) {
      console.error(`ensure preferences failed: ${JSON.stringify(error)}`);
      throw new Error('ensure preferences failed');
    }
  }

  private async getMusicSourceScript(sourceId: string): Promise<string> {
    let store = await this.ensurePreferences();
    return await readMusicSourceScript(store, this.musicSourceScripts, sourceId);
  }

  private async deleteMusicSourceScript(sourceId: string): Promise<void> {
    let store = await this.ensurePreferences();
    await deletePersistedMusicSourceScript(store, this.musicSourceScripts, sourceId);
  }

  private async restorePersistedState(): Promise<void> {
    let store = await this.ensurePreferences();
    let restoredState = await restorePersistedAppState(store);
    this.localTracks = restoredState.localTracks;
    this.recentTrackIds = restoredState.recentTrackIds;
    this.currentTrackId = restoredState.currentTrackId;
    this.collectionMode = restoredState.collectionMode;
    this.totalListeningMs = restoredState.totalListeningMs;
    this.playMode = restoredState.playMode;
    this.musicSources = restoredState.musicSources;
    this.musicSourceScripts = restoredState.musicSourceScripts;
    this.syncCurrentTrackSelection();
  }

  private trackArtworkForTrack(trackId: string): image.PixelMap | null {
    return this.trackArtworkMap.get(trackId) ?? null;
  }

  private refreshTrackArtworkIds(): void {
    this.trackArtworkIds = this.localTracks.filter((track: MusicTrack) => this.trackArtworkMap.has(track.id))
      .map((track: MusicTrack) => track.id);
  }

  private syncTrackArtworkCache(): void {
    let activeTrackIds = this.localTracks.map((track: MusicTrack) => track.id);

    Array.from(this.trackArtworkMap.keys()).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) {
        void this.releaseCachedTrackArtwork(trackId);
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

    this.localTracks.forEach((track: MusicTrack) => {
      let hasPlayableFile = track.filePath.length > 0 || track.sourceUri.length > 0;
      if (!hasPlayableFile || this.trackArtworkMap.has(track.id) || this.trackArtworkLoadingIds.has(track.id) ||
        this.trackArtworkUnavailableIds.has(track.id)) {
        return;
      }
      void this.loadTrackArtwork(track);
    });
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
        this.trackArtworkUnavailableIds.add(track.id);
        return;
      }
      let previous = this.trackArtworkMap.get(track.id);
      this.trackArtworkMap.set(track.id, pixelMap);
      this.trackArtworkUnavailableIds.delete(track.id);
      this.refreshTrackArtworkIds();
      await releaseExtractedTrackArtwork(previous);
    } finally {
      this.trackArtworkLoadingIds.delete(track.id);
    }
  }

  private async releaseCachedTrackArtwork(trackId: string): Promise<void> {
    let pixelMap = this.trackArtworkMap.get(trackId);
    this.trackArtworkMap.delete(trackId);
    this.trackArtworkLoadingIds.delete(trackId);
    this.trackArtworkUnavailableIds.delete(trackId);
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
    void this.persistState();
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
        let store = await this.ensurePreferences();
        await savePersistedAppState(store, {
          localTracks: this.localTracks,
          recentTrackIds: this.recentTrackIds,
          currentTrackId: this.currentTrackId,
          collectionMode: this.collectionMode,
          totalListeningMs: this.totalListeningMs,
          playMode: this.playMode,
          musicSources: this.musicSources
        }, this.musicSourceScripts);
      } while (this.pendingPersistState);
    } catch (error) {
      console.error(`persist state failed: ${JSON.stringify(error)}`);
    } finally {
      this.isPersistingState = false;
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
      this.syncTrackArtworkCache();
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

  private async downloadOnlineTrack(): Promise<void> {
    if (this.isDownloadingOnlineTrack) {
      return;
    }
    let trimmedUrl = this.onlineDownloadUrl.trim();
    if (!(trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://'))) {
      this.showToast('请输入有效的 http 或 https 音频链接');
      return;
    }

    let targetFileName = '';
    try {
      targetFileName = `${Date.now()}-${fileNameFromUrl(trimmedUrl)}`;
    } catch (_) {
      this.showToast('当前仅支持直接下载 mp3 等音频链接');
      return;
    }

    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let downloadDirectory = `${context.filesDir}/downloads`;
    let targetPath = `${downloadDirectory}/${targetFileName}`;
    let referer = this.onlineDownloadReferer.trim();
    let cookie = this.onlineDownloadCookie.trim();
    let userAgent = this.onlineDownloadUserAgent.trim();
    let requestHeaders: Record<string, string> = {
      'Accept': 'audio/*,*/*',
      'User-Agent': userAgent.length > 0 ? userAgent : 'Mozilla/5.0 (HarmonyOS Local Music Player)'
    };
    if (referer.length > 0) {
      requestHeaders['Referer'] = referer;
      let origin = originFromUrl(referer);
      if (origin.length > 0) {
        requestHeaders['Origin'] = origin;
      }
    }
    if (cookie.length > 0) {
      requestHeaders['Cookie'] = cookie;
    }

    this.isDownloadingOnlineTrack = true;
    this.showOnlineDownloadPanel = true;
    this.onlineDownloadTargetFileName = targetFileName;
    this.onlineDownloadReceivedBytes = 0;
    this.onlineDownloadTotalBytes = 0;

    try {
      if (!fs.accessSync(downloadDirectory)) {
        fs.mkdirSync(downloadDirectory, true);
      }
    } catch (error) {
      let errorText = JSON.stringify(error);
      if (errorText.indexOf('13900015') < 0) {
        console.error(`create download directory failed: ${errorText}`);
      }
    }

    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(trimmedUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 60000,
        connectTimeout: 60000,
        usingCache: false,
        priority: 1000,
        maxLimit: ONLINE_DOWNLOAD_MAX_BYTES,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        header: requestHeaders
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`http status ${response.responseCode}`);
      }

      let audioBuffer = response.result as ArrayBuffer;
      if (!(audioBuffer instanceof ArrayBuffer) || audioBuffer.byteLength === 0) {
        throw new Error('empty response buffer');
      }
      this.onlineDownloadReceivedBytes = audioBuffer.byteLength;
      this.onlineDownloadTotalBytes = audioBuffer.byteLength;
      if (fs.accessSync(targetPath)) {
        fs.unlinkSync(targetPath);
      }
      let outputFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try {
        fs.writeSync(outputFile.fd, audioBuffer);
      } finally {
        fs.closeSync(outputFile);
      }

      let importedTrack = buildDownloadedTrack(targetPath, trimmedUrl, this.localTracks.length);
      let alreadyExists = this.localTracks.some((track: MusicTrack) => track.filePath === targetPath);
      if (!alreadyExists) {
        this.localTracks = this.localTracks.concat([importedTrack]);
        this.syncTrackArtworkCache();
      }
      this.collectionMode = CollectionMode.Library;
      this.activeLibraryDimension = LibraryDimension.Song;
      this.activeMainTab = MainTab.Home;
      this.currentTrackId = alreadyExists ? this.currentTrackId : importedTrack.id;
      this.schedulePersistState();
      this.showToast('在线音频已下载并导入');
      this.onlineDownloadUrl = '';
    } catch (error) {
      console.error(`download online track failed: ${JSON.stringify(error)} / ${String(error)}`);
      this.showToast(buildOnlineDownloadFailureToast(error as Object));
    } finally {
      httpRequest.destroy();
      this.isDownloadingOnlineTrack = false;
      this.onlineDownloadReceivedBytes = 0;
      this.onlineDownloadTotalBytes = 0;
      this.onlineDownloadTargetFileName = '';
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

      let importedTrack: MusicTrack = {
        id: `source-${Date.now()}`,
        title: track.name,
        artist: track.singer,
        album: track.album,
        folder: 'downloads',
        sourceUri: '',
        filePath: targetPath,
        rawFileName: '',
        accentColor: COLOR_PALETTE[this.localTracks.length % COLOR_PALETTE.length],
        pic: track.pic ?? '',
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
        this.syncTrackArtworkCache();
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
    this.syncTrackArtworkCache();
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
      this.schedulePersistState();
      this.showToast(updatedTracks[localIndex].isFavorite ? '已加入收藏' : '已取消收藏');
    }
  }

  private trackDurationText(track: MusicTrack): string {
    if (track.id === this.currentTrackId && this.playbackDurationMs > 0) {
      return formatDurationMs(this.playbackDurationMs);
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

  private async startTrackPlayback(track: MusicTrack): Promise<void> {
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
    this.setMiniPlayButtonState(true, true);

    try {
      let player = await media.createAVPlayer();
      let sessionId = this.playerSession + 1;
      this.playerSession = sessionId;
      this.player = player;
      this.loadedTrackId = track.id;
      this.registerPlayerCallbacks(player, sessionId);
      await this.attachTrackSource(player, track);
      this.markTrackPlayed(track.id);
    } catch (error) {
      console.error(`start playback failed: ${JSON.stringify(error)}`);
      await this.releasePlayer();
      this.setMiniPlayButtonState(false, false);
      this.showToast('这首歌曲暂时无法播放，请尝试其他文件');
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
        this.isPlaying = true;
        this.setMiniPlayButtonState(true, false);
        this.startDiscRotation();
        void this.updateMusicLiveView(true);
        void this.startBackgroundTask();
        void this.updateAVSessionState(true);
      } else if (state === 'paused') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        void this.updateMusicLiveView(false);
        void this.updateAVSessionState(false);
      } else if (state === 'completed') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        this.playbackProgressMs = this.playbackDurationMs;
        void this.stopMusicLiveView();
        void this.stopBackgroundTask();
        void this.destroyAVSession();
        void this.playNextTrack();
      } else if (state === 'released') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        void this.stopMusicLiveView();
        void this.stopBackgroundTask();
        void this.destroyAVSession();
      } else if (state === 'error') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
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
        this.totalListeningMs += time - this.lastProgressSnapshotMs;
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
    });

    player.on('error', (error: BusinessError) => {
      if (sessionId !== this.playerSession) {
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
