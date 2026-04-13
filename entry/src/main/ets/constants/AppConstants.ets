import {
  DimensionTabItem,
  LibraryDimension,
  MainTab,
  MainTabItem,
  MusicTrack,
  SourceBoardItem
} from '../models/AppModels';
import { t } from '../utils/I18nUtil';

export function getBuiltinBoardList(): Record<string, SourceBoardItem[]> {
  return {
    'kw': [
      { id: 'kw__93', name: t('board.kw_1'), bangid: '93' }, { id: 'kw__17', name: t('board.kw_2'), bangid: '17' },
      { id: 'kw__16', name: t('board.kw_3'), bangid: '16' }, { id: 'kw__158', name: t('board.kw_4'), bangid: '158' },
      { id: 'kw__284', name: t('board.kw_5'), bangid: '284' }, { id: 'kw__290', name: t('board.kw_6'), bangid: '290' },
      { id: 'kw__242', name: t('board.kw_7'), bangid: '242' }, { id: 'kw__187', name: t('board.kw_8'), bangid: '187' },
      { id: 'kw__26', name: t('board.kw_9'), bangid: '26' }, { id: 'kw__104', name: t('board.kw_10'), bangid: '104' },
      { id: 'kw__182', name: t('board.kw_11'), bangid: '182' }, { id: 'kw__22', name: t('board.kw_12'), bangid: '22' },
      { id: 'kw__184', name: t('board.kw_13'), bangid: '184' }, { id: 'kw__183', name: t('board.kw_14'), bangid: '183' },
      { id: 'kw__153', name: t('board.kw_15'), bangid: '153' }, { id: 'kw__64', name: t('board.kw_16'), bangid: '64' },
      { id: 'kw__176', name: t('board.kw_17'), bangid: '176' }, { id: 'kw__186', name: t('board.kw_18'), bangid: '186' },
      { id: 'kw__12', name: 'Billboard', bangid: '12' }, { id: 'kw__278', name: t('board.kw_guofeng'), bangid: '278' }
    ],
    'kg': [
      { id: 'kg__8888', name: 'TOP500', bangid: '8888' }, { id: 'kg__6666', name: t('board.kg_2'), bangid: '6666' },
      { id: 'kg__59703', name: t('board.kg_3'), bangid: '59703' }, { id: 'kg__52144', name: t('board.kg_douyin'), bangid: '52144' },
      { id: 'kg__24971', name: t('board.kg_dj'), bangid: '24971' }, { id: 'kg__23784', name: t('board.kg_network'), bangid: '23784' },
      { id: 'kg__31308', name: t('board.kg_mainland'), bangid: '31308' }, { id: 'kg__33160', name: t('board.kg_9'), bangid: '33160' },
      { id: 'kg__31310', name: t('board.kg_11'), bangid: '31310' }, { id: 'kg__33162', name: t('board.kg_acg'), bangid: '33162' },
      { id: 'kg__31311', name: t('board.kg_12'), bangid: '31311' }, { id: 'kg__31312', name: t('board.kg_13'), bangid: '31312' },
      { id: 'kg__33165', name: t('board.kg_cantonese'), bangid: '33165' }, { id: 'kg__51340', name: t('board.kg_sad'), bangid: '51340' },
      { id: 'kg__51341', name: t('board.kg_16'), bangid: '51341' }, { id: 'kg__33163', name: t('board.kg_ost'), bangid: '33163' },
      { id: 'kg__33161', name: t('board.kg_guofeng'), bangid: '33161' }, { id: 'kg__59895', name: t('board.kg_rnb'), bangid: '59895' },
      { id: 'kg__59896', name: t('board.kg_rock'), bangid: '59896' }, { id: 'kg__59900', name: t('board.kg_instrumental'), bangid: '59900' }
    ],
    'tx': [
      { id: 'tx__4', name: t('board.tx_1'), bangid: '4' }, { id: 'tx__26', name: t('board.tx_2'), bangid: '26' },
      { id: 'tx__27', name: t('board.tx_3'), bangid: '27' }, { id: 'tx__62', name: t('board.tx_4'), bangid: '62' },
      { id: 'tx__58', name: t('board.tx_rap'), bangid: '58' }, { id: 'tx__57', name: t('board.tx_edm'), bangid: '57' },
      { id: 'tx__28', name: t('board.tx_network'), bangid: '28' }, { id: 'tx__5', name: t('board.tx_mainland'), bangid: '5' },
      { id: 'tx__3', name: t('board.tx_10'), bangid: '3' }, { id: 'tx__59', name: t('board.tx_hk'), bangid: '59' },
      { id: 'tx__16', name: t('board.tx_11'), bangid: '16' }, { id: 'tx__60', name: t('board.tx_doukai'), bangid: '60' },
      { id: 'tx__29', name: t('board.tx_ost'), bangid: '29' }, { id: 'tx__17', name: t('board.tx_12'), bangid: '17' },
      { id: 'tx__65', name: t('board.tx_guofeng'), bangid: '65' }, { id: 'tx__72', name: t('board.tx_anime'), bangid: '72' }
    ],
    'wy': [
      { id: 'wy__19723756', name: t('board.wy_1'), bangid: '19723756' }, { id: 'wy__3779629', name: t('board.wy_2'), bangid: '3779629' },
      { id: 'wy__2884035', name: t('board.wy_6'), bangid: '2884035' }, { id: 'wy__3778678', name: t('board.wy_3'), bangid: '3778678' },
      { id: 'wy__991319590', name: t('board.wy_13'), bangid: '991319590' }, { id: 'wy__71384707', name: t('board.wy_classical'), bangid: '71384707' },
      { id: 'wy__1978921795', name: t('board.wy_12'), bangid: '1978921795' }, { id: 'wy__71385702', name: t('board.wy_14'), bangid: '71385702' },
      { id: 'wy__745956260', name: t('board.wy_8'), bangid: '745956260' }, { id: 'wy__6723173524', name: t('board.wy_network'), bangid: '6723173524' },
      { id: 'wy__5059644681', name: t('board.wy_9'), bangid: '5059644681' }, { id: 'wy__5059633707', name: t('board.wy_rock'), bangid: '5059633707' },
      { id: 'wy__5059642708', name: t('board.wy_11'), bangid: '5059642708' }, { id: 'wy__5059661515', name: t('board.wy_folk'), bangid: '5059661515' },
      { id: 'wy__6886768100', name: t('board.wy_dj'), bangid: '6886768100' }, { id: 'wy__60198', name: 'Billboard', bangid: '60198' }
    ],
    'mg': [
      { id: 'mg__27553319', name: t('board.mg_1'), bangid: '27553319' }, { id: 'mg__27186466', name: t('board.mg_2'), bangid: '27186466' },
      { id: 'mg__27553408', name: t('board.mg_4'), bangid: '27553408' }, { id: 'mg__75959118', name: t('board.mg_trend'), bangid: '75959118' },
      { id: 'mg__76557036', name: t('board.mg_ringtone'), bangid: '76557036' }, { id: 'mg__76557745', name: t('board.mg_vip'), bangid: '76557745' },
      { id: 'mg__23189800', name: t('board.mg_hk'), bangid: '23189800' }, { id: 'mg__23189399', name: t('board.mg_mainland'), bangid: '23189399' },
      { id: 'mg__83176390', name: t('board.mg_guofeng'), bangid: '83176390' }
    ]
  };
}

