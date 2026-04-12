import { common } from '@kit.AbilityKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { avSession } from '@kit.AVSessionKit';
import { WantAgent } from '@ohos.app.ability.wantAgent';
import wantAgent from '@ohos.app.ability.wantAgent';

import {
  LIVE_VIEW_ICON_FILE_NAME,
  LIVE_VIEW_ICON_FRAME_COUNT,
  LIVE_VIEW_ICON_FRAME_PREFIX
} from '../constants/AppConstants';
import { MusicTrack, PlaybackCollectionSummary, PlayMode } from '../models/AppModels';

export async function createPlaybackWantAgent(
  context: common.UIAbilityContext,
  bundleName: string,
  abilityName: string
): Promise<WantAgent> {
  let wantAgentInfo: wantAgent.WantAgentInfo = {
    wants: [
      {
        bundleName: bundleName,
        abilityName: abilityName
      }
    ],
    actionType: wantAgent.OperationType.START_ABILITY,
    requestCode: 0,
    actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
  };
  return await wantAgent.getWantAgent(wantAgentInfo);
}

export function createPlaybackLiveView(
  track: MusicTrack,
  clickAction: WantAgent,
  sequence: number,
  iconFileName: string = LIVE_VIEW_ICON_FILE_NAME,
  lyricText: string = '',
  secondaryLyricText: string = '',
  compactLayout: boolean = false
): liveViewManager.LiveView {
  return {
    id: 1,
    event: 'TIMER',
    sequence: sequence,
    liveViewData: {
      primary: buildPlaybackPrimaryData(track, clickAction, iconFileName, lyricText, secondaryLyricText, 0, compactLayout),
      capsule: buildPlaybackCapsule(track, iconFileName, lyricText, secondaryLyricText, compactLayout)
    }
  };
}

export function applyPlaybackLiveViewUpdate(
  liveView: liveViewManager.LiveView,
  track: MusicTrack,
  sequence: number,
  progress: number,
  playing: boolean,
  iconFileName: string = LIVE_VIEW_ICON_FILE_NAME,
  lyricText: string = '',
  secondaryLyricText: string = '',
  compactLayout: boolean = false
): liveViewManager.LiveView {
  liveView.sequence = sequence;
  let clickAction = liveView.liveViewData.primary.clickAction;
  liveView.liveViewData.primary = buildPlaybackPrimaryData(
    track,
    clickAction,
    iconFileName,
    lyricText,
    secondaryLyricText,
    progress,
    compactLayout
  );
  liveView.liveViewData.capsule = buildPlaybackCapsule(track, iconFileName, lyricText, secondaryLyricText, compactLayout);
  return liveView;
}

function buildPlaybackPrimaryData(
  track: MusicTrack,
  clickAction: WantAgent | undefined,
  iconFileName: string,
  lyricText: string,
  secondaryLyricText: string,
  progress: number,
  compactLayout: boolean
): liveViewManager.PrimaryData {
  let primary: liveViewManager.PrimaryData = {
    title: buildPlaybackLiveViewTitle(track, lyricText),
    content: buildPlaybackLiveViewContent(track, lyricText, secondaryLyricText),
    keepTime: 0,
    clickAction: clickAction
  };
  if (!compactLayout) {
    primary.layoutData = buildPlaybackProgressLayout(progress, iconFileName);
  }
  return primary;
}

function buildPlaybackCapsule(
  track: MusicTrack,
  iconFileName: string,
  lyricText: string,
  secondaryLyricText: string,
  compactLayout: boolean
): liveViewManager.TextCapsule {
  let capsule: liveViewManager.TextCapsule = {
    type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
    status: 1,
    title: buildPlaybackLiveViewTitle(track, lyricText),
    content: buildPlaybackLiveViewCapsuleContent(track, secondaryLyricText),
    backgroundColor: '#FF2A2928'
  };
  if (!compactLayout) {
    capsule.icon = iconFileName;
  }
  return capsule;
}

