import { CustomPlaylist } from '../models/AppModels';

export interface CreateCustomPlaylistResult {
  playlists: CustomPlaylist[];
  createdPlaylistId: string;
}

export interface RemoveCustomPlaylistResult {
  playlists: CustomPlaylist[];
  removed: boolean;
}

export interface ToggleCustomPlaylistTrackResult {
  playlists: CustomPlaylist[];
  included: boolean;
}

function clonePlaylist(playlist: CustomPlaylist, trackIds: string[]): CustomPlaylist {
  let nextPlaylist: CustomPlaylist = {
    id: playlist.id,
    name: playlist.name,
    trackIds: trackIds
  };
  return nextPlaylist;
}

function normalizedPlaylistName(name: string): string {
  return name.trim();
}

function uniqueTrackIds(trackIds: string[]): string[] {
  let nextTrackIds: string[] = [];
  trackIds.forEach((trackId: string) => {
    let normalizedTrackId = trackId.trim();
    if (normalizedTrackId.length === 0 || nextTrackIds.indexOf(normalizedTrackId) >= 0) {
      return;
    }
    nextTrackIds.push(normalizedTrackId);
  });
  return nextTrackIds;
}

export function normalizeCustomPlaylists(playlists: CustomPlaylist[]): CustomPlaylist[] {
  let normalized: CustomPlaylist[] = [];
  playlists.forEach((playlist: CustomPlaylist) => {
    if (!playlist || typeof playlist.id !== 'string' || playlist.id.length === 0) {
      return;
    }
    let name = normalizedPlaylistName(playlist.name);
    if (name.length === 0) {
      return;
    }
    if (normalized.some((item: CustomPlaylist) => item.id === playlist.id)) {
      return;
    }
    normalized.push({
      id: playlist.id,
      name: name,
      trackIds: uniqueTrackIds(Array.isArray(playlist.trackIds) ? playlist.trackIds : [])
    });
  });
  return normalized;
}

export function createCustomPlaylist(
  playlists: CustomPlaylist[],
  name: string
): CreateCustomPlaylistResult {
  let normalizedName = normalizedPlaylistName(name);
  if (normalizedName.length === 0) {
    return {
      playlists: playlists,
      createdPlaylistId: ''
    };
  }
  let nextId = `playlist_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  let createdPlaylist: CustomPlaylist = {
    id: nextId,
    name: normalizedName,
    trackIds: []
  };
  return {
    playlists: playlists.concat([createdPlaylist]),
    createdPlaylistId: nextId
  };
}

export function removeCustomPlaylist(playlists: CustomPlaylist[], playlistId: string): RemoveCustomPlaylistResult {
  let nextPlaylists = playlists.filter((playlist: CustomPlaylist) => playlist.id !== playlistId);
  return {
    playlists: nextPlaylists,
    removed: nextPlaylists.length !== playlists.length
  };
}

export function toggleTrackInCustomPlaylist(
  playlists: CustomPlaylist[],
  playlistId: string,
  trackId: string
): ToggleCustomPlaylistTrackResult {
  let included = false;
  let nextPlaylists = playlists.map((playlist: CustomPlaylist) => {
    if (playlist.id !== playlistId) {
      return playlist;
    }
    let nextTrackIds = uniqueTrackIds(playlist.trackIds);
    let existingIndex = nextTrackIds.indexOf(trackId);
    if (existingIndex >= 0) {
      nextTrackIds.splice(existingIndex, 1);
      included = false;
    } else {
      nextTrackIds.push(trackId);
      included = true;
    }
    return clonePlaylist(playlist, nextTrackIds);
  });
  return {
    playlists: nextPlaylists,
    included: included
  };
}

export function removeTracksFromCustomPlaylists(playlists: CustomPlaylist[], trackIds: string[]): CustomPlaylist[] {
  if (trackIds.length === 0) {
    return playlists;
  }
  let uniqueIds = uniqueTrackIds(trackIds);
  return playlists.map((playlist: CustomPlaylist) => {
    return clonePlaylist(
      playlist,
      playlist.trackIds.filter((trackId: string) => uniqueIds.indexOf(trackId) < 0)
    );
  });
}
