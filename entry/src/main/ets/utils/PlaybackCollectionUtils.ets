import { DEFAULT_PLAYBACK_COLLECTION_ID } from '../constants/AppConstants';
import {
  CustomPlaylist,
  MusicTrack,
  PlaybackCollectionKind,
  PlaybackCollectionSummary
} from '../models/AppModels';

const UNTITLED_ALBUM_NAME: string = '未命名专辑';
const UNKNOWN_ARTIST_NAME: string = '未知歌手';
export const FAVORITES_PLAYBACK_COLLECTION_ID: string = 'builtin:favorites';

interface GroupedCollectionItem {
  key: string;
  count: number;
}

function buildCollectionSummary(
  id: string,
  title: string,
  subtitle: string,
  trackCount: number,
  kind: PlaybackCollectionKind
): PlaybackCollectionSummary {
  let summary: PlaybackCollectionSummary = {
    id: id,
    title: title,
    subtitle: subtitle,
    trackCount: trackCount,
    kind: kind
  };
  return summary;
}

function normalizedAlbumTitle(track: MusicTrack): string {
  let album = track.album.trim();
  return album.length > 0 ? album : UNTITLED_ALBUM_NAME;
}

function normalizedArtistTitle(track: MusicTrack): string {
  let artist = track.artist.trim();
  return artist.length > 0 ? artist : UNKNOWN_ARTIST_NAME;
}

function groupedCollectionSummaries(
  tracks: MusicTrack[],
  kind: PlaybackCollectionKind
): PlaybackCollectionSummary[] {
  let grouped: GroupedCollectionItem[] = [];
  let groupedIndexMap: Map<string, number> = new Map();
  tracks.forEach((track: MusicTrack) => {
    let key = kind === PlaybackCollectionKind.Album ? normalizedAlbumTitle(track) : normalizedArtistTitle(track);
    let index = groupedIndexMap.get(key);
    if (index === undefined) {
      groupedIndexMap.set(key, grouped.length);
      let groupedItem: GroupedCollectionItem = {
        key: key,
        count: 1
      };
      grouped.push(groupedItem);
      return;
    }
    grouped[index].count += 1;
  });

  return grouped.map((item: GroupedCollectionItem) => {
    return buildCollectionSummary(
      kind === PlaybackCollectionKind.Album ? buildAlbumPlaybackCollectionId(item.key) : buildArtistPlaybackCollectionId(item.key),
      item.key,
      `${item.count} 首`,
      item.count,
      kind
    );
  });
}

export function buildAlbumPlaybackCollectionId(albumTitle: string): string {
  return `album:${albumTitle}`;
}

export function buildArtistPlaybackCollectionId(artistName: string): string {
  return `artist:${artistName}`;
}

export function buildCustomPlaybackCollectionId(playlistId: string): string {
  return `custom:${playlistId}`;
}

export function customPlaylistIdFromCollectionId(collectionId: string): string {
  return collectionId.startsWith('custom:') ? collectionId.substring('custom:'.length) : '';
}

export function isCustomPlaybackCollectionId(collectionId: string): boolean {
  return customPlaylistIdFromCollectionId(collectionId).length > 0;
}

export function allPlaybackTracks(localTracks: MusicTrack[]): MusicTrack[] {
  return localTracks.filter((track: MusicTrack) => track.inPlayQueue !== false);
}

export function allPlaybackCollectionSummary(localTracks: MusicTrack[]): PlaybackCollectionSummary {
  let tracks = allPlaybackTracks(localTracks);
  return buildCollectionSummary(
    DEFAULT_PLAYBACK_COLLECTION_ID,
    '全部音乐',
    `${tracks.length} 首`,
    tracks.length,
    PlaybackCollectionKind.All
  );
}

export function favoritePlaybackTracks(localTracks: MusicTrack[]): MusicTrack[] {
  return localTracks.filter((track: MusicTrack) => track.isFavorite);
}

export function favoritePlaybackCollectionSummary(localTracks: MusicTrack[]): PlaybackCollectionSummary {
  let tracks = favoritePlaybackTracks(localTracks);
  return buildCollectionSummary(
    FAVORITES_PLAYBACK_COLLECTION_ID,
    '收藏',
    `${tracks.length} 首`,
    tracks.length,
    PlaybackCollectionKind.Favorites
  );
}

export function albumPlaybackCollectionSummaries(localTracks: MusicTrack[]): PlaybackCollectionSummary[] {
  return groupedCollectionSummaries(allPlaybackTracks(localTracks), PlaybackCollectionKind.Album);
}

export function artistPlaybackCollectionSummaries(localTracks: MusicTrack[]): PlaybackCollectionSummary[] {
  return groupedCollectionSummaries(allPlaybackTracks(localTracks), PlaybackCollectionKind.Artist);
}

