export enum MainTab {
  Home = 0,
  Explore = 1,
  Profile = 2
}

export enum AppThemeMode {
  System = 0,
  Light = 1,
  Dark = 2
}

export enum AppThemeAppearance {
  Light = 0,
  Dark = 1
}

export enum LibraryDimension {
  Song = 0,
  Artist = 1,
  Album = 2,
  Folder = 3
}

export enum CollectionMode {
  Library = 0,
  Favorites = 1,
  Recent = 2
}

export enum PlayMode {
  Shuffle = 0,
  Sequential = 1,
  Loop = 2
}

export enum PlaybackCollectionKind {
  All = 0,
  Favorites = 1,
  Album = 2,
  Artist = 3,
  Custom = 4
}

export interface MusicSourceQuality {
  source: string;
  qualitys: string[];
  preferredQuality?: string;
}

export interface MusicSourceConfig {
  id: string;
  name: string;
  description: string;
  author: string;
  homepage: string;
  version: string;
  allowShowUpdateAlert: boolean;
  apiUrl: string;
  apiKey: string;
  musicSources: MusicSourceQuality[];
}

export interface PersistedMusicSourceConfig extends MusicSourceConfig {
  script?: string;
}

export interface MusicSourceTrack {
  id: string;
  name: string;
  singer: string;
  album: string;
  albumId: string;
  duration: number;
  interval: string;
  pic: string;
  source: string;
  songmid: string;
  hash: string;
  types: MusicQualityType[];
  _types: Record<string, MusicQualityType>;
  copyrightId: string;
}

export interface MusicQualityType {
  type: string;
  size: string;
  hash: string;
}

export interface SourceBoardItem {
  id: string;
  name: string;
  bangid: string;
}

export interface MusicSourceUrlResult {
  code: number;
  data: string;
  msg: string;
}

export interface LxSourceParseResult {
  name: string;
  description: string;
  author: string;
  homepage: string;
  version: string;
  apiUrl: string;
  apiKey: string;
  musicSources: MusicSourceQuality[];
}

export interface JsEngineInitInfo {
  sources: Record<string, JsEngineSourceInfo>;
}

export interface JsEngineSourceInfo {
  type: string;
  actions: string[];
  qualitys: string[];
}

export interface JsEngineMusicUrlResult {
  source: string;
  action: string;
  data: JsEngineMusicUrlData;
}

export interface JsEngineMusicUrlData {
  type: string;
  url: string;
}

export interface SourceUpdateAlertPayload {
  name: string;
  log: string;
  updateUrl: string;
}

export interface QuickJsLogPayload {
  type: string;
  log: string;
}

export interface JsEngineResponse {
  requestKey: string;
  status: boolean;
  result: JsEngineMusicUrlResult;
  errorMessage: string;
}

export interface JsEngineHttpRequest {
  requestKey: string;
  url: string;
  options: JsEngineHttpOptions;
}

export interface JsEngineHttpOptions {
  method: string;
  headers: Record<string, string>;
  body: string;
  timeout: number;
  binary: boolean;
}

export interface MusicTrack {
  id: string;
  title: string;
  artist: string;
  album: string;
  durationMs: number;
  folder: string;
  sourceUri: string;
  filePath: string;
  rawFileName: string;
  accentColor: string;
  pic: string;
  isFavorite: boolean;
  isImported: boolean;
  inPlayQueue: boolean;
  playCount: number;
  lastPlayedAt: number;
  sourceImportKey?: string;
}

export interface BaiduPanEntry {
  fsId: string;
  name: string;
  path: string;
  isDirectory: boolean;
  size: number;
  modifiedAt: number;
}

export interface CustomPlaylist {
  id: string;
  name: string;
  trackIds: string[];
}

export interface PlaybackCollectionSummary {
  id: string;
  title: string;
  subtitle: string;
  trackCount: number;
  kind: PlaybackCollectionKind;
}

export interface LibraryGroup {
  id: string;
  title: string;
  subtitle: string;
  count: number;
}

export interface DimensionTabItem {
  value: LibraryDimension;
  label: string;
}

export interface MainTabItem {
  value: MainTab;
  label: string;
  icon: Resource;
}
