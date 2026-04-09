import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileShare } from '@kit.CoreFileKit';

import {
  LISTENING_SEED_MS,
  MAX_RECENT_TRACKS,
  MINI_PLACEHOLDER_TRACK,
  PREFERENCES_FILE_NAME,
  PREF_KEY_COLLECTION_MODE,
  PREF_KEY_CURRENT_TRACK_ID,
  PREF_KEY_LOCAL_TRACKS,
  PREF_KEY_MUSIC_SOURCES,
  PREF_KEY_MUSIC_SOURCE_SCRIPT_PREFIX,
  PREF_KEY_PLAY_MODE,
  PREF_KEY_RECENT_TRACK_IDS,
  PREF_KEY_TOTAL_LISTENING_MS
} from '../constants/AppConstants';
import {
  CollectionMode,
  MusicSourceConfig,
  MusicTrack,
  PersistedMusicSourceConfig,
  PlayMode
} from '../models/AppModels';
import { copyTrack } from '../utils/TrackUtils';
import { normalizeMusicSource } from '../utils/MusicSourceUtils';

const LEGACY_BUNDLED_TRACK_ID: string = 'bundled-track-netease-demo';
const LEGACY_BUNDLED_TRACK_FILE_NAME: string = 'netease_demo_import.mp3';

function isLegacyBundledTrack(track: MusicTrack): boolean {
  if (track.id === LEGACY_BUNDLED_TRACK_ID) {
    return true;
  }
  return track.rawFileName === LEGACY_BUNDLED_TRACK_FILE_NAME &&
    track.sourceUri.length === 0 &&
    track.filePath.length === 0;
}

export interface RestoredAppState {
  localTracks: MusicTrack[];
  recentTrackIds: string[];
  currentTrackId: string;
  collectionMode: CollectionMode;
  totalListeningMs: number;
  playMode: PlayMode;
  musicSources: MusicSourceConfig[];
  musicSourceScripts: Map<string, string>;
}

export interface PersistableAppState {
  localTracks: MusicTrack[];
  recentTrackIds: string[];
  currentTrackId: string;
  collectionMode: CollectionMode;
  totalListeningMs: number;
  playMode: PlayMode;
  musicSources: MusicSourceConfig[];
}

export async function ensureAppPreferences(
  existing: preferences.Preferences | null,
  context: common.UIAbilityContext
): Promise<preferences.Preferences> {
  if (existing !== null) {
    return existing;
  }
  return await preferences.getPreferences(context, { name: PREFERENCES_FILE_NAME });
}

export function getMusicSourceScriptPreferenceKey(sourceId: string): string {
  return `${PREF_KEY_MUSIC_SOURCE_SCRIPT_PREFIX}${sourceId}`;
}

export async function readMusicSourceScript(
  store: preferences.Preferences,
  cache: Map<string, string>,
  sourceId: string
): Promise<string> {
  if (cache.has(sourceId)) {
    return cache.get(sourceId) || '';
  }
  let scriptPayload = await store.get(getMusicSourceScriptPreferenceKey(sourceId), '');
  let script = typeof scriptPayload === 'string' ? scriptPayload : '';
  if (script.length > 0) {
    cache.set(sourceId, script);
  }
  return script;
}

export async function deleteMusicSourceScript(
  store: preferences.Preferences,
  cache: Map<string, string>,
  sourceId: string
): Promise<void> {
  cache.delete(sourceId);
  await store.delete(getMusicSourceScriptPreferenceKey(sourceId));
  await store.flush();
}

