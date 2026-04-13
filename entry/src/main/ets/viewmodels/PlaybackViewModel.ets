import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import audio from '@ohos.multimedia.audio';
import { MINI_PLACEHOLDER_TRACK } from '../constants/AppConstants';
import { MusicTrack, PlayMode } from '../models/AppModels';
import { copyTrack, formatDurationMs } from '../utils/TrackUtils';
import { t } from '../utils/I18nUtil';
import { BaseViewModel } from './BaseViewModel';

@Observed
export class PlaybackState {
  isPlaying: boolean = false;
  playButtonShowsPause: boolean = false;
  isPlayButtonTransitioning: boolean = false;
  discRotationAngle: number = 0;
  playButtonScale: number = 1;
  nextButtonScale: number = 1;
  playbackProgressMs: number = 0;
  playbackDurationMs: number = 0;
  isSeekingPlayback: boolean = false;
  seekPreviewMs: number = 0;
  currentTrackId: string = MINI_PLACEHOLDER_TRACK.id;
  loadedTrackId: string = '';
}

export class PlaybackViewModel extends BaseViewModel {
  private player: media.AVPlayer | null = null;
  private openedFile: fs.File | null = null;
  private openedRawFileName: string = '';
  private playbackLaunchToken: number = 0;
  private playerSession: number = 0;
  private autoPlayAfterPrepare: boolean = false;
  private pendingStartSeekMs: number = 0;
  private lastProgressSnapshotMs: number = 0;
  private isAudioInterrupted: boolean = false;
  private shouldResumeAfterInterrupt: boolean = false;
  private playerReleasedDuringInterrupt: boolean = false;
  private interruptedTrackId: string = '';
  private interruptedProgressMs: number = 0;
  private discRotationTimer: number = -1;
  private currentPlaybackRecordTrackId: string = '';
  private currentPlaybackRecordStartedAt: number = 0;
  private currentPlaybackRecordMs: number = 0;

  // Callbacks for Index to handle cross-concern updates
  onPlaybackStateChanged: ((playing: boolean) => void) | null = null;
  onTrackSwitched: ((trackId: string) => void) | null = null;
  onProgressUpdated: ((progressMs: number, durationMs: number) => void) | null = null;
  onLyricIndexChanged: ((index: number) => void) | null = null;
  onPlaybackCompleted: (() => void) | null = null;
  onPlaybackError: ((message: string) => void) | null = null;
  onPlaybackRecordFlush: ((trackId: string, startedAt: number, listenedMs: number) => void) | null = null;
  onPlaybackRecordBegin: ((trackId: string) => void) | null = null;
  onDurationCached: ((trackId: string, durationMs: number) => void) | null = null;

  clampSeekMs(value: number, durationMs: number): number {
    let safeValue = Math.max(0, Math.floor(value));
    if (durationMs <= 0) {
      return safeValue;
    }
    return Math.min(safeValue, durationMs);
  }

  setMiniPlayButtonState(state: PlaybackState, showPause: boolean, transitioning: boolean): void {
    state.playButtonShowsPause = showPause;
    state.isPlayButtonTransitioning = transitioning;
  }

  handlePlayButtonTouch(state: PlaybackState, event: TouchEvent): void {
    state.playButtonScale = event.type === TouchType.Down ? 0.92 : 1;
  }

  handleNextButtonTouch(state: PlaybackState, event: TouchEvent): void {
    state.nextButtonScale = event.type === TouchType.Down ? 0.92 : 1;
  }

