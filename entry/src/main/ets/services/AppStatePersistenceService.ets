import { common } from '@kit.AbilityKit';
import { preferences, relationalStore } from '@kit.ArkData';
import { fileShare } from '@kit.CoreFileKit';

import {
  APP_DATABASE_NAME,
  APP_DATABASE_VERSION,
  DEFAULT_PLAYBACK_COLLECTION_ID,
  LISTENING_SEED_MS,
  MAX_RECENT_TRACKS,
  MINI_PLACEHOLDER_TRACK,
  PREFERENCES_FILE_NAME,
  PREF_KEY_ACTIVE_PLAYBACK_COLLECTION_ID,
  PREF_KEY_APP_THEME_MODE,
  PREF_KEY_BAIDU_PAN_APP_KEY,
  PREF_KEY_BAIDU_PAN_ACCESS_TOKEN,
  PREF_KEY_BAIDU_PAN_CURRENT_DIR,
  PREF_KEY_COLLECTION_MODE,
  PREF_KEY_CURRENT_TRACK_ID,
  PREF_KEY_CUSTOM_PLAYLISTS,
  PREF_KEY_LOCAL_TRACKS,
  PREF_KEY_MUSIC_SOURCES,
  PREF_KEY_MUSIC_SOURCE_SCRIPT_PREFIX,
  PREF_KEY_PLAYBACK_DRAWER_SHOW_ALBUM_COLLECTIONS,
  PREF_KEY_PLAYBACK_DRAWER_SHOW_ARTIST_COLLECTIONS,
  PREF_KEY_PLAY_MODE,
  PREF_KEY_RECENT_TRACK_IDS,
  PREF_KEY_TOTAL_LISTENING_MS
} from '../constants/AppConstants';
import {
  AppThemeMode,
  CollectionMode,
  CustomPlaylist,
  MusicSourceConfig,
  MusicTrack,
  PersistedMusicSourceConfig,
  PlayMode
} from '../models/AppModels';
import { normalizeCustomPlaylists } from './CustomPlaylistService';
import { copyTrack } from '../utils/TrackUtils';
import { normalizeMusicSource } from '../utils/MusicSourceUtils';

const LEGACY_BUNDLED_TRACK_ID: string = 'bundled-track-netease-demo';
const LEGACY_BUNDLED_TRACK_FILE_NAME: string = 'netease_demo_import.mp3';

const TABLE_APP_CONFIG: string = 'app_config';
const TABLE_LOCAL_TRACK: string = 'local_track';
const TABLE_MUSIC_SOURCE_CONFIG: string = 'music_source_config';
const TABLE_MUSIC_SOURCE_SCRIPT: string = 'music_source_script';
const TABLE_PLAYBACK_RECORD: string = 'playback_record';

const CONFIG_KEY_MIGRATION_STATE: string = 'legacy_preferences_migrated';
const CONFIG_VALUE_MIGRATED: string = '1';

const SQL_CREATE_APP_CONFIG_TABLE: string =
  'CREATE TABLE IF NOT EXISTS app_config (' +
  'config_key TEXT PRIMARY KEY NOT NULL,' +
  'config_value TEXT NOT NULL,' +
  'updated_at INTEGER NOT NULL' +
  ')';

const SQL_CREATE_LOCAL_TRACK_TABLE: string =
  'CREATE TABLE IF NOT EXISTS local_track (' +
  'track_id TEXT PRIMARY KEY NOT NULL,' +
  'sort_index INTEGER NOT NULL,' +
  'title TEXT NOT NULL,' +
  'artist TEXT NOT NULL,' +
  'album TEXT NOT NULL,' +
  'duration_ms INTEGER NOT NULL DEFAULT 0,' +
  'folder TEXT NOT NULL,' +
  'source_uri TEXT NOT NULL,' +
  'file_path TEXT NOT NULL,' +
  'raw_file_name TEXT NOT NULL,' +
  'accent_color TEXT NOT NULL,' +
  'pic TEXT NOT NULL,' +
  'is_favorite INTEGER NOT NULL,' +
  'is_imported INTEGER NOT NULL,' +
  'in_play_queue INTEGER NOT NULL,' +
  'play_count INTEGER NOT NULL,' +
  'last_played_at INTEGER NOT NULL,' +
  'source_import_key TEXT NOT NULL,' +
  'updated_at INTEGER NOT NULL' +
  ')';

const SQL_CREATE_MUSIC_SOURCE_CONFIG_TABLE: string =
  'CREATE TABLE IF NOT EXISTS music_source_config (' +
  'source_id TEXT PRIMARY KEY NOT NULL,' +
  'sort_index INTEGER NOT NULL,' +
  'payload_json TEXT NOT NULL,' +
  'updated_at INTEGER NOT NULL' +
  ')';

