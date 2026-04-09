import { MINI_PLACEHOLDER_TRACK } from '../constants/AppConstants';
import { CollectionMode, MusicTrack } from '../models/AppModels';

export function totalListeningHours(totalListeningMs: number): number {
  return Math.floor(totalListeningMs / (60 * 60 * 1000));
}

export function onlineDownloadFailureToast(error: Object): string {
  let errorText = JSON.stringify(error);
  if (errorText.indexOf('http status 401') >= 0 || errorText.indexOf('http status 403') >= 0) {
    return '下载失败，链接可能已过期或需要鉴权';
  }
  if (errorText.indexOf('http status 404') >= 0) {
    return '下载失败，链接已失效或文件不存在';
  }
  if (errorText.indexOf('http status 429') >= 0) {
    return '下载失败，目标站点当前限制访问频率';
  }
  return '下载失败，请确认链接可直接访问音频文件';
}

export function librarySource(localTracks: MusicTrack[]): MusicTrack[] {
  return localTracks;
}

export function visibleTracks(
  localTracks: MusicTrack[],
  recentTrackIds: string[],
  collectionMode: CollectionMode,
  searchKeyword: string
): MusicTrack[] {
  let source = librarySource(localTracks);
  let filtered: MusicTrack[] = [];
  if (collectionMode === CollectionMode.Favorites) {
    source.forEach((track: MusicTrack) => {
      if (track.isFavorite) {
        filtered.push(track);
      }
    });
  } else if (collectionMode === CollectionMode.Recent) {
    recentTrackIds.forEach((trackId: string) => {
      let found = source.find((track: MusicTrack) => track.id === trackId);
      if (found) {
        filtered.push(found);
      }
    });
  } else {
    filtered = source.slice();
  }

  let keyword = searchKeyword.trim().toLowerCase();
  if (keyword.length === 0) {
    return filtered;
  }
  return filtered.filter((track: MusicTrack) => {
    let target = `${track.title} ${track.artist} ${track.album} ${track.folder}`.toLowerCase();
    return target.indexOf(keyword) >= 0;
  });
}

export function currentTrack(localTracks: MusicTrack[], currentTrackId: string): MusicTrack {
  let allTracks = librarySource(localTracks).concat([MINI_PLACEHOLDER_TRACK]);
  let found = allTracks.find((track: MusicTrack) => track.id === currentTrackId);
  return found ?? MINI_PLACEHOLDER_TRACK;
}

export function playbackProgressRatio(playbackProgressMs: number, playbackDurationMs: number): number {
  if (playbackDurationMs <= 0) {
    return 0.32;
  }
  let ratio = playbackProgressMs / playbackDurationMs;
  if (ratio < 0) {
    return 0;
  }
  if (ratio > 1) {
    return 1;
  }
  return ratio;
}