export async function restorePersistedAppState(store: preferences.Preferences): Promise<RestoredAppState> {
  let restored: RestoredAppState = {
    localTracks: [],
    recentTrackIds: [],
    currentTrackId: MINI_PLACEHOLDER_TRACK.id,
    collectionMode: CollectionMode.Library,
    totalListeningMs: LISTENING_SEED_MS,
    playMode: PlayMode.Sequential,
    musicSources: [],
    musicSourceScripts: new Map()
  };

  try {
    let trackPayload = await store.get(PREF_KEY_LOCAL_TRACKS, '[]');
    if (typeof trackPayload === 'string' && trackPayload.length > 0) {
      try {
        let parsedTracks = JSON.parse(trackPayload) as Array<MusicTrack>;
        restored.localTracks = parsedTracks
          .filter((track: MusicTrack) => !isLegacyBundledTrack(track))
          .map((track: MusicTrack) => copyTrack(track));
      } catch (error) {
        console.error(`restore local tracks failed: ${JSON.stringify(error)}`);
      }
    }
  } catch (error) {
    console.error(`read local tracks from preferences failed: ${JSON.stringify(error)}`);
  }

  try {
    let recentPayload = await store.get(PREF_KEY_RECENT_TRACK_IDS, '[]');
    if (typeof recentPayload === 'string' && recentPayload.length > 0) {
      try {
        let parsedRecent = JSON.parse(recentPayload) as Array<string>;
        restored.recentTrackIds = parsedRecent.slice(0, MAX_RECENT_TRACKS);
      } catch (error) {
        console.error(`restore recent tracks failed: ${JSON.stringify(error)}`);
      }
    }
  } catch (error) {
    console.error(`read recent tracks from preferences failed: ${JSON.stringify(error)}`);
  }

  try {
    let currentTrackPayload = await store.get(PREF_KEY_CURRENT_TRACK_ID, MINI_PLACEHOLDER_TRACK.id);
    if (typeof currentTrackPayload === 'string' && currentTrackPayload.length > 0) {
      restored.currentTrackId = currentTrackPayload;
    }
  } catch (error) {
    console.error(`read current track from preferences failed: ${JSON.stringify(error)}`);
  }

  try {
    let collectionModePayload = await store.get(PREF_KEY_COLLECTION_MODE, CollectionMode.Library);
    if (typeof collectionModePayload === 'number' && collectionModePayload >= CollectionMode.Library &&
      collectionModePayload <= CollectionMode.Recent) {
      restored.collectionMode = collectionModePayload as CollectionMode;
    }
  } catch (error) {
    console.error(`read collection mode from preferences failed: ${JSON.stringify(error)}`);
  }

  try {
    let listeningPayload = await store.get(PREF_KEY_TOTAL_LISTENING_MS, LISTENING_SEED_MS);
    if (typeof listeningPayload === 'number' && listeningPayload > 0) {
      restored.totalListeningMs = listeningPayload;
    }
  } catch (error) {
    console.error(`read listening duration from preferences failed: ${JSON.stringify(error)}`);
  }

  try {
    let playModePayload = await store.get(PREF_KEY_PLAY_MODE, PlayMode.Sequential);
    if (typeof playModePayload === 'number' && playModePayload >= PlayMode.Shuffle &&
      playModePayload <= PlayMode.Loop) {
      restored.playMode = playModePayload as PlayMode;
    }
  } catch (error) {
    console.error(`read play mode from preferences failed: ${JSON.stringify(error)}`);
  }

  try {
    let sourcesPayload = await store.get(PREF_KEY_MUSIC_SOURCES, '[]');
    if (typeof sourcesPayload === 'string' && sourcesPayload.length > 0) {
      let parsed = JSON.parse(sourcesPayload) as PersistedMusicSourceConfig[];
      let normalizedSources: MusicSourceConfig[] = [];
      for (let index = 0; index < parsed.length; index++) {
        let source = parsed[index];
        if (!source || typeof source.id !== 'string' || source.id.length === 0) {
          continue;
        }
        if (typeof source.script === 'string' && source.script.length > 0) {
          restored.musicSourceScripts.set(source.id, source.script);
        }
        normalizedSources.push(normalizeMusicSource(source));
      }
      restored.musicSources = normalizedSources;
    }
  } catch (error) {
    console.error(`read music sources from preferences failed: ${JSON.stringify(error)}`);
  }

  if (restored.localTracks.length > 0) {
    let hasTrack = restored.localTracks.some((track: MusicTrack) => track.id === restored.currentTrackId);
    if (!hasTrack) {
      restored.currentTrackId = restored.localTracks[0].id;
    }
  } else {
    restored.currentTrackId = MINI_PLACEHOLDER_TRACK.id;
  }

  return restored;
}

export async function persistAppState(
  store: preferences.Preferences,
  state: PersistableAppState,
  musicSourceScripts: Map<string, string>
): Promise<void> {
  let serializedTracks = JSON.stringify(state.localTracks.map((track: MusicTrack) => copyTrack(track)));
  let serializedRecent = JSON.stringify(state.recentTrackIds);
  await store.put(PREF_KEY_LOCAL_TRACKS, serializedTracks);
  await store.put(PREF_KEY_RECENT_TRACK_IDS, serializedRecent);
  await store.put(PREF_KEY_CURRENT_TRACK_ID, state.currentTrackId);
  await store.put(PREF_KEY_COLLECTION_MODE, state.collectionMode);
  await store.put(PREF_KEY_TOTAL_LISTENING_MS, state.totalListeningMs);
  await store.put(PREF_KEY_PLAY_MODE, state.playMode);
  await store.put(PREF_KEY_MUSIC_SOURCES, JSON.stringify(state.musicSources));
  for (let index = 0; index < state.musicSources.length; index++) {
    let source = state.musicSources[index];
    let script = musicSourceScripts.get(source.id) || '';
    if (script.length > 0) {
      await store.put(getMusicSourceScriptPreferenceKey(source.id), script);
    }
  }
  await store.flush();
}

export function createReadPolicies(uris: string[]): Array<fileShare.PolicyInfo> {
  let policies: Array<fileShare.PolicyInfo> = [];
  uris.forEach((uri: string) => {
    policies.push({
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE
    });
  });
  return policies;
}

export async function persistReadUriPermissions(uris: string[]): Promise<boolean> {
  if (uris.length === 0) {
    return true;
  }
  try {
    let policies = createReadPolicies(uris);
    let persistedResults = await fileShare.checkPersistentPermission(policies);
    let missingPolicies: Array<fileShare.PolicyInfo> = [];
    for (let index = 0; index < persistedResults.length; index++) {
      if (!persistedResults[index]) {
        missingPolicies.push(policies[index]);
      }
    }
    if (missingPolicies.length > 0) {
      await fileShare.persistPermission(missingPolicies);
    }
    return true;
  } catch (error) {
    console.error(`persist uri permissions failed: ${JSON.stringify(error)}`);
    return false;
  }
}

export async function activatePersistedReadUriPermissions(trackUris: string[]): Promise<void> {
  if (trackUris.length === 0) {
    return;
  }
  try {
    let policies = createReadPolicies(trackUris);
    let persistedResults = await fileShare.checkPersistentPermission(policies);
    let activePolicies: Array<fileShare.PolicyInfo> = [];
    for (let index = 0; index < persistedResults.length; index++) {
      if (persistedResults[index]) {
        activePolicies.push(policies[index]);
      }
    }
    if (activePolicies.length > 0) {
      await fileShare.activatePermission(activePolicies);
    }
  } catch (error) {
    console.error(`activate uri permissions failed: ${JSON.stringify(error)}`);
  }
}
