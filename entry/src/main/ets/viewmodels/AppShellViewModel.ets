import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { fileUri } from '@kit.CoreFileKit';
import { avSession } from '@kit.AVSessionKit';
import fs from '@ohos.file.fs';
import notificationManager from '@ohos.notificationManager';
import {
  APP_BUNDLE_NAME,
  APP_ENTRY_ABILITY_NAME,
  LIVE_VIEW_ICON_FRAME_COUNT
} from '../constants/AppConstants';
import {
  AppThemeAppearance,
  AppThemeMode,
  CustomPlaylist,
  MusicTrack,
  PlayMode,
  PlaybackCollectionSummary
} from '../models/AppModels';
import { copyTrack } from '../utils/TrackUtils';
import {
  appThemeModeToColorMode,
  resolveAppThemeAppearance
} from '../utils/ThemeUtils';
import { resolveTrackDisplayCover } from '../utils/TrackCoverDisplayUtils';
import {
  applyPlaybackLiveViewUpdate,
  applyStoppedLiveViewUpdate,
  buildPlaybackCollectionQueueItems,
  buildPlaybackCollectionQueueTitle,
  buildTrackQueueItems,
  createPlaybackLiveView,
  createPlaybackState,
  createPlaybackWantAgent,
  createSessionMetadata,
  loopModeToPlayMode,
  playModeToLoopMode,
  resolveLiveViewIconFileName,
  startAudioBackgroundTask,
  stopAudioBackgroundTask
} from '../services/PlaybackPlatformService';
import { t } from '../utils/I18nUtil';
import { BaseViewModel } from './BaseViewModel';

@Observed
export class AppShellState {
  appThemeMode: AppThemeMode = AppThemeMode.Light;
  themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
}

export class AppShellViewModel extends BaseViewModel {
  private session: avSession.AVSession | null = null;
  private liveView: liveViewManager.LiveView | null = null;
  private liveViewSequence: number = 0;
  private liveViewCoverTrackId: string = '';
  private liveViewUnavailable: boolean = false;
  private liveViewCompactLayout: boolean = false;
  private liveViewIconFrameIndex: number = 0;
  private liveViewIconTimer: number = -1;
  private coverArtFilePath: string = '';
  private isBackgroundTaskRunning: boolean = false;
  private backgroundNotificationId: number = -1;
  private backgroundNotificationLabel: string = '';
  private backgroundNotificationSlotType: number = -1;
  private backgroundNotificationContentType: number = -1;
  private backgroundNotificationTypeCode: number = -1;
  private backgroundNotificationSupportsSystemLiveView: boolean = false;
  private backgroundNotificationProbeTimer: number = -1;
  private systemColorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  // Callbacks
  onResumeCurrentTrack: (() => void) | null = null;
  onPauseCurrentTrack: (() => void) | null = null;
  onPlayNextTrack: (() => void) | null = null;
  onPlayPreviousTrack: (() => void) | null = null;
  onSeekCurrentTrack: ((ms: number) => void) | null = null;
  onToggleFavorite: ((assetId: string) => void) | null = null;
  onSetPlayMode: ((mode: PlayMode) => void) | null = null;
  onSelectPlaybackCollectionForCar: ((collectionId: string) => void) | null = null;
  onStartTrackPlayback: ((track: MusicTrack) => void) | null = null;
  onRefreshAVSessionQueue: (() => void) | null = null;
  onRequestTrackArtwork: ((trackId: string) => image.PixelMap | null) | null = null;

  // Theme
  applyThemeMode(state: AppShellState, mode: AppThemeMode, shouldPersist: boolean): void {
    state.appThemeMode = mode;
    this.updateApplicationColorMode(mode);
    this.systemColorMode = this.resolveSystemColorMode();
    state.themeAppearance = resolveAppThemeAppearance(mode, this.systemColorMode);
    this.syncThemeStorage(state);
    if (shouldPersist) {
      this.schedulePersist();
    }
  }