function buildPlaybackLiveViewTitle(track: MusicTrack, lyricText: string): string {
  let titleText = lyricText.trim();
  if (titleText.length > 0) {
    return titleText;
  }
  return track.title;
}

function buildPlaybackLiveViewContent(
  track: MusicTrack,
  lyricText: string,
  secondaryLyricText: string
): Array<liveViewManager.RichText> {
  let trackMeta = `${track.artist} - ${track.album}`;
  let primaryLyricText = lyricText.trim();
  if (primaryLyricText.length === 0) {
    return [
      createLiveViewRichText(trackMeta)
    ];
  }
  let secondaryText = secondaryLyricText.trim().length > 0 ? secondaryLyricText.trim() : trackMeta;
  return [
    createLiveViewRichText(track.title),
    createLiveViewRichText(secondaryText)
  ];
}

function buildPlaybackLiveViewCapsuleContent(track: MusicTrack, secondaryLyricText: string): string {
  let secondaryText = secondaryLyricText.trim();
  if (secondaryText.length > 0) {
    return secondaryText;
  }
  return `${track.artist} - ${track.album}`;
}

function buildPlaybackProgressLayout(progress: number, iconFileName: string): liveViewManager.ProgressLayout {
  let normalizedProgress = Math.max(0, Math.min(progress, 100));
  let layout: liveViewManager.ProgressLayout = {
    layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
    progress: normalizedProgress,
    color: '#FFF1F1F1',
    backgroundColor: '#FF444341',
    nodeIcons: [iconFileName]
  };
  return layout;
}

function createLiveViewRichText(text: string): liveViewManager.RichText {
  let richText: liveViewManager.RichText = {
    text: text
  };
  return richText;
}

export function applyStoppedLiveViewUpdate(
  liveView: liveViewManager.LiveView,
  sequence: number,
  iconFileName: string = LIVE_VIEW_ICON_FILE_NAME,
  compactLayout: boolean = false
): liveViewManager.LiveView {
  liveView.sequence = sequence;
  let clickAction = liveView.liveViewData.primary.clickAction;
  liveView.liveViewData.primary = {
    title: '播放结束',
    content: [createLiveViewRichText('可返回应用继续播放')],
    keepTime: 0,
    clickAction: clickAction
  };
  if (!compactLayout) {
    liveView.liveViewData.primary.layoutData = buildPlaybackProgressLayout(100, iconFileName);
  }
  let capsule: liveViewManager.TextCapsule = {
    type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
    status: 1,
    title: '播放结束',
    backgroundColor: '#FF2A2928'
  };
  if (!compactLayout) {
    capsule.icon = iconFileName;
  }
  liveView.liveViewData.capsule = capsule;
  return liveView;
}

export function resolveLiveViewIconFileName(playing: boolean, frameIndex: number): string {
  if (!playing) {
    return LIVE_VIEW_ICON_FILE_NAME;
  }
  let normalizedIndex = ((frameIndex % LIVE_VIEW_ICON_FRAME_COUNT) + LIVE_VIEW_ICON_FRAME_COUNT) % LIVE_VIEW_ICON_FRAME_COUNT;
  return `${LIVE_VIEW_ICON_FRAME_PREFIX}${normalizedIndex}.png`;
}