const SQL_CREATE_MUSIC_SOURCE_SCRIPT_TABLE: string =
  'CREATE TABLE IF NOT EXISTS music_source_script (' +
  'source_id TEXT PRIMARY KEY NOT NULL,' +
  'script_content TEXT NOT NULL,' +
  'updated_at INTEGER NOT NULL' +
  ')';

const SQL_CREATE_PLAYBACK_RECORD_TABLE: string =
  'CREATE TABLE IF NOT EXISTS playback_record (' +
  'record_id TEXT PRIMARY KEY NOT NULL,' +
  'track_id TEXT NOT NULL,' +
  'track_title TEXT NOT NULL,' +
  'track_artist TEXT NOT NULL,' +
  'track_album TEXT NOT NULL,' +
  'track_source_import_key TEXT NOT NULL,' +
  'started_at INTEGER NOT NULL,' +
  'ended_at INTEGER NOT NULL,' +
  'listened_ms INTEGER NOT NULL,' +
  'created_at INTEGER NOT NULL' +
  ')';

export interface RestoredAppState {
  localTracks: MusicTrack[];
  recentTrackIds: string[];
  currentTrackId: string;
  collectionMode: CollectionMode;
  totalListeningMs: number;
  playMode: PlayMode;
  appThemeMode: AppThemeMode;
  customPlaylists: CustomPlaylist[];
  activePlaybackCollectionId: string;
  playbackDrawerShowAlbumCollections: boolean;
  playbackDrawerShowArtistCollections: boolean;
  baiduPanAppKey: string;
  baiduPanAccessToken: string;
  baiduPanCurrentDir: string;
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
  appThemeMode: AppThemeMode;
  customPlaylists: CustomPlaylist[];
  activePlaybackCollectionId: string;
  playbackDrawerShowAlbumCollections: boolean;
  playbackDrawerShowArtistCollections: boolean;
  baiduPanAppKey: string;
  baiduPanAccessToken: string;
  baiduPanCurrentDir: string;
  musicSources: MusicSourceConfig[];
}

export interface PlaybackRecordEntry {
  id: string;
  trackId: string;
  trackTitle: string;
  trackArtist: string;
  trackAlbum: string;
  trackSourceImportKey: string;
  startedAt: number;
  endedAt: number;
  listenedMs: number;
}

interface OrderedTrackItem {
  sortIndex: number;
  track: MusicTrack;
}

interface OrderedMusicSourceItem {
  sortIndex: number;
  source: MusicSourceConfig;
}

function isLegacyBundledTrack(track: MusicTrack): boolean {
  if (track.id === LEGACY_BUNDLED_TRACK_ID) {
    return true;
  }
  return track.rawFileName === LEGACY_BUNDLED_TRACK_FILE_NAME &&
    track.sourceUri.length === 0 &&
    track.filePath.length === 0;
}

function trackTableValues(track: MusicTrack, sortIndex: number, updatedAt: number): relationalStore.ValuesBucket {
  return {
    track_id: track.id,
    sort_index: sortIndex,
    title: track.title,
    artist: track.artist,
    album: track.album,
    duration_ms: track.durationMs,
    folder: track.folder,
    source_uri: track.sourceUri,
    file_path: track.filePath,
    raw_file_name: track.rawFileName,
    accent_color: track.accentColor,
    pic: track.pic,
    is_favorite: track.isFavorite ? 1 : 0,
    is_imported: track.isImported ? 1 : 0,
    in_play_queue: track.inPlayQueue ? 1 : 0,
    play_count: track.playCount,
    last_played_at: track.lastPlayedAt,
    source_import_key: track.sourceImportKey ?? '',
    updated_at: updatedAt
  };
}

function musicSourceValues(source: MusicSourceConfig, sortIndex: number, updatedAt: number): relationalStore.ValuesBucket {
  return {
    source_id: source.id,
    sort_index: sortIndex,
    payload_json: JSON.stringify(source),
    updated_at: updatedAt
  };
}

function musicSourceScriptValues(sourceId: string, scriptContent: string, updatedAt: number): relationalStore.ValuesBucket {
  return {
    source_id: sourceId,
    script_content: scriptContent,
    updated_at: updatedAt
  };
}

function playbackRecordValues(record: PlaybackRecordEntry, createdAt: number): relationalStore.ValuesBucket {
  return {
    record_id: record.id,
    track_id: record.trackId,
    track_title: record.trackTitle,
    track_artist: record.trackArtist,
    track_album: record.trackAlbum,
    track_source_import_key: record.trackSourceImportKey,
    started_at: record.startedAt,
    ended_at: record.endedAt,
    listened_ms: record.listenedMs,
    created_at: createdAt
  };
}

