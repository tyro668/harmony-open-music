import { MINI_PLACEHOLDER_TRACK } from '../constants/AppConstants';
import { CollectionMode, MusicTrack } from '../models/AppModels';
import { t } from './I18nUtil';

export function totalListeningHours(totalListeningMs: number): number {
  return Math.round((totalListeningMs / (60 * 60 * 1000)) * 10) / 10;
}

export function totalListeningSummaryText(totalListeningMs: number): string {
  if (totalListeningMs <= 0) {
    return t('profile.listening_hours', '0');
  }
  if (totalListeningMs < 60 * 60 * 1000) {
    let minutes = Math.max(1, Math.round(totalListeningMs / (60 * 1000)));
    return t('profile.listening_minutes', `${minutes}`);
  }
  let totalHours = totalListeningHours(totalListeningMs);
  let displayHours = Number.isInteger(totalHours) ? `${totalHours}` : totalHours.toFixed(1);
  return t('profile.listening_hours', displayHours);
}

export function librarySource(localTracks: MusicTrack[]): MusicTrack[] {
  return localTracks.filter((track: MusicTrack) => track.inPlayQueue !== false);
}

export function playQueueTracks(localTracks: MusicTrack[]): MusicTrack[] {
  return librarySource(localTracks);
}

export function visibleTracks(
  localTracks: MusicTrack[],
  recentTrackIds: string[],
  collectionMode: CollectionMode,
  searchKeyword: string
): MusicTrack[] {
  let source = collectionMode === CollectionMode.Library ? librarySource(localTracks) : localTracks;
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
  let allTracks = localTracks.concat([MINI_PLACEHOLDER_TRACK]);
  let found = allTracks.find((track: MusicTrack) => track.id === currentTrackId);
  return found ?? MINI_PLACEHOLDER_TRACK;
}

export function moveTrackByReference(
  tracks: MusicTrack[],
  trackId: string,
  referenceTrackId: string,
  placeAfter: boolean
): MusicTrack[] {
  if (trackId.length === 0 || referenceTrackId.length === 0 || trackId === referenceTrackId) {
    return tracks;
  }
  let sourceIndex = tracks.findIndex((track: MusicTrack) => track.id === trackId);
  let referenceIndex = tracks.findIndex((track: MusicTrack) => track.id === referenceTrackId);
  if (sourceIndex < 0 || referenceIndex < 0) {
    return tracks;
  }

  let nextTracks = tracks.slice();
  let movedTracks = nextTracks.splice(sourceIndex, 1);
  if (movedTracks.length === 0) {
    return tracks;
  }
  let movedTrack = movedTracks[0];
  let nextReferenceIndex = nextTracks.findIndex((track: MusicTrack) => track.id === referenceTrackId);
  if (nextReferenceIndex < 0) {
    return tracks;
  }
  let targetIndex = placeAfter ? nextReferenceIndex + 1 : nextReferenceIndex;
  nextTracks.splice(targetIndex, 0, movedTrack);
  return nextTracks;
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