export function customPlaybackCollectionSummaries(
  customPlaylists: CustomPlaylist[],
  localTracks: MusicTrack[]
): PlaybackCollectionSummary[] {
  return customPlaylists.map((playlist: CustomPlaylist) => {
    let count = playbackCollectionTracks(localTracks, customPlaylists, buildCustomPlaybackCollectionId(playlist.id)).length;
    return buildCollectionSummary(
      buildCustomPlaybackCollectionId(playlist.id),
      playlist.name,
      `${count} 首`,
      count,
      PlaybackCollectionKind.Custom
    );
  });
}

export function playbackCollectionSelectorSummaries(
  localTracks: MusicTrack[],
  customPlaylists: CustomPlaylist[]
): PlaybackCollectionSummary[] {
  let summaries: PlaybackCollectionSummary[] = [];
  let allSummary = allPlaybackCollectionSummary(localTracks);
  if (allSummary.trackCount > 0) {
    summaries.push(allSummary);
  }

  let favoriteSummary = favoritePlaybackCollectionSummary(localTracks);
  if (favoriteSummary.trackCount > 0) {
    summaries.push(favoriteSummary);
  }

  summaries = summaries
    .concat(albumPlaybackCollectionSummaries(localTracks))
    .concat(artistPlaybackCollectionSummaries(localTracks))
    .concat(customPlaybackCollectionSummaries(customPlaylists, localTracks)
      .filter((summary: PlaybackCollectionSummary) => summary.trackCount > 0));

  return summaries;
}

export function playbackCollectionKindLabel(kind: PlaybackCollectionKind): string {
  if (kind === PlaybackCollectionKind.All) {
    return '全部';
  }
  if (kind === PlaybackCollectionKind.Favorites) {
    return '收藏';
  }
  if (kind === PlaybackCollectionKind.Album) {
    return '专辑';
  }
  if (kind === PlaybackCollectionKind.Artist) {
    return '歌手';
  }
  return '自定义';
}

export function playbackCollectionTracks(
  localTracks: MusicTrack[],
  customPlaylists: CustomPlaylist[],
  collectionId: string
): MusicTrack[] {
  let queueTracks = allPlaybackTracks(localTracks);
  if (collectionId.length === 0 || collectionId === DEFAULT_PLAYBACK_COLLECTION_ID) {
    return queueTracks;
  }

  if (collectionId === FAVORITES_PLAYBACK_COLLECTION_ID) {
    return favoritePlaybackTracks(localTracks);
  }

  if (collectionId.startsWith('album:')) {
    let targetAlbum = collectionId.substring('album:'.length);
    return queueTracks.filter((track: MusicTrack) => normalizedAlbumTitle(track) === targetAlbum);
  }

  if (collectionId.startsWith('artist:')) {
    let targetArtist = collectionId.substring('artist:'.length);
    return queueTracks.filter((track: MusicTrack) => normalizedArtistTitle(track) === targetArtist);
  }

  if (collectionId.startsWith('custom:')) {
    let playlistId = customPlaylistIdFromCollectionId(collectionId);
    let playlist = customPlaylists.find((item: CustomPlaylist) => item.id === playlistId);
    if (!playlist) {
      return [];
    }
    let playlistTrackIds = playlist.trackIds.slice();
    return localTracks.filter((track: MusicTrack) => playlistTrackIds.indexOf(track.id) >= 0);
  }

  return queueTracks;
}

export function playbackCollectionSummaryById(
  localTracks: MusicTrack[],
  customPlaylists: CustomPlaylist[],
  collectionId: string
): PlaybackCollectionSummary {
  if (collectionId.length === 0 || collectionId === DEFAULT_PLAYBACK_COLLECTION_ID) {
    return allPlaybackCollectionSummary(localTracks);
  }
  if (collectionId === FAVORITES_PLAYBACK_COLLECTION_ID) {
    return favoritePlaybackCollectionSummary(localTracks);
  }

  let summaries = [favoritePlaybackCollectionSummary(localTracks)]
    .concat(albumPlaybackCollectionSummaries(localTracks))
    .concat(artistPlaybackCollectionSummaries(localTracks))
    .concat(customPlaybackCollectionSummaries(customPlaylists, localTracks));
  let matched = summaries.find((item: PlaybackCollectionSummary) => item.id === collectionId);
  return matched ?? allPlaybackCollectionSummary(localTracks);
}

export function playbackCollectionExists(
  localTracks: MusicTrack[],
  customPlaylists: CustomPlaylist[],
  collectionId: string
): boolean {
  if (collectionId.length === 0 || collectionId === DEFAULT_PLAYBACK_COLLECTION_ID ||
    collectionId === FAVORITES_PLAYBACK_COLLECTION_ID) {
    return true;
  }
  return playbackCollectionSummaryById(localTracks, customPlaylists, collectionId).id === collectionId;
}

export function trackBelongsToPlaybackCollection(
  trackId: string,
  localTracks: MusicTrack[],
  customPlaylists: CustomPlaylist[],
  collectionId: string
): boolean {
  return playbackCollectionTracks(localTracks, customPlaylists, collectionId)
    .some((track: MusicTrack) => track.id === trackId);
}