  handleMiniSeekChange(state: PlaybackState, value: number, mode: SliderChangeMode, durationMs: number): void {
    let targetMs = this.clampSeekMs(value, durationMs);
    if (mode === SliderChangeMode.Begin) {
      state.isSeekingPlayback = true;
      state.seekPreviewMs = targetMs;
      return;
    }
    if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click) {
      state.isSeekingPlayback = true;
      state.seekPreviewMs = targetMs;
      return;
    }
    if (mode === SliderChangeMode.End) {
      state.seekPreviewMs = targetMs;
      state.isSeekingPlayback = false;
      void this.seekCurrentTrack(state, targetMs);
    }
  }

  displayedPlaybackProgressMs(state: PlaybackState): number {
    return state.isSeekingPlayback ? state.seekPreviewMs : state.playbackProgressMs;
  }

  async seekCurrentTrack(state: PlaybackState, targetMs: number): Promise<void> {
    if (!this.player || state.playbackDurationMs <= 0) {
      return;
    }
    let playerState = this.player.state;
    if (playerState !== 'prepared' && playerState !== 'playing' && playerState !== 'paused' && playerState !== 'completed') {
      return;
    }
    let clampedTargetMs = this.clampSeekMs(targetMs, state.playbackDurationMs);
    try {
      state.playbackProgressMs = clampedTargetMs;
      this.lastProgressSnapshotMs = clampedTargetMs;
      this.player.seek(clampedTargetMs);
      if (this.onProgressUpdated) {
        this.onProgressUpdated(clampedTargetMs, state.playbackDurationMs);
      }
    } catch (error) {
      console.error(`seek failed: ${JSON.stringify(error)}`);
      this.showToast(t('playback.seek_fail'));
    }
  }

  startDiscRotation(state: PlaybackState): void {
    if (this.discRotationTimer >= 0) {
      return;
    }
    this.discRotationTimer = setInterval(() => {
      state.discRotationAngle += 2;
    }, 30) as number;
  }

  stopDiscRotation(state: PlaybackState): void {
    if (this.discRotationTimer < 0) {
      return;
    }
    clearInterval(this.discRotationTimer);
    this.discRotationTimer = -1;
  }

  async startTrackPlayback(
    state: PlaybackState,
    track: MusicTrack,
    localTracks: Array<MusicTrack>,
    resumePositionMs: number = 0,
    countAsPlay: boolean = true
  ): Promise<boolean> {
    let launchToken = ++this.playbackLaunchToken;
    let sessionId = this.playerSession + 1;
    this.playerSession = sessionId;
    this.resetAudioInterruptState();
    state.currentTrackId = track.id;
    state.playbackProgressMs = 0;
    state.playbackDurationMs = 0;
    state.isSeekingPlayback = false;
    state.seekPreviewMs = 0;
    this.lastProgressSnapshotMs = 0;
    this.setMiniPlayButtonState(state, true, true);

    if (this.onTrackSwitched) {
      this.onTrackSwitched(track.id);
    }

    await this.releasePlayer(state);
    if (!this.isPlaybackLaunchCurrent(launchToken, sessionId)) {
      return false;
    }
    this.autoPlayAfterPrepare = true;
    this.pendingStartSeekMs = this.clampSeekMs(resumePositionMs, state.playbackDurationMs);
    this.setMiniPlayButtonState(state, true, true);

    try {
      let player = await media.createAVPlayer();
      if (!this.isPlaybackLaunchCurrent(launchToken, sessionId)) {
        await player.release();
        return false;
      }
      this.player = player;
      state.loadedTrackId = track.id;
      this.registerPlayerCallbacks(player, sessionId, state);
      if (this.onPlaybackStateChanged) {
        this.onPlaybackStateChanged(false);
      }
      await this.attachTrackSource(player, track);
      if (!this.isPlaybackLaunchCurrent(launchToken, sessionId)) {
        await player.release();
        return false;
      }
      if (countAsPlay) {
        this.markTrackPlayed(track.id, localTracks);
      }
      return true;
    } catch (error) {
      console.error(`start playback failed: ${JSON.stringify(error)}`);
      if (this.isPlaybackLaunchCurrent(launchToken, sessionId)) {
        await this.releasePlayer(state);
        this.setMiniPlayButtonState(state, false, false);
        this.showToast(t('playback.cannot_play'));
        if (this.onPlaybackError) {
          this.onPlaybackError('start playback failed');
        }
      }
      return false;
    }
  }

  async restartTrackPlayerAfterInterrupt(
    state: PlaybackState,
    track: MusicTrack,
    resumePositionMs: number
  ): Promise<boolean> {
    let launchToken = ++this.playbackLaunchToken;
    let sessionId = this.playerSession + 1;
    this.playerSession = sessionId;
    this.resetAudioInterruptState();
    state.currentTrackId = track.id;
    state.playbackProgressMs = this.clampSeekMs(resumePositionMs, state.playbackDurationMs);
    state.playbackDurationMs = 0;
    state.isSeekingPlayback = false;
    state.seekPreviewMs = 0;
    this.lastProgressSnapshotMs = state.playbackProgressMs;
    this.setMiniPlayButtonState(state, true, true);

    await this.releasePlayer(state);
    if (!this.isPlaybackLaunchCurrent(launchToken, sessionId)) {
      return false;
    }
    this.autoPlayAfterPrepare = true;
    this.pendingStartSeekMs = this.clampSeekMs(resumePositionMs, state.playbackDurationMs);
    this.setMiniPlayButtonState(state, true, true);

    try {
      let player = await media.createAVPlayer();
      if (!this.isPlaybackLaunchCurrent(launchToken, sessionId)) {
        await player.release();
        return false;
      }
      this.player = player;
      state.loadedTrackId = track.id;
      this.registerPlayerCallbacks(player, sessionId, state);
      if (this.onPlaybackStateChanged) {
        this.onPlaybackStateChanged(false);
      }
      await this.attachTrackSource(player, track);
      if (!this.isPlaybackLaunchCurrent(launchToken, sessionId)) {
        await player.release();
        return false;
      }
      return true;
    } catch (error) {
      console.error(`restart interrupt playback failed: ${JSON.stringify(error)}`);
      if (this.isPlaybackLaunchCurrent(launchToken, sessionId)) {
        await this.releasePlayer(state);
        this.setMiniPlayButtonState(state, false, false);
        this.showToast(t('playback.resume_fail'));
      }
      return false;
    }
  }

  private isPlaybackLaunchCurrent(token: number, sessionId: number): boolean {
    return token === this.playbackLaunchToken && sessionId === this.playerSession;
  }

  private async attachTrackSource(player: media.AVPlayer, track: MusicTrack): Promise<void> {
    try {
      if (track.rawFileName.length > 0) {
        let context = this.context();
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
        return;
      } catch (fdError) {
        if (!this.canUseSandboxUri(track, playablePath)) {
          throw new Error(`open track file failed: ${String(fdError)}`);
        }
        let sandboxUri = fileUri.getUriFromPath(playablePath);
        player.url = sandboxUri;
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
    let context = this.context();
    return playablePath.startsWith(context.filesDir);
  }

  private registerPlayerCallbacks(player: media.AVPlayer, sessionId: number, state: PlaybackState): void {
    player.on('stateChange', async (playerState: string) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      if (playerState === 'initialized') {
        try {
          await player.prepare();
        } catch (error) {
          console.error(`prepare failed: ${JSON.stringify(error)}`);
          this.showToast(t('playback.prepare_fail'));
        }
      } else if (playerState === 'prepared') {
        state.playbackDurationMs = player.duration > 0 ? player.duration : state.playbackDurationMs;
        if (this.onDurationCached) {
          this.onDurationCached(state.loadedTrackId, state.playbackDurationMs);
        }
        if (this.pendingStartSeekMs > 0) {
          let resumeAtMs = this.clampSeekMs(this.pendingStartSeekMs, state.playbackDurationMs);
          this.pendingStartSeekMs = 0;
          state.playbackProgressMs = resumeAtMs;
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
            this.showToast(t('playback.start_fail'));
          }
        }
      } else if (playerState === 'playing') {
        this.resetAudioInterruptState();
        state.isPlaying = true;
        this.setMiniPlayButtonState(state, true, false);
        if (this.currentPlaybackRecordTrackId.length === 0) {
          this.beginPlaybackRecord(state.loadedTrackId);
        }
        this.startDiscRotation(state);
        if (this.onPlaybackStateChanged) {
          this.onPlaybackStateChanged(true);
        }
      } else if (playerState === 'paused') {
        state.isPlaying = false;
        this.setMiniPlayButtonState(state, false, false);
        this.stopDiscRotation(state);
        void this.flushCurrentPlaybackRecord();
        if (this.onPlaybackStateChanged) {
          this.onPlaybackStateChanged(false);
        }
      } else if (playerState === 'completed') {
        state.isPlaying = false;
        this.setMiniPlayButtonState(state, false, false);
        this.stopDiscRotation(state);
        state.playbackProgressMs = state.playbackDurationMs;
        void this.flushCurrentPlaybackRecord();
        if (this.onPlaybackCompleted) {
          this.onPlaybackCompleted();
        }
      } else if (playerState === 'released') {
        state.isPlaying = false;
        this.setMiniPlayButtonState(state, false, false);
        this.stopDiscRotation(state);
        void this.flushCurrentPlaybackRecord();
        if (this.isAudioInterrupted || this.shouldResumeAfterInterrupt) {
          this.playerReleasedDuringInterrupt = true;
          if (this.onPlaybackStateChanged) {
            this.onPlaybackStateChanged(false);
          }
          return;
        }
        if (this.onPlaybackError) {
          this.onPlaybackError('released');
        }
      } else if (playerState === 'error') {
        state.isPlaying = false;
        this.setMiniPlayButtonState(state, false, false);
        this.stopDiscRotation(state);
        void this.flushCurrentPlaybackRecord();
        if (this.isAudioInterrupted || this.shouldResumeAfterInterrupt) {
          this.playerReleasedDuringInterrupt = true;
          if (this.onPlaybackStateChanged) {
            this.onPlaybackStateChanged(false);
          }
          return;
        }
        this.showToast(t('playback.error'));
      }
    });

    player.on('timeUpdate', (time: number) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      if (time >= this.lastProgressSnapshotMs && time - this.lastProgressSnapshotMs < 5000) {
        let listenedDelta = time - this.lastProgressSnapshotMs;
        this.currentPlaybackRecordMs += listenedDelta;
      }
      this.lastProgressSnapshotMs = time;
      state.playbackProgressMs = time;
      if (this.onProgressUpdated) {
        this.onProgressUpdated(time, state.playbackDurationMs);
      }
    });

    player.on('seekDone', (time: number) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      let actualTime = player.currentTime >= 0 ? player.currentTime : time;
      state.playbackProgressMs = actualTime;
      this.lastProgressSnapshotMs = actualTime;
      if (this.onProgressUpdated) {
        this.onProgressUpdated(actualTime, state.playbackDurationMs);
      }
    });

    player.on('durationUpdate', (duration: number) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      state.playbackDurationMs = duration;
      if (this.onDurationCached) {
        this.onDurationCached(state.loadedTrackId, duration);
      }
    });

    player.on('audioInterrupt', (interruptEvent: audio.InterruptEvent) => {
      this.handlePlayerAudioInterrupt(interruptEvent, sessionId, state);
    });

    player.on('error', (error: BusinessError) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      if (this.isAudioInterrupted || this.shouldResumeAfterInterrupt || this.playerReleasedDuringInterrupt) {
        return;
      }
      console.error(`player error: ${error.code}, ${error.message}`);
      this.showToast(t('playback.unsupported_format'));
    });
  }

  private markTrackPlayed(trackId: string, localTracks: Array<MusicTrack>): void {
    let trackIndex = localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (trackIndex < 0) {
      return;
    }
    this.schedulePersist();
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

  private handlePlayerAudioInterrupt(interruptEvent: audio.InterruptEvent, sessionId: number, state: PlaybackState): void {
    if (sessionId !== this.playerSession) {
      return;
    }
    if (interruptEvent.eventType === audio.InterruptType.INTERRUPT_TYPE_BEGIN) {
      this.isAudioInterrupted = true;
      this.playerReleasedDuringInterrupt = false;
      let wasPlaying = (this.player?.state === 'playing') || state.isPlaying || this.autoPlayAfterPrepare;
      if (wasPlaying) {
        this.shouldResumeAfterInterrupt = true;
        this.interruptedTrackId = state.loadedTrackId.length > 0 ? state.loadedTrackId : state.currentTrackId;
        this.interruptedProgressMs = state.playbackProgressMs;
      }
      if (this.shouldPauseForAudioInterrupt(interruptEvent)) {
        if (this.player && this.player.state === 'playing') {
          void this.pauseCurrentTrack(state);
        } else {
          state.isPlaying = false;
          this.setMiniPlayButtonState(state, false, false);
          this.stopDiscRotation(state);
          if (this.onPlaybackStateChanged) {
            this.onPlaybackStateChanged(false);
          }
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
      void this.resumeAfterAudioInterrupt(state);
    }
  }

  private async resumeAfterAudioInterrupt(state: PlaybackState): Promise<void> {
    let resumeTrackId = this.interruptedTrackId.length > 0 ? this.interruptedTrackId : state.loadedTrackId;
    let resumeProgressMs = this.interruptedProgressMs;
    this.shouldResumeAfterInterrupt = false;
    this.interruptedTrackId = '';
    this.interruptedProgressMs = 0;
    if (resumeTrackId.length === 0) {
      this.playerReleasedDuringInterrupt = false;
      return;
    }
    this.playerReleasedDuringInterrupt = false;
    // The actual resume logic needs localTracks from Index
    if (this.onPlaybackStateChanged) {
      this.onPlaybackStateChanged(false);
    }
  }

  async pauseCurrentTrack(state: PlaybackState): Promise<void> {
    if (!this.player) {
      return;
    }
    this.setMiniPlayButtonState(state, false, true);
    try {
      await this.player.pause();
      state.isPlaying = false;
      this.setMiniPlayButtonState(state, false, false);
    } catch (error) {
      console.error(`pause failed: ${JSON.stringify(error)}`);
      this.setMiniPlayButtonState(state, true, false);
    }
  }

  async resumeCurrentTrack(state: PlaybackState): Promise<void> {
    if (!this.player) {
      return;
    }
    this.setMiniPlayButtonState(state, true, true);
    try {
      await this.player.play();
      state.isPlaying = true;
      this.setMiniPlayButtonState(state, true, false);
    } catch (error) {
      console.error(`resume failed: ${JSON.stringify(error)}`);
      this.setMiniPlayButtonState(state, false, false);
    }
  }

  async releasePlayer(state: PlaybackState): Promise<void> {
    void this.flushCurrentPlaybackRecord();
    this.resetAudioInterruptState();
    let existingPlayer = this.player;
    let existingFile = this.openedFile;
    let existingRawFileName = this.openedRawFileName;
    this.player = null;
    this.openedFile = null;
    this.openedRawFileName = '';
    state.loadedTrackId = '';
    state.isPlaying = false;
    state.isSeekingPlayback = false;
    state.seekPreviewMs = 0;
    this.setMiniPlayButtonState(state, false, false);
    this.autoPlayAfterPrepare = false;
    this.pendingStartSeekMs = 0;
    this.lastProgressSnapshotMs = 0;
    this.stopDiscRotation(state);
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
        let context = this.context();
        context.resourceManager.closeRawFdSync(existingRawFileName);
      } catch (error) {
        console.error(`close raw file failed: ${JSON.stringify(error)}`);
      }
    }
  }

  private beginPlaybackRecord(trackId: string): void {
    if (trackId.length === 0) {
      return;
    }
    this.currentPlaybackRecordTrackId = trackId;
    this.currentPlaybackRecordStartedAt = Date.now();
    this.currentPlaybackRecordMs = 0;
    if (this.onPlaybackRecordBegin) {
      this.onPlaybackRecordBegin(trackId);
    }
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

    if (this.onPlaybackRecordFlush) {
      this.onPlaybackRecordFlush(trackId, startedAt, listenedMs);
    }
  }

  getInterruptedTrackId(): string {
    return this.interruptedTrackId;
  }

  getInterruptedProgressMs(): number {
    return this.interruptedProgressMs;
  }

  isPlayerForTrack(state: PlaybackState, trackId: string): boolean {
    return state.loadedTrackId === trackId;
  }

  isPlayerPaused(): boolean {
    return this.player?.state === 'paused';
  }

  getLoadedTrackId(state: PlaybackState): string {
    return state.loadedTrackId;
  }

  dispose(state: PlaybackState): void {
    this.stopDiscRotation(state);
    if (this.player) {
      try {
        void this.player.release();
      } catch (_) {}
      this.player = null;
    }
  }
}