function parseConfigValue<T>(payload: string | null, fallback: T): T {
  if (payload === null || payload.length === 0) {
    return fallback;
  }
  try {
    return JSON.parse(payload) as T;
  } catch (error) {
    console.error(`parse persisted config failed: ${JSON.stringify(error)}`);
    return fallback;
  }
}

async function initializeAppDatabase(store: relationalStore.RdbStore): Promise<void> {
  await store.executeSql(SQL_CREATE_APP_CONFIG_TABLE);
  await store.executeSql(SQL_CREATE_LOCAL_TRACK_TABLE);
  try {
    await store.executeSql('ALTER TABLE local_track ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0');
  } catch (error) {
    let errorMessage = error instanceof Error ? `${error.name}: ${error.message}` : JSON.stringify(error);
    let normalized = errorMessage.toLowerCase();
    if (normalized.indexOf('duplicate') < 0 && normalized.indexOf('exists') < 0 && normalized.indexOf('already') < 0) {
      console.error(`ensure local_track.duration_ms failed: ${errorMessage}`);
    }
  }
  await store.executeSql(SQL_CREATE_MUSIC_SOURCE_CONFIG_TABLE);
  await store.executeSql(SQL_CREATE_MUSIC_SOURCE_SCRIPT_TABLE);
  await store.executeSql(SQL_CREATE_PLAYBACK_RECORD_TABLE);
  try {
    if (store.version !== APP_DATABASE_VERSION) {
      store.version = APP_DATABASE_VERSION;
    }
  } catch (error) {
    console.error(`set database version failed: ${JSON.stringify(error)}`);
  }
}

async function queryConfigValue(
  store: relationalStore.RdbStore,
  key: string
): Promise<string | null> {
  let predicates = new relationalStore.RdbPredicates(TABLE_APP_CONFIG);
  predicates.equalTo('config_key', key);
  let resultSet = await store.query(predicates, ['config_value']);
  try {
    if (!resultSet.goToFirstRow()) {
      return null;
    }
    return resultSet.getString(0);
  } finally {
    resultSet.close();
  }
}

