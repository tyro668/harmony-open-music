import { common } from '@kit.AbilityKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { avSession } from '@kit.AVSessionKit';
import { WantAgent } from '@ohos.app.ability.wantAgent';
import wantAgent from '@ohos.app.ability.wantAgent';

import { MusicTrack, PlaybackCollectionSummary } from '../models/AppModels';

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
  sequence: number
): liveViewManager.LiveView {
  return {
    id: 1,
    event: 'TIMER',
    sequence: sequence,
    liveViewData: {
      primary: {
        title: track.title,
        content: [{ text: `${track.artist} - ${track.album}` }],
        keepTime: 0,
        clickAction: clickAction,
        layoutData: {
          layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
          progress: 0,
          color: '#FFF1F1F1',
          backgroundColor: '#FF444341'
        }
      },
      capsule: {
        type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
        status: 1,
        title: track.title,
        icon: 'startIcon.png',
        backgroundColor: '#FF2A2928'
      }
    }
  };
}

export function applyPlaybackLiveViewUpdate(
  liveView: liveViewManager.LiveView,
  track: MusicTrack,
  sequence: number,
  progress: number,
  playing: boolean
): liveViewManager.LiveView {
  liveView.sequence = sequence;
  liveView.liveViewData.primary.title = track.title;
  liveView.liveViewData.primary.content = [{ text: `${track.artist} - ${track.album}` }];
  liveView.liveViewData.primary.layoutData = {
    layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
    progress: progress,
    color: '#FFF1F1F1',
    backgroundColor: '#FF444341'
  };
  liveView.liveViewData.capsule = {
    type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
    status: 1,
    title: playing ? '正在播放' : '已暂停',
    icon: 'startIcon.png',
    backgroundColor: '#FF2A2928'
  };
  return liveView;
}

export function applyStoppedLiveViewUpdate(
  liveView: liveViewManager.LiveView,
  sequence: number
): liveViewManager.LiveView {
  liveView.sequence = sequence;
  liveView.liveViewData.primary.layoutData = {
    layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
    progress: 100,
    color: '#FFF1F1F1',
    backgroundColor: '#FF444341'
  };
  liveView.liveViewData.capsule = {
    type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
    status: 1,
    title: '播放结束',
    icon: 'startIcon.png',
    backgroundColor: '#FF2A2928'
  };
  return liveView;
}

export function createSessionMetadata(track: MusicTrack): avSession.AVMetadata {
  return {
    assetId: track.id,
    title: track.title,
    artist: track.artist,
    album: track.album
  };
}

export function createPlaybackState(
  playing: boolean,
  playbackProgressMs: number,
  playbackDurationMs: number
): avSession.AVPlaybackState {
  return {
    state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
    position: {
      elapsedTime: playbackProgressMs,
      updateTime: Date.now()
    },
    duration: playbackDurationMs
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

export async function startAudioBackgroundTask(
  context: common.UIAbilityContext,
  clickAction: WantAgent
): Promise<void> {
  let bgModes: string[] = ['audioPlayback'];
  await backgroundTaskManager.startBackgroundRunning(context, bgModes, clickAction);
}

export async function stopAudioBackgroundTask(context: common.UIAbilityContext): Promise<void> {
  await backgroundTaskManager.stopBackgroundRunning(context);
}