export function createSessionMetadata(
  track: MusicTrack,
  coverImageUri?: string,
  durationMs?: number,
  lyricContent?: string,
  previousAssetId?: string,
  nextAssetId?: string,
  singleLyricText?: string,
  subtitleText?: string,
  descriptionText?: string
): avSession.AVMetadata {
  let metadata: avSession.AVMetadata = {
    assetId: track.id,
    title: track.title,
    artist: track.artist,
    album: track.album
  };
  if (coverImageUri && coverImageUri.length > 0) {
    metadata.mediaImage = coverImageUri;
  }
  if (durationMs !== undefined && durationMs > 0) {
    metadata.duration = durationMs;
  }
  if (lyricContent && lyricContent.length > 0) {
    metadata.lyric = lyricContent;
  }
  if (singleLyricText && singleLyricText.length > 0) {
    metadata.singleLyricText = singleLyricText;
  }
  if (subtitleText && subtitleText.length > 0) {
    metadata.subtitle = subtitleText;
  }
  if (descriptionText && descriptionText.length > 0) {
    metadata.description = descriptionText;
  }
  if (previousAssetId && previousAssetId.length > 0) {
    metadata.previousAssetId = previousAssetId;
  }
  if (nextAssetId && nextAssetId.length > 0) {
    metadata.nextAssetId = nextAssetId;
  }
  return metadata;
}

export function playModeToLoopMode(playMode: PlayMode): avSession.LoopMode {
  if (playMode === PlayMode.Shuffle) {
    return avSession.LoopMode.LOOP_MODE_SHUFFLE;
  } else if (playMode === PlayMode.Loop) {
    return avSession.LoopMode.LOOP_MODE_SINGLE;
  }
  return avSession.LoopMode.LOOP_MODE_LIST;
}

export function loopModeToPlayMode(loopMode: avSession.LoopMode): PlayMode {
  if (loopMode === avSession.LoopMode.LOOP_MODE_SHUFFLE) {
    return PlayMode.Shuffle;
  } else if (loopMode === avSession.LoopMode.LOOP_MODE_SINGLE) {
    return PlayMode.Loop;
  }
  return PlayMode.Sequential;
}

export function createPlaybackState(
  playing: boolean,
  playbackProgressMs: number,
  playbackDurationMs: number,
  playMode: PlayMode = PlayMode.Sequential,
  isFavorite: boolean = false
): avSession.AVPlaybackState {
  return {
    state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
    position: {
      elapsedTime: playbackProgressMs,
      updateTime: Date.now()
    },
    duration: playbackDurationMs,
    loopMode: playModeToLoopMode(playMode),
    isFavorite: isFavorite
  };
}

function queueSubtitle(summary: PlaybackCollectionSummary, activeCollectionId: string): string {
  let status = summary.id === activeCollectionId ? '当前播放' : '可切换';
  return `${status} · ${summary.subtitle}`;
}

export function buildPlaybackCollectionQueueItems(
  collections: PlaybackCollectionSummary[],
  activeCollectionId: string
): avSession.AVQueueItem[] {
  return collections.map((summary: PlaybackCollectionSummary, index: number) => {
    let description: avSession.AVMediaDescription = {
      assetId: summary.id,
      title: summary.title,
      subtitle: queueSubtitle(summary, activeCollectionId),
      description: summary.title
    };
    let item: avSession.AVQueueItem = {
      itemId: index + 1,
      description: description
    };
    return item;
  });
}

export function buildPlaybackCollectionQueueTitle(): string {
  return '选择播放列表';
}

export function buildTrackQueueItems(tracks: MusicTrack[]): avSession.AVQueueItem[] {
  return tracks.map((track: MusicTrack, index: number) => {
    let description: avSession.AVMediaDescription = {
      assetId: track.id,
      title: track.title,
      subtitle: track.artist,
      description: track.album
    };
    let item: avSession.AVQueueItem = {
      itemId: index + 1,
      description: description
    };
    return item;
  });
}

export async function startAudioBackgroundTask(
  context: common.UIAbilityContext,
  clickAction: WantAgent
): Promise<backgroundTaskManager.ContinuousTaskNotification> {
  let bgModes: string[] = ['audioPlayback'];
  return await backgroundTaskManager.startBackgroundRunning(context, bgModes, clickAction);
}

export async function stopAudioBackgroundTask(context: common.UIAbilityContext): Promise<void> {
  await backgroundTaskManager.stopBackgroundRunning(context);
}