export const AUDIO_FILTERS: Array<string> = [t('common.audio_filter') + '|.mp3,.flac,.wav,.m4a,.aac,.ogg,.ape,.amr'];
export const AUDIO_EXTENSIONS: Array<string> = ['.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.ape', '.amr'];
export const COLOR_PALETTE: Array<string> = ['#BC5B12', '#157CB7', '#9C2B25', '#7430D8', '#10934B', '#C21869', '#1C54D6'];
export const APP_BUNDLE_NAME: string = 'com.opensource.metis.music';
export const APP_ENTRY_ABILITY_NAME: string = 'EntryAbility';
export const LIVE_VIEW_ICON_FILE_NAME: string = 'startIcon.png';
export const LIVE_VIEW_ICON_FRAME_PREFIX: string = 'startIcon_frame_';
export const LIVE_VIEW_ICON_FRAME_COUNT: number = 8;
export const LISTENING_SEED_MS: number = 0;
export const ONLINE_DOWNLOAD_MAX_BYTES: number = 64 * 1024 * 1024;
export const PAGE_HEADER_HEIGHT: number = 48;
export const PAGE_HEADER_RADIUS: number = 16;
export const PAGE_HEADER_HORIZONTAL_PADDING: number = 16;
export const PAGE_HEADER_TOP_PADDING: number = 14;
export const PAGE_HEADER_BOTTOM_PADDING: number = 8;
export const PAGE_HEADER_ICON_SIZE: number = 16;
export const PAGE_HEADER_PRIMARY_FONT_SIZE: number = 13;
export const PAGE_HEADER_SECONDARY_FONT_SIZE: number = 12;
export const PAGE_HEADER_BACKGROUND_COLOR: string = '#17191B';
export const PAGE_HEADER_BORDER_COLOR: string = '#24282B';
export const APP_DATABASE_NAME: string = 'local_music_player.db';
export const APP_DATABASE_VERSION: number = 1;
export const PREFERENCES_FILE_NAME: string = 'local_music_player_state';
export const PREF_KEY_LOCAL_TRACKS: string = 'local_tracks';
export const PREF_KEY_RECENT_TRACK_IDS: string = 'recent_track_ids';
export const PREF_KEY_CURRENT_TRACK_ID: string = 'current_track_id';
export const PREF_KEY_COLLECTION_MODE: string = 'collection_mode';
export const PREF_KEY_APP_THEME_MODE: string = 'app_theme_mode';
export const PREF_KEY_MUSIC_SOURCES: string = 'music_sources';
export const PREF_KEY_MUSIC_SOURCE_SCRIPT_PREFIX: string = 'music_source_script_';
export const PREF_KEY_TOTAL_LISTENING_MS: string = 'total_listening_ms';
export const PREF_KEY_PLAY_MODE: string = 'play_mode';
export const PREF_KEY_CUSTOM_PLAYLISTS: string = 'custom_playlists';
export const PREF_KEY_ACTIVE_PLAYBACK_COLLECTION_ID: string = 'active_playback_collection_id';
export const PREF_KEY_PLAYBACK_DRAWER_SHOW_ALBUM_COLLECTIONS: string = 'playback_drawer_show_album_collections';
export const PREF_KEY_PLAYBACK_DRAWER_SHOW_ARTIST_COLLECTIONS: string = 'playback_drawer_show_artist_collections';
export const PREF_KEY_BAIDU_PAN_APP_KEY: string = 'baidu_pan_app_key';
export const PREF_KEY_BAIDU_PAN_ACCESS_TOKEN: string = 'baidu_pan_access_token';
export const PREF_KEY_BAIDU_PAN_CURRENT_DIR: string = 'baidu_pan_current_dir';
export const MAX_RECENT_TRACKS: number = 20;
export const DEFAULT_PLAYBACK_COLLECTION_ID: string = 'builtin:all';
export const MUSIC_SOURCE_INFO_LIMITS: Record<string, number> = {
  'name': 24,
  'description': 36,
  'author': 56,
  'homepage': 1024,
  'version': 36
};
export function getHomeDimensionTabs(): Array<DimensionTabItem> {
  return [
    { value: LibraryDimension.Song, label: t('dimension.song') },
    { value: LibraryDimension.Artist, label: t('dimension.artist') },
    { value: LibraryDimension.Album, label: t('dimension.album') },
    { value: LibraryDimension.Folder, label: t('dimension.folder') }
  ];
}
export function getMainTabs(): Array<MainTabItem> {
  return [
    { value: MainTab.Home, label: t('tab.play'), icon: $r('app.media.ic_home') },
    { value: MainTab.Explore, label: t('tab.explore'), icon: $r('app.media.ic_discover') },
    { value: MainTab.Profile, label: t('tab.profile'), icon: $r('app.media.ic_user') }
  ];
}
export const MINI_PLACEHOLDER_TRACK: MusicTrack = {
  id: 'mini-placeholder',
  title: '',
  artist: '',
  album: '',
  durationMs: 0,
  folder: '',
  sourceUri: '',
  filePath: '',
  rawFileName: '',
  accentColor: '#3A3A3A',
  pic: '',
  isFavorite: false,
  isImported: false,
  inPlayQueue: false,
  playCount: 0,
  lastPlayedAt: 0
};

export function getMiniPlaceholderTrack(): MusicTrack {
  return {
    id: 'mini-placeholder',
    title: t('home.idle_not_playing'),
    artist: t('home.idle_import_hint'),
    album: '',
    durationMs: 0,
    folder: '',
    sourceUri: '',
    filePath: '',
    rawFileName: '',
    accentColor: '#3A3A3A',
    pic: '',
    isFavorite: false,
    isImported: false,
    inPlayQueue: false,
    playCount: 0,
    lastPlayedAt: 0
  };
}