  private updateApplicationColorMode(mode: AppThemeMode): void {
    try {
      let context = this.context();
      context.getApplicationContext().setColorMode(appThemeModeToColorMode(mode));
    } catch (error) {
      console.error(`apply app theme mode failed: ${JSON.stringify(error)}`);
    }
  }

  private resolveSystemColorMode(): ConfigurationConstant.ColorMode {
    try {
      let context = this.context();
      return context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } catch (error) {
      console.error(`resolve system color mode failed: ${JSON.stringify(error)}`);
      return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
  }

  private syncThemeStorage(state: AppShellState): void {
    if (AppStorage.has('appThemeMode')) {
      AppStorage.set('appThemeMode', state.appThemeMode);
    } else {
      AppStorage.setOrCreate('appThemeMode', state.appThemeMode);
    }
    if (AppStorage.has('appThemeAppearance')) {
      AppStorage.set('appThemeAppearance', state.themeAppearance);
    } else {
      AppStorage.setOrCreate('appThemeAppearance', state.themeAppearance);
    }
  }

  // AVSession
  async createAVSession(
    track: MusicTrack,
    durationMs: number,
    isFavorite: boolean,
    playMode: PlayMode,
    currentLyricMetadataText: string,
    currentLyricContentText: string,
    currentLyricSecondaryText: string,
    previousAssetId: string,
    nextAssetId: string
  ): Promise<void> {
    try {
      await this.destroyAVSession();
      let context = this.context();
      let clickAction = await createPlaybackWantAgent(context, APP_BUNDLE_NAME, APP_ENTRY_ABILITY_NAME);
      let session = await avSession.createAVSession(context, 'MusicPlayer', 'audio');
      this.session = session;
      let metadata = createSessionMetadata(
        track, this.currentSessionCoverUri(), durationMs,
        currentLyricContentText, previousAssetId, nextAssetId,
        currentLyricMetadataText,
        this.avSessionSubtitleText(track, currentLyricMetadataText, currentLyricSecondaryText),
        this.avSessionDescriptionText(track, currentLyricMetadataText, currentLyricSecondaryText)
      );
      await session.setAVMetadata(metadata);
      await session.setLaunchAbility(clickAction);
      if (this.onRefreshAVSessionQueue) {
        this.onRefreshAVSessionQueue();
      }
      this.registerSessionHandlers(session);
      await session.activate();
    } catch (error) {
      console.error(`createAVSession failed: ${JSON.stringify(error)}`);
    }
  }

  private registerSessionHandlers(session: avSession.AVSession): void {
    session.on('play', () => { if (this.onResumeCurrentTrack) void this.onResumeCurrentTrack(); });
    session.on('pause', () => { if (this.onPauseCurrentTrack) void this.onPauseCurrentTrack(); });
    session.on('playNext', () => { if (this.onPlayNextTrack) void this.onPlayNextTrack(); });
    session.on('playPrevious', () => { if (this.onPlayPreviousTrack) void this.onPlayPreviousTrack(); });
    session.on('seek', (time: number) => { if (this.onSeekCurrentTrack) void this.onSeekCurrentTrack(time); });
    session.on('fastForward', () => { if (this.onSeekCurrentTrack) void this.onSeekCurrentTrack(15000); });
    session.on('rewind', () => { if (this.onSeekCurrentTrack) void this.onSeekCurrentTrack(-15000); });
    session.on('setLoopMode', (mode: avSession.LoopMode) => {
      if (this.onSetPlayMode) this.onSetPlayMode(loopModeToPlayMode(mode));
    });
    session.on('stop', () => { if (this.onPauseCurrentTrack) void this.onPauseCurrentTrack(); });
    session.on('toggleFavorite', (assetId: string) => { if (this.onToggleFavorite) this.onToggleFavorite(assetId); });
    try {
      session.on('playWithAssetId', (assetId: string) => {
        // handled by Index
      });
    } catch (error) {
      console.warn(`register playWithAssetId failed: ${JSON.stringify(error)}`);
    }
  }

  async updateAVSessionState(playing: boolean, progressMs: number, durationMs: number, playMode: PlayMode, isFavorite: boolean): Promise<void> {
    if (!this.session) return;
    try {
      await this.session.setAVPlaybackState(createPlaybackState(playing, progressMs, durationMs, playMode, isFavorite));
    } catch (error) {
      console.error(`updateAVSessionState failed: ${JSON.stringify(error)}`);
    }
  }

  async updateAVSessionCoverArt(
    track: MusicTrack,
    durationMs: number,
    isFavorite: boolean,
    playMode: PlayMode,
    currentLyricMetadataText: string,
    currentLyricContentText: string,
    currentLyricSecondaryText: string,
    previousAssetId: string,
    nextAssetId: string
  ): Promise<void> {
    if (!this.session) return;
    try {
      let metadata = createSessionMetadata(
        track, this.currentSessionCoverUri(), durationMs,
        currentLyricContentText, previousAssetId, nextAssetId,
        currentLyricMetadataText,
        this.avSessionSubtitleText(track, currentLyricMetadataText, currentLyricSecondaryText),
        this.avSessionDescriptionText(track, currentLyricMetadataText, currentLyricSecondaryText)
      );
      await this.session.setAVMetadata(metadata);
    } catch (error) {
      console.error(`updateAVSessionCoverArt failed: ${JSON.stringify(error)}`);
    }
  }

  async ensureIdleAVSession(): Promise<void> {
    if (this.session) return;
    try {
      let context = this.context();
      let clickAction = await createPlaybackWantAgent(context, APP_BUNDLE_NAME, APP_ENTRY_ABILITY_NAME);
      let session = await avSession.createAVSession(context, 'MusicPlayer', 'audio');
      this.session = session;
      await session.setAVMetadata({ assetId: 'idle', title: t('app.name'), artist: t('playback.waiting') });
      await session.setLaunchAbility(clickAction);
      if (this.onRefreshAVSessionQueue) {
        this.onRefreshAVSessionQueue();
      }
      this.registerSessionHandlers(session);
      let idleState: avSession.AVPlaybackState = {
        state: avSession.PlaybackState.PLAYBACK_STATE_INITIAL,
        isFavorite: false,
        loopMode: playModeToLoopMode(PlayMode.Sequential)
      };
      await session.setAVPlaybackState(idleState);
      await session.activate();
    } catch (error) {
      console.error(`ensureIdleAVSession failed: ${JSON.stringify(error)}`);
    }
  }

  async destroyAVSession(): Promise<void> {
    if (!this.session) return;
    try {
      await this.session.destroy();
      this.session = null;
    } catch (error) {
      console.error(`destroyAVSession failed: ${JSON.stringify(error)}`);
      this.session = null;
    }
  }

  async refreshAVSessionQueue(localTracks: MusicTrack[], customPlaylists: CustomPlaylist[], activePlaybackCollectionId: string): Promise<void> {
    if (!this.session) return;
    try {
      await this.session.setAVQueueTitle(buildPlaybackCollectionQueueTitle());
    } catch (error) {
      console.error(`refresh AVSession queue failed: ${JSON.stringify(error)}`);
    }
  }

  async refreshAVSessionTrackQueue(tracks: MusicTrack[]): Promise<void> {
    if (!this.session) return;
    try {
      await this.session.setAVQueueItems(buildTrackQueueItems(tracks));
    } catch (error) {
      console.error(`refresh AVSession track queue failed: ${JSON.stringify(error)}`);
    }
  }

  // LiveView
  async startMusicLiveView(track: MusicTrack, currentLyricPreviewText: string, currentLyricSecondaryText: string): Promise<void> {
    if (this.liveViewUnavailable) {
      this.liveView = null;
      this.liveViewCompactLayout = false;
      return;
    }
    try {
      let enabled = await liveViewManager.isLiveViewEnabled();
      if (!enabled) {
        this.liveViewUnavailable = true;
        this.liveView = null;
        return;
      }
      this.liveViewSequence = 1;
      this.liveViewIconFrameIndex = 0;
      await this.saveLiveViewCoverIcon(track.id);
      let icon = this.resolveLiveViewIcon(track, false);
      let context = this.context();
      let clickAction = await createPlaybackWantAgent(context, APP_BUNDLE_NAME, APP_ENTRY_ABILITY_NAME);
      let nextLiveView = createPlaybackLiveView(track, clickAction, this.liveViewSequence, icon, currentLyricPreviewText, currentLyricSecondaryText, false);
      await liveViewManager.startLiveView(nextLiveView);
      this.liveView = nextLiveView;
      this.liveViewCompactLayout = false;
    } catch (error) {
      let handledError: BusinessError = error as BusinessError;
      let errorCode = handledError.code;
      if (errorCode === 401) {
        try {
          let icon = this.resolveLiveViewIcon(track, false);
          let context = this.context();
          let clickAction = await createPlaybackWantAgent(context, APP_BUNDLE_NAME, APP_ENTRY_ABILITY_NAME);
          let compactLiveView = createPlaybackLiveView(track, clickAction, this.liveViewSequence, icon, currentLyricPreviewText, currentLyricSecondaryText, true);
          await liveViewManager.startLiveView(compactLiveView);
          this.liveView = compactLiveView;
          this.liveViewCompactLayout = true;
          return;
        } catch (compactError) {
          handledError = compactError as BusinessError;
          errorCode = handledError.code;
        }
      }
      if (errorCode === 401 || errorCode === 1003500004 || errorCode === 1003500005) {
        this.liveViewUnavailable = true;
      }
      this.liveView = null;
      this.liveViewCompactLayout = false;
    }
  }

  async updateMusicLiveView(playing: boolean, track: MusicTrack, progressMs: number, durationMs: number, currentLyricPreviewText: string, currentLyricSecondaryText: string): Promise<void> {
    if (!this.liveView) return;
    try {
      this.liveViewSequence += 1;
      if (track.id !== this.liveViewCoverTrackId) {
        await this.saveLiveViewCoverIcon(track.id);
      }
      let icon = this.resolveLiveViewIcon(track, playing);
      let progress = durationMs > 0 ? Math.round(progressMs / durationMs * 100) : 0;
      this.liveView = applyPlaybackLiveViewUpdate(this.liveView, track, this.liveViewSequence, progress, playing, icon, currentLyricPreviewText, currentLyricSecondaryText, this.liveViewCompactLayout);
      await liveViewManager.updateLiveView(this.liveView);
    } catch (error) {
      let errorCode = (error as BusinessError).code;
      if (errorCode === 1003500009 || errorCode === 1003500010 || errorCode === 401) {
        if (errorCode === 401) this.liveViewUnavailable = true;
        this.liveView = null;
        this.liveViewCompactLayout = false;
      }
    }
  }

  async stopMusicLiveView(): Promise<void> {
    if (!this.liveView) return;
    try {
      this.liveViewSequence += 1;
      this.liveView = applyStoppedLiveViewUpdate(this.liveView, this.liveViewSequence, this.currentLiveViewIconFileName(false), this.liveViewCompactLayout);
      await liveViewManager.stopLiveView(this.liveView);
      this.liveView = null;
      this.liveViewCompactLayout = false;
    } catch (error) {
      this.liveView = null;
      this.liveViewCompactLayout = false;
    }
  }

  startLiveViewIconRotation(isPlaying: boolean): void {
    if (this.liveViewIconTimer >= 0) return;
    this.liveViewIconTimer = setInterval(() => {
      if (!isPlaying || !this.liveView) return;
      this.liveViewIconFrameIndex = (this.liveViewIconFrameIndex + 1) % LIVE_VIEW_ICON_FRAME_COUNT;
    }, 420) as number;
  }

  stopLiveViewIconRotation(resetFrame: boolean = false): void {
    if (this.liveViewIconTimer >= 0) {
      clearInterval(this.liveViewIconTimer);
      this.liveViewIconTimer = -1;
    }
    if (resetFrame) this.liveViewIconFrameIndex = 0;
  }

  private currentLiveViewIconFileName(playing: boolean): string {
    return resolveLiveViewIconFileName(playing, this.liveViewIconFrameIndex);
  }

  private resolveLiveViewIcon(track: MusicTrack, playing: boolean): string | image.PixelMap {
    let pixelMap = this.onRequestTrackArtwork ? this.onRequestTrackArtwork(track.id) : null;
    let cover = resolveTrackDisplayCover(track, pixelMap);
    return cover ?? resolveLiveViewIconFileName(playing, this.liveViewIconFrameIndex);
  }

  private async saveLiveViewCoverIcon(trackId: string): Promise<void> {
    // This needs the artwork from TrackMetadataViewModel - handled via callback
    this.liveViewCoverTrackId = trackId;
  }

  setCoverArtFilePath(path: string): void {
    this.coverArtFilePath = path;
  }

  private currentSessionCoverUri(): string {
    if (this.coverArtFilePath.length === 0) return '';
    try {
      if (!fs.accessSync(this.coverArtFilePath)) return '';
      return fileUri.getUriFromPath(this.coverArtFilePath);
    } catch (_) {
      return '';
    }
  }

  private avSessionTrackMetaText(track: MusicTrack): string {
    let artist = track.artist.trim();
    let album = track.album.trim();
    if (artist.length > 0 && album.length > 0) return `${artist} · ${album}`;
    if (artist.length > 0) return artist;
    if (album.length > 0) return album;
    return track.title;
  }

  private avSessionSubtitleText(track: MusicTrack, lyricText: string, secondaryLyricText: string): string {
    let secondary = secondaryLyricText.trim();
    if (this.liveViewUnavailable && lyricText.length > 0) return track.title;
    if (secondary.length > 0) return secondary;
    let metaText = this.avSessionTrackMetaText(track);
    return metaText !== track.title ? metaText : '';
  }

  private avSessionDescriptionText(track: MusicTrack, lyricText: string, secondaryLyricText: string): string {
    let secondary = secondaryLyricText.trim();
    let metaText = this.avSessionTrackMetaText(track);
    if (this.liveViewUnavailable && lyricText.length > 0) {
      return secondary.length > 0 ? secondary : metaText;
    }
    let subtitleText = this.avSessionSubtitleText(track, lyricText, secondaryLyricText);
    return (metaText.length > 0 && metaText !== subtitleText) ? metaText : '';
  }

  // Background task
  async startBackgroundTask(): Promise<void> {
    if (this.isBackgroundTaskRunning) return;
    try {
      let context = this.context();
      let clickAction = await createPlaybackWantAgent(context, APP_BUNDLE_NAME, APP_ENTRY_ABILITY_NAME);
      let taskNotification = await startAudioBackgroundTask(context, clickAction);
      this.isBackgroundTaskRunning = true;
      this.backgroundNotificationId = taskNotification.notificationId;
      this.backgroundNotificationSlotType = taskNotification.slotType as number;
      this.backgroundNotificationContentType = taskNotification.contentType as number;
      this.backgroundNotificationTypeCode = -1;
      this.backgroundNotificationSupportsSystemLiveView =
        this.backgroundNotificationSlotType === notificationManager.SlotType.LIVE_VIEW ||
        this.backgroundNotificationContentType === notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW;
      this.scheduleBackgroundNotificationProbe();
    } catch (error) {
      this.resetBackgroundNotificationState();
      console.error(`startBackgroundTask failed: ${JSON.stringify(error)}`);
    }
  }

  async stopBackgroundTask(): Promise<void> {
    if (!this.isBackgroundTaskRunning) return;
    try {
      let context = this.context();
      await stopAudioBackgroundTask(context);
      this.isBackgroundTaskRunning = false;
      this.resetBackgroundNotificationState();
    } catch (error) {
      console.error(`stopBackgroundTask failed: ${JSON.stringify(error)}`);
    }
  }

  private clearBackgroundNotificationProbe(): void {
    if (this.backgroundNotificationProbeTimer < 0) return;
    clearTimeout(this.backgroundNotificationProbeTimer);
    this.backgroundNotificationProbeTimer = -1;
  }

  private resetBackgroundNotificationState(): void {
    this.clearBackgroundNotificationProbe();
    this.backgroundNotificationId = -1;
    this.backgroundNotificationLabel = '';
    this.backgroundNotificationSlotType = -1;
    this.backgroundNotificationContentType = -1;
    this.backgroundNotificationTypeCode = -1;
    this.backgroundNotificationSupportsSystemLiveView = false;
  }

  private scheduleBackgroundNotificationProbe(): void {
    this.clearBackgroundNotificationProbe();
    this.backgroundNotificationProbeTimer = setTimeout(() => {
      this.backgroundNotificationProbeTimer = -1;
      void this.inspectBackgroundNotification();
    }, 400) as number;
  }

  private async inspectBackgroundNotification(): Promise<void> {
    try {
      let notifications = await notificationManager.getActiveNotifications();
      if (notifications.length === 0) return;
      let request = notifications[0];
      this.backgroundNotificationId = request.id ?? -1;
      this.backgroundNotificationLabel = request.label ?? '';
      let slotType = request.notificationSlotType ?? -1;
      let contentType = request.content.notificationContentType ?? -1;
      let systemLiveView = request.content.systemLiveView;
      this.backgroundNotificationSlotType = slotType;
      this.backgroundNotificationContentType = contentType;
      this.backgroundNotificationSupportsSystemLiveView = systemLiveView !== undefined ||
        slotType === notificationManager.SlotType.LIVE_VIEW ||
        contentType === notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW;
      if (systemLiveView && typeof systemLiveView.typeCode === 'number') {
        this.backgroundNotificationTypeCode = systemLiveView.typeCode;
      }
    } catch (error) {
      console.error(`inspectBackgroundNotification failed: ${JSON.stringify(error)}`);
    }
  }

  async updateBackgroundLyricNotification(track: MusicTrack, currentLyricMetadataText: string, currentLyricSecondaryText: string): Promise<void> {
    if (!this.isBackgroundTaskRunning) return;
    if (!this.backgroundNotificationSupportsSystemLiveView || this.backgroundNotificationTypeCode < 0) {
      await this.inspectBackgroundNotification();
      if (!this.backgroundNotificationSupportsSystemLiveView || this.backgroundNotificationTypeCode < 0) return;
    }
    let lyricTitle = currentLyricMetadataText.trim();
    if (lyricTitle.length === 0) lyricTitle = track.title.trim();
    let detailText = currentLyricSecondaryText.trim();
    if (detailText.length === 0) detailText = this.avSessionTrackMetaText(track);
    if (detailText.length === 0) detailText = track.title;
    let liveViewContent: notificationManager.NotificationSystemLiveViewContent = {
      typeCode: this.backgroundNotificationTypeCode,
      title: lyricTitle,
      text: detailText,
      capsule: { title: lyricTitle }
    };
    let request: notificationManager.NotificationRequest = {
      updateOnly: true,
      isOngoing: true,
      isUnremovable: true,
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
        systemLiveView: liveViewContent
      }
    };
    if (this.backgroundNotificationId >= 0) request.id = this.backgroundNotificationId;
    if (this.backgroundNotificationLabel.length > 0) request.label = this.backgroundNotificationLabel;
    try {
      await notificationManager.publish(request);
    } catch (error) {
      let errorCode = (error as BusinessError).code;
      if (errorCode === 1600007) this.resetBackgroundNotificationState();
    }
  }

  isBackgroundRunning(): boolean {
    return this.isBackgroundTaskRunning;
  }

  hasSession(): boolean {
    return this.session !== null;
  }

  hasLiveView(): boolean {
    return this.liveView !== null;
  }

  dispose(): void {
    this.stopLiveViewIconRotation(true);
    void this.stopMusicLiveView();
    void this.destroyAVSession();
    void this.stopBackgroundTask();
  }
}