async function upsertConfigValue(
  store: relationalStore.RdbStore,
  key: string,
  value: string
): Promise<void> {
  await store.insert(TABLE_APP_CONFIG, {
    config_key: key,
    config_value: value,
    updated_at: Date.now()
  }, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
}

async function replaceLocalTracks(
  store: relationalStore.RdbStore,
  tracks: MusicTrack[]
): Promise<void> {
  await store.executeSql(`DELETE FROM ${TABLE_LOCAL_TRACK}`);
  let updatedAt = Date.now();
  for (let index = 0; index < tracks.length; index++) {
    let track = copyTrack(tracks[index]);
    await store.insert(
      TABLE_LOCAL_TRACK,
      trackTableValues(track, index, updatedAt),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
  }
}

function replaceLocalTracksSync(
  store: relationalStore.RdbStore,
  tracks: MusicTrack[]
): void {
  store.executeSync(`DELETE FROM ${TABLE_LOCAL_TRACK}`);
  let updatedAt = Date.now();
  for (let index = 0; index < tracks.length; index++) {
    let track = copyTrack(tracks[index]);
    store.insertSync(
      TABLE_LOCAL_TRACK,
      trackTableValues(track, index, updatedAt),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
  }
}

async function replaceMusicSources(
  store: relationalStore.RdbStore,
  sources: MusicSourceConfig[],
  scripts: Map<string, string>
): Promise<void> {
  await store.executeSql(`DELETE FROM ${TABLE_MUSIC_SOURCE_CONFIG}`);
  await store.executeSql(`DELETE FROM ${TABLE_MUSIC_SOURCE_SCRIPT}`);
  let updatedAt = Date.now();
  for (let index = 0; index < sources.length; index++) {
    let source = sources[index];
    await store.insert(
      TABLE_MUSIC_SOURCE_CONFIG,
      musicSourceValues(source, index, updatedAt),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
    let scriptContent = scripts.get(source.id) ?? '';
    if (scriptContent.length > 0) {
      await store.insert(
        TABLE_MUSIC_SOURCE_SCRIPT,
        musicSourceScriptValues(source.id, scriptContent, updatedAt),
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    }
  }
}

function replaceMusicSourcesSync(
  store: relationalStore.RdbStore,
  sources: MusicSourceConfig[],
  scripts: Map<string, string>
): void {
  store.executeSync(`DELETE FROM ${TABLE_MUSIC_SOURCE_CONFIG}`);
  store.executeSync(`DELETE FROM ${TABLE_MUSIC_SOURCE_SCRIPT}`);
  let updatedAt = Date.now();
  for (let index = 0; index < sources.length; index++) {
    let source = sources[index];
    store.insertSync(
      TABLE_MUSIC_SOURCE_CONFIG,
      musicSourceValues(source, index, updatedAt),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
    let scriptContent = scripts.get(source.id) ?? '';
    if (scriptContent.length > 0) {
      store.insertSync(
        TABLE_MUSIC_SOURCE_SCRIPT,
        musicSourceScriptValues(source.id, scriptContent, updatedAt),
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
    }
  }
}

async function writeStateConfig(
  store: relationalStore.RdbStore,
  state: PersistableAppState
): Promise<void> {
  await upsertConfigValue(store, PREF_KEY_RECENT_TRACK_IDS, JSON.stringify(state.recentTrackIds.slice(0, MAX_RECENT_TRACKS)));
  await upsertConfigValue(store, PREF_KEY_CURRENT_TRACK_ID, JSON.stringify(state.currentTrackId));
  await upsertConfigValue(store, PREF_KEY_COLLECTION_MODE, JSON.stringify(state.collectionMode));
  await upsertConfigValue(store, PREF_KEY_TOTAL_LISTENING_MS, JSON.stringify(state.totalListeningMs));
  await upsertConfigValue(store, PREF_KEY_PLAY_MODE, JSON.stringify(state.playMode));
  await upsertConfigValue(store, PREF_KEY_APP_THEME_MODE, JSON.stringify(state.appThemeMode));
  await upsertConfigValue(store, PREF_KEY_CUSTOM_PLAYLISTS, JSON.stringify(state.customPlaylists));
  await upsertConfigValue(store, PREF_KEY_ACTIVE_PLAYBACK_COLLECTION_ID, JSON.stringify(state.activePlaybackCollectionId));
  await upsertConfigValue(
    store,
    PREF_KEY_PLAYBACK_DRAWER_SHOW_ALBUM_COLLECTIONS,
    JSON.stringify(state.playbackDrawerShowAlbumCollections)
  );
  await upsertConfigValue(
    store,
    PREF_KEY_PLAYBACK_DRAWER_SHOW_ARTIST_COLLECTIONS,
    JSON.stringify(state.playbackDrawerShowArtistCollections)
  );
  await upsertConfigValue(store, PREF_KEY_BAIDU_PAN_APP_KEY, JSON.stringify(state.baiduPanAppKey));
  await upsertConfigValue(store, PREF_KEY_BAIDU_PAN_ACCESS_TOKEN, JSON.stringify(state.baiduPanAccessToken));
  await upsertConfigValue(store, PREF_KEY_BAIDU_PAN_CURRENT_DIR, JSON.stringify(state.baiduPanCurrentDir));
}

function upsertConfigValueSync(
  store: relationalStore.RdbStore,
  key: string,
  value: string
): void {
  store.insertSync(TABLE_APP_CONFIG, {
    config_key: key,
    config_value: value,
    updated_at: Date.now()
  }, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
}

function writeStateConfigSync(
  store: relationalStore.RdbStore,
  state: PersistableAppState
): void {
  upsertConfigValueSync(store, PREF_KEY_RECENT_TRACK_IDS, JSON.stringify(state.recentTrackIds.slice(0, MAX_RECENT_TRACKS)));
  upsertConfigValueSync(store, PREF_KEY_CURRENT_TRACK_ID, JSON.stringify(state.currentTrackId));
  upsertConfigValueSync(store, PREF_KEY_COLLECTION_MODE, JSON.stringify(state.collectionMode));
  upsertConfigValueSync(store, PREF_KEY_TOTAL_LISTENING_MS, JSON.stringify(state.totalListeningMs));
  upsertConfigValueSync(store, PREF_KEY_PLAY_MODE, JSON.stringify(state.playMode));
  upsertConfigValueSync(store, PREF_KEY_APP_THEME_MODE, JSON.stringify(state.appThemeMode));
  upsertConfigValueSync(store, PREF_KEY_CUSTOM_PLAYLISTS, JSON.stringify(state.customPlaylists));
  upsertConfigValueSync(store, PREF_KEY_ACTIVE_PLAYBACK_COLLECTION_ID, JSON.stringify(state.activePlaybackCollectionId));
  upsertConfigValueSync(
    store,
    PREF_KEY_PLAYBACK_DRAWER_SHOW_ALBUM_COLLECTIONS,
    JSON.stringify(state.playbackDrawerShowAlbumCollections)
  );
  upsertConfigValueSync(
    store,
    PREF_KEY_PLAYBACK_DRAWER_SHOW_ARTIST_COLLECTIONS,
    JSON.stringify(state.playbackDrawerShowArtistCollections)
  );
  upsertConfigValueSync(store, PREF_KEY_BAIDU_PAN_APP_KEY, JSON.stringify(state.baiduPanAppKey));
  upsertConfigValueSync(store, PREF_KEY_BAIDU_PAN_ACCESS_TOKEN, JSON.stringify(state.baiduPanAccessToken));
  upsertConfigValueSync(store, PREF_KEY_BAIDU_PAN_CURRENT_DIR, JSON.stringify(state.baiduPanCurrentDir));
}

async function persistStateTables(
  store: relationalStore.RdbStore,
  state: PersistableAppState,
  musicSourceScripts: Map<string, string>
): Promise<void> {
  try {
    store.beginTransaction();
    replaceLocalTracksSync(store, state.localTracks);
    replaceMusicSourcesSync(store, state.musicSources, musicSourceScripts);
    writeStateConfigSync(store, state);
    store.commit();
  } catch (error) {
    try {
      store.rollBack();
    } catch (_) {
      // ignore rollback errors and report the original failure below
    }
    throw error instanceof Error ? error : new Error(JSON.stringify(error));
  }
}

async function readLegacyMusicSourceScript(
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

async function restoreLegacyPreferenceState(store: preferences.Preferences): Promise<RestoredAppState> {
  let restored: RestoredAppState = {
    localTracks: [],
    recentTrackIds: [],
    currentTrackId: MINI_PLACEHOLDER_TRACK.id,
    collectionMode: CollectionMode.Library,
    totalListeningMs: LISTENING_SEED_MS,
    playMode: PlayMode.Sequential,
    appThemeMode: AppThemeMode.Light,
    customPlaylists: [],
    activePlaybackCollectionId: DEFAULT_PLAYBACK_COLLECTION_ID,
    playbackDrawerShowAlbumCollections: false,
    playbackDrawerShowArtistCollections: false,
    baiduPanAppKey: '',
    baiduPanAccessToken: '',
    baiduPanCurrentDir: '/',
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
        console.error(`restore legacy local tracks failed: ${JSON.stringify(error)}`);
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
        console.error(`restore legacy recent tracks failed: ${JSON.stringify(error)}`);
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
    let themeModePayload = await store.get(PREF_KEY_APP_THEME_MODE, AppThemeMode.Light);
    let themeMode = AppThemeMode.Light;
    if (typeof themeModePayload === 'number') {
      themeMode = themeModePayload as AppThemeMode;
    } else if (typeof themeModePayload === 'string' && themeModePayload.length > 0) {
      themeMode = Number(themeModePayload) as AppThemeMode;
    }
    if (themeMode >= AppThemeMode.System && themeMode <= AppThemeMode.Dark) {
      restored.appThemeMode = themeMode;
    }
  } catch (error) {
    console.error(`read app theme mode from preferences failed: ${JSON.stringify(error)}`);
  }

  try {
    let showAlbumPayload = await store.get(PREF_KEY_PLAYBACK_DRAWER_SHOW_ALBUM_COLLECTIONS, false);
    if (typeof showAlbumPayload === 'boolean') {
      restored.playbackDrawerShowAlbumCollections = showAlbumPayload;
    }
  } catch (error) {
    console.error(`read album drawer fold state from preferences failed: ${JSON.stringify(error)}`);
  }

  try {
    let showArtistPayload = await store.get(PREF_KEY_PLAYBACK_DRAWER_SHOW_ARTIST_COLLECTIONS, false);
    if (typeof showArtistPayload === 'boolean') {
      restored.playbackDrawerShowArtistCollections = showArtistPayload;
    }
  } catch (error) {
    console.error(`read artist drawer fold state from preferences failed: ${JSON.stringify(error)}`);
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

  for (let index = 0; index < restored.musicSources.length; index++) {
    let source = restored.musicSources[index];
    let script = await readLegacyMusicSourceScript(store, restored.musicSourceScripts, source.id);
    if (script.length > 0) {
      restored.musicSourceScripts.set(source.id, script);
    }
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

function hasMeaningfulState(restored: RestoredAppState): boolean {
  return restored.localTracks.length > 0 ||
    restored.recentTrackIds.length > 0 ||
    restored.currentTrackId !== MINI_PLACEHOLDER_TRACK.id ||
    restored.collectionMode !== CollectionMode.Library ||
    restored.totalListeningMs !== LISTENING_SEED_MS ||
    restored.playMode !== PlayMode.Sequential ||
    restored.appThemeMode !== AppThemeMode.Light ||
    restored.musicSources.length > 0 ||
    restored.musicSourceScripts.size > 0;
}

async function migrateLegacyPreferencesIfNeeded(
  store: relationalStore.RdbStore,
  context: common.UIAbilityContext
): Promise<void> {
  let migrationState = await queryConfigValue(store, CONFIG_KEY_MIGRATION_STATE);
  if (migrationState === CONFIG_VALUE_MIGRATED) {
    return;
  }

  try {
    let legacyStore = await preferences.getPreferences(context, { name: PREFERENCES_FILE_NAME });
    let restored = await restoreLegacyPreferenceState(legacyStore);
    if (hasMeaningfulState(restored)) {
      await persistStateTables(store, {
        localTracks: restored.localTracks,
        recentTrackIds: restored.recentTrackIds,
      currentTrackId: restored.currentTrackId,
      collectionMode: restored.collectionMode,
      totalListeningMs: restored.totalListeningMs,
      playMode: restored.playMode,
      appThemeMode: restored.appThemeMode,
      customPlaylists: restored.customPlaylists,
      activePlaybackCollectionId: restored.activePlaybackCollectionId,
        playbackDrawerShowAlbumCollections: restored.playbackDrawerShowAlbumCollections,
        playbackDrawerShowArtistCollections: restored.playbackDrawerShowArtistCollections,
        baiduPanAppKey: restored.baiduPanAppKey,
        baiduPanAccessToken: restored.baiduPanAccessToken,
        baiduPanCurrentDir: restored.baiduPanCurrentDir,
        musicSources: restored.musicSources
      }, restored.musicSourceScripts);
    }
    await upsertConfigValue(store, CONFIG_KEY_MIGRATION_STATE, CONFIG_VALUE_MIGRATED);
  } catch (error) {
    console.error(`migrate legacy preferences failed: ${JSON.stringify(error)}`);
  }
}

export async function ensureAppDatabase(
  existing: relationalStore.RdbStore | null,
  context: common.UIAbilityContext
): Promise<relationalStore.RdbStore> {
  if (existing !== null) {
    return existing;
  }
  let store = await relationalStore.getRdbStore(context, {
    name: APP_DATABASE_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  });
  await initializeAppDatabase(store);
  await migrateLegacyPreferencesIfNeeded(store, context);
  return store;
}

export function getMusicSourceScriptPreferenceKey(sourceId: string): string {
  return `${PREF_KEY_MUSIC_SOURCE_SCRIPT_PREFIX}${sourceId}`;
}

export async function readMusicSourceScript(
  store: relationalStore.RdbStore,
  cache: Map<string, string>,
  sourceId: string
): Promise<string> {
  if (cache.has(sourceId)) {
    return cache.get(sourceId) || '';
  }
  let predicates = new relationalStore.RdbPredicates(TABLE_MUSIC_SOURCE_SCRIPT);
  predicates.equalTo('source_id', sourceId);
  let resultSet = await store.query(predicates, ['script_content']);
  try {
    if (!resultSet.goToFirstRow()) {
      return '';
    }
    let scriptContent = resultSet.getString(0);
    if (scriptContent.length > 0) {
      cache.set(sourceId, scriptContent);
    }
    return scriptContent;
  } finally {
    resultSet.close();
  }
}

export async function deleteMusicSourceScript(
  store: relationalStore.RdbStore,
  cache: Map<string, string>,
  sourceId: string
): Promise<void> {
  cache.delete(sourceId);
  let predicates = new relationalStore.RdbPredicates(TABLE_MUSIC_SOURCE_SCRIPT);
  predicates.equalTo('source_id', sourceId);
  await store.delete(predicates);
}

export async function restorePersistedAppState(store: relationalStore.RdbStore): Promise<RestoredAppState> {
  let restored: RestoredAppState = {
    localTracks: [],
    recentTrackIds: [],
    currentTrackId: MINI_PLACEHOLDER_TRACK.id,
    collectionMode: CollectionMode.Library,
    totalListeningMs: LISTENING_SEED_MS,
    playMode: PlayMode.Sequential,
    appThemeMode: AppThemeMode.Light,
    customPlaylists: [],
    activePlaybackCollectionId: DEFAULT_PLAYBACK_COLLECTION_ID,
    playbackDrawerShowAlbumCollections: false,
    playbackDrawerShowArtistCollections: false,
    baiduPanAppKey: '',
    baiduPanAccessToken: '',
    baiduPanCurrentDir: '/',
    musicSources: [],
    musicSourceScripts: new Map()
  };

  try {
    let trackPredicates = new relationalStore.RdbPredicates(TABLE_LOCAL_TRACK);
    let resultSet = await store.query(trackPredicates);
    try {
      if (resultSet.goToFirstRow()) {
        let tracks: OrderedTrackItem[] = [];
        do {
          let track: MusicTrack = {
            id: resultSet.getString(resultSet.getColumnIndex('track_id')),
            title: resultSet.getString(resultSet.getColumnIndex('title')),
            artist: resultSet.getString(resultSet.getColumnIndex('artist')),
            album: resultSet.getString(resultSet.getColumnIndex('album')),
            durationMs: resultSet.getLong(resultSet.getColumnIndex('duration_ms')),
            folder: resultSet.getString(resultSet.getColumnIndex('folder')),
            sourceUri: resultSet.getString(resultSet.getColumnIndex('source_uri')),
            filePath: resultSet.getString(resultSet.getColumnIndex('file_path')),
            rawFileName: resultSet.getString(resultSet.getColumnIndex('raw_file_name')),
            accentColor: resultSet.getString(resultSet.getColumnIndex('accent_color')),
            pic: resultSet.getString(resultSet.getColumnIndex('pic')),
            isFavorite: resultSet.getLong(resultSet.getColumnIndex('is_favorite')) > 0,
            isImported: resultSet.getLong(resultSet.getColumnIndex('is_imported')) > 0,
            inPlayQueue: resultSet.getLong(resultSet.getColumnIndex('in_play_queue')) > 0,
            playCount: resultSet.getLong(resultSet.getColumnIndex('play_count')),
            lastPlayedAt: resultSet.getLong(resultSet.getColumnIndex('last_played_at'))
          };
          let sourceImportKey = resultSet.getString(resultSet.getColumnIndex('source_import_key'));
          if (sourceImportKey.length > 0) {
            track.sourceImportKey = sourceImportKey;
          }
          if (!isLegacyBundledTrack(track)) {
            let orderedTrack: OrderedTrackItem = {
              sortIndex: resultSet.getLong(resultSet.getColumnIndex('sort_index')),
              track: track
            };
            tracks.push(orderedTrack);
          }
        } while (resultSet.goToNextRow());
        restored.localTracks = tracks
          .sort((left, right) => left.sortIndex - right.sortIndex)
          .map((item) => copyTrack(item.track));
      }
    } finally {
      resultSet.close();
    }
  } catch (error) {
    console.error(`read local tracks from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    restored.recentTrackIds = parseConfigValue<Array<string>>(
      await queryConfigValue(store, PREF_KEY_RECENT_TRACK_IDS),
      []
    ).slice(0, MAX_RECENT_TRACKS);
  } catch (error) {
    console.error(`read recent tracks from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let currentTrackId = parseConfigValue<string>(
      await queryConfigValue(store, PREF_KEY_CURRENT_TRACK_ID),
      MINI_PLACEHOLDER_TRACK.id
    );
    if (typeof currentTrackId === 'string' && currentTrackId.length > 0) {
      restored.currentTrackId = currentTrackId;
    }
  } catch (error) {
    console.error(`read current track from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let collectionMode = parseConfigValue<number>(
      await queryConfigValue(store, PREF_KEY_COLLECTION_MODE),
      CollectionMode.Library
    );
    if (collectionMode >= CollectionMode.Library && collectionMode <= CollectionMode.Recent) {
      restored.collectionMode = collectionMode as CollectionMode;
    }
  } catch (error) {
    console.error(`read collection mode from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let totalListeningMs = parseConfigValue<number>(
      await queryConfigValue(store, PREF_KEY_TOTAL_LISTENING_MS),
      LISTENING_SEED_MS
    );
    if (typeof totalListeningMs === 'number' && totalListeningMs > 0) {
      restored.totalListeningMs = totalListeningMs;
    }
  } catch (error) {
    console.error(`read listening duration from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let playMode = parseConfigValue<number>(
      await queryConfigValue(store, PREF_KEY_PLAY_MODE),
      PlayMode.Sequential
    );
    if (playMode >= PlayMode.Shuffle && playMode <= PlayMode.Loop) {
      restored.playMode = playMode as PlayMode;
    }
  } catch (error) {
    console.error(`read play mode from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let appThemeMode = parseConfigValue<number>(
      await queryConfigValue(store, PREF_KEY_APP_THEME_MODE),
      AppThemeMode.Light
    );
    if (appThemeMode >= AppThemeMode.System && appThemeMode <= AppThemeMode.Dark) {
      restored.appThemeMode = appThemeMode as AppThemeMode;
    }
  } catch (error) {
    console.error(`read app theme mode from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let customPlaylists = parseConfigValue<CustomPlaylist[]>(
      await queryConfigValue(store, PREF_KEY_CUSTOM_PLAYLISTS),
      []
    );
    restored.customPlaylists = normalizeCustomPlaylists(Array.isArray(customPlaylists) ? customPlaylists : []);
  } catch (error) {
    console.error(`read custom playlists from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let activePlaybackCollectionId = parseConfigValue<string>(
      await queryConfigValue(store, PREF_KEY_ACTIVE_PLAYBACK_COLLECTION_ID),
      DEFAULT_PLAYBACK_COLLECTION_ID
    );
    if (typeof activePlaybackCollectionId === 'string' && activePlaybackCollectionId.length > 0) {
      restored.activePlaybackCollectionId = activePlaybackCollectionId;
    }
  } catch (error) {
    console.error(`read active playback collection from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    restored.playbackDrawerShowAlbumCollections = parseConfigValue<boolean>(
      await queryConfigValue(store, PREF_KEY_PLAYBACK_DRAWER_SHOW_ALBUM_COLLECTIONS),
      false
    ) === true;
  } catch (error) {
    console.error(`read album drawer fold state from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    restored.playbackDrawerShowArtistCollections = parseConfigValue<boolean>(
      await queryConfigValue(store, PREF_KEY_PLAYBACK_DRAWER_SHOW_ARTIST_COLLECTIONS),
      false
    ) === true;
  } catch (error) {
    console.error(`read artist drawer fold state from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let appKey = parseConfigValue<string>(
      await queryConfigValue(store, PREF_KEY_BAIDU_PAN_APP_KEY),
      ''
    );
    restored.baiduPanAppKey = typeof appKey === 'string' ? appKey : '';
  } catch (error) {
    console.error(`read baidu pan app key from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let accessToken = parseConfigValue<string>(
      await queryConfigValue(store, PREF_KEY_BAIDU_PAN_ACCESS_TOKEN),
      ''
    );
    restored.baiduPanAccessToken = typeof accessToken === 'string' ? accessToken : '';
  } catch (error) {
    console.error(`read baidu pan access token from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let currentDir = parseConfigValue<string>(
      await queryConfigValue(store, PREF_KEY_BAIDU_PAN_CURRENT_DIR),
      '/'
    );
    restored.baiduPanCurrentDir = typeof currentDir === 'string' && currentDir.length > 0 ? currentDir : '/';
  } catch (error) {
    console.error(`read baidu pan current dir from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let sourcePredicates = new relationalStore.RdbPredicates(TABLE_MUSIC_SOURCE_CONFIG);
    let resultSet = await store.query(sourcePredicates);
    try {
      if (resultSet.goToFirstRow()) {
        let sources: OrderedMusicSourceItem[] = [];
        do {
          let payloadJson = resultSet.getString(resultSet.getColumnIndex('payload_json'));
          if (payloadJson.length === 0) {
            continue;
          }
          try {
            let parsed = JSON.parse(payloadJson) as PersistedMusicSourceConfig;
            let orderedSource: OrderedMusicSourceItem = {
              sortIndex: resultSet.getLong(resultSet.getColumnIndex('sort_index')),
              source: normalizeMusicSource(parsed)
            };
            sources.push(orderedSource);
          } catch (error) {
            console.error(`parse music source from sqlite failed: ${JSON.stringify(error)}`);
          }
        } while (resultSet.goToNextRow());
        restored.musicSources = sources
          .sort((left, right) => left.sortIndex - right.sortIndex)
          .map((item) => item.source);
      }
    } finally {
      resultSet.close();
    }
  } catch (error) {
    console.error(`read music sources from sqlite failed: ${JSON.stringify(error)}`);
  }

  try {
    let scriptPredicates = new relationalStore.RdbPredicates(TABLE_MUSIC_SOURCE_SCRIPT);
    let resultSet = await store.query(scriptPredicates);
    try {
      if (resultSet.goToFirstRow()) {
        do {
          let sourceId = resultSet.getString(resultSet.getColumnIndex('source_id'));
          let scriptContent = resultSet.getString(resultSet.getColumnIndex('script_content'));
          if (sourceId.length > 0 && scriptContent.length > 0) {
            restored.musicSourceScripts.set(sourceId, scriptContent);
          }
        } while (resultSet.goToNextRow());
      }
    } finally {
      resultSet.close();
    }
  } catch (error) {
    console.error(`read music source scripts from sqlite failed: ${JSON.stringify(error)}`);
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
  store: relationalStore.RdbStore,
  state: PersistableAppState,
  musicSourceScripts: Map<string, string>
): Promise<void> {
  await persistStateTables(store, state, musicSourceScripts);
}

export function persistAppStateSync(
  store: relationalStore.RdbStore,
  state: PersistableAppState,
  musicSourceScripts: Map<string, string>
): void {
  try {
    store.beginTransaction();
    replaceLocalTracksSync(store, state.localTracks);
    replaceMusicSourcesSync(store, state.musicSources, musicSourceScripts);
    writeStateConfigSync(store, state);
    store.commit();
  } catch (error) {
    try {
      store.rollBack();
    } catch (_) {
      // ignore rollback errors and report the original failure below
    }
    throw error instanceof Error ? error : new Error(JSON.stringify(error));
  }
}

export async function appendPlaybackRecord(
  store: relationalStore.RdbStore,
  record: PlaybackRecordEntry
): Promise<void> {
  await store.insert(
    TABLE_PLAYBACK_RECORD,
    playbackRecordValues(record, Date.now()),
    relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
  );
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
