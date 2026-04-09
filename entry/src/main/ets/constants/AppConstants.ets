import {
  DimensionTabItem,
  LibraryDimension,
  MainTab,
  MainTabItem,
  MusicTrack,
  SourceBoardItem
} from '../models/AppModels';

export const BUILTIN_BOARD_LIST: Record<string, SourceBoardItem[]> = {
  'kw': [
    { id: 'kw__93', name: '飙升榜', bangid: '93' }, { id: 'kw__17', name: '新歌榜', bangid: '17' },
    { id: 'kw__16', name: '热歌榜', bangid: '16' }, { id: 'kw__158', name: '抖音热歌榜', bangid: '158' },
    { id: 'kw__284', name: '热评榜', bangid: '284' }, { id: 'kw__290', name: 'ACG新歌榜', bangid: '290' },
    { id: 'kw__242', name: '电音榜', bangid: '242' }, { id: 'kw__187', name: '流行趋势榜', bangid: '187' },
    { id: 'kw__26', name: '经典怀旧榜', bangid: '26' }, { id: 'kw__104', name: '华语榜', bangid: '104' },
    { id: 'kw__182', name: '粤语榜', bangid: '182' }, { id: 'kw__22', name: '欧美榜', bangid: '22' },
    { id: 'kw__184', name: '韩语榜', bangid: '184' }, { id: 'kw__183', name: '日语榜', bangid: '183' },
    { id: 'kw__153', name: '网红新歌榜', bangid: '153' }, { id: 'kw__64', name: '影视金曲榜', bangid: '64' },
    { id: 'kw__176', name: 'DJ嗨歌榜', bangid: '176' }, { id: 'kw__186', name: 'ACG神曲榜', bangid: '186' },
    { id: 'kw__12', name: 'Billboard榜', bangid: '12' }, { id: 'kw__278', name: '古风音乐榜', bangid: '278' }
  ],
  'kg': [
    { id: 'kg__8888', name: 'TOP500', bangid: '8888' }, { id: 'kg__6666', name: '飙升榜', bangid: '6666' },
    { id: 'kg__59703', name: '蜂鸟流行音乐榜', bangid: '59703' }, { id: 'kg__52144', name: '抖音热歌榜', bangid: '52144' },
    { id: 'kg__24971', name: 'DJ热歌榜', bangid: '24971' }, { id: 'kg__23784', name: '网络红歌榜', bangid: '23784' },
    { id: 'kg__31308', name: '内地榜', bangid: '31308' }, { id: 'kg__33160', name: '电音榜', bangid: '33160' },
    { id: 'kg__31310', name: '欧美榜', bangid: '31310' }, { id: 'kg__33162', name: 'ACG新歌榜', bangid: '33162' },
    { id: 'kg__31311', name: '韩国榜', bangid: '31311' }, { id: 'kg__31312', name: '日本榜', bangid: '31312' },
    { id: 'kg__33165', name: '粤语金曲榜', bangid: '33165' }, { id: 'kg__51340', name: '伤感榜', bangid: '51340' },
    { id: 'kg__51341', name: '民谣榜', bangid: '51341' }, { id: 'kg__33163', name: '影视金曲榜', bangid: '33163' },
    { id: 'kg__33161', name: '古风新歌榜', bangid: '33161' }, { id: 'kg__59895', name: 'R&B榜', bangid: '59895' },
    { id: 'kg__59896', name: '摇滚榜', bangid: '59896' }, { id: 'kg__59900', name: '纯音乐榜', bangid: '59900' }
  ],
  'tx': [
    { id: 'tx__4', name: '流行指数榜', bangid: '4' }, { id: 'tx__26', name: '热歌榜', bangid: '26' },
    { id: 'tx__27', name: '新歌榜', bangid: '27' }, { id: 'tx__62', name: '飙升榜', bangid: '62' },
    { id: 'tx__58', name: '说唱榜', bangid: '58' }, { id: 'tx__57', name: '喜力电音榜', bangid: '57' },
    { id: 'tx__28', name: '网络歌曲榜', bangid: '28' }, { id: 'tx__5', name: '内地榜', bangid: '5' },
    { id: 'tx__3', name: '欧美榜', bangid: '3' }, { id: 'tx__59', name: '香港地区榜', bangid: '59' },
    { id: 'tx__16', name: '韩国榜', bangid: '16' }, { id: 'tx__60', name: '抖快榜', bangid: '60' },
    { id: 'tx__29', name: '影视金曲榜', bangid: '29' }, { id: 'tx__17', name: '日本榜', bangid: '17' },
    { id: 'tx__65', name: '国风热歌榜', bangid: '65' }, { id: 'tx__72', name: '动漫音乐榜', bangid: '72' }
  ],
  'wy': [
    { id: 'wy__19723756', name: '飙升榜', bangid: '19723756' }, { id: 'wy__3779629', name: '新歌榜', bangid: '3779629' },
    { id: 'wy__2884035', name: '原创榜', bangid: '2884035' }, { id: 'wy__3778678', name: '热歌榜', bangid: '3778678' },
    { id: 'wy__991319590', name: '说唱榜', bangid: '991319590' }, { id: 'wy__71384707', name: '古典榜', bangid: '71384707' },
    { id: 'wy__1978921795', name: '电音榜', bangid: '1978921795' }, { id: 'wy__71385702', name: 'ACG榜', bangid: '71385702' },
    { id: 'wy__745956260', name: '韩语榜', bangid: '745956260' }, { id: 'wy__6723173524', name: '网络热歌榜', bangid: '6723173524' },
    { id: 'wy__5059644681', name: '日语榜', bangid: '5059644681' }, { id: 'wy__5059633707', name: '摇滚榜', bangid: '5059633707' },
    { id: 'wy__5059642708', name: '国风榜', bangid: '5059642708' }, { id: 'wy__5059661515', name: '民谣榜', bangid: '5059661515' },
    { id: 'wy__6886768100', name: '中文DJ榜', bangid: '6886768100' }, { id: 'wy__60198', name: 'Billboard榜', bangid: '60198' }
  ],
  'mg': [
    { id: 'mg__27553319', name: '新歌榜', bangid: '27553319' }, { id: 'mg__27186466', name: '热歌榜', bangid: '27186466' },
    { id: 'mg__27553408', name: '原创榜', bangid: '27553408' }, { id: 'mg__75959118', name: '音乐风向榜', bangid: '75959118' },
    { id: 'mg__23189800', name: '港台榜', bangid: '23189800' }, { id: 'mg__23189399', name: '内地榜', bangid: '23189399' },
    { id: 'mg__19190036', name: '欧美榜', bangid: '19190036' }, { id: 'mg__83176390', name: '国风金曲榜', bangid: '83176390' }
  ]
};

export const AUDIO_FILTERS: Array<string> = ['音乐|.mp3,.flac,.wav,.m4a,.aac,.ogg,.ape,.amr'];
export const AUDIO_EXTENSIONS: Array<string> = ['.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.ape', '.amr'];
export const COLOR_PALETTE: Array<string> = ['#BC5B12', '#157CB7', '#9C2B25', '#7430D8', '#10934B', '#C21869', '#1C54D6'];
export const LISTENING_SEED_MS: number = 128 * 60 * 60 * 1000;
export const ONLINE_DOWNLOAD_MAX_BYTES: number = 64 * 1024 * 1024;
export const PREFERENCES_FILE_NAME: string = 'local_music_player_state';
export const PREF_KEY_LOCAL_TRACKS: string = 'local_tracks';
export const PREF_KEY_RECENT_TRACK_IDS: string = 'recent_track_ids';
export const PREF_KEY_CURRENT_TRACK_ID: string = 'current_track_id';
export const PREF_KEY_COLLECTION_MODE: string = 'collection_mode';
export const PREF_KEY_MUSIC_SOURCES: string = 'music_sources';
export const PREF_KEY_MUSIC_SOURCE_SCRIPT_PREFIX: string = 'music_source_script_';
export const PREF_KEY_TOTAL_LISTENING_MS: string = 'total_listening_ms';
export const PREF_KEY_PLAY_MODE: string = 'play_mode';
export const MAX_RECENT_TRACKS: number = 20;
export const MUSIC_SOURCE_INFO_LIMITS: Record<string, number> = {
  'name': 24,
  'description': 36,
  'author': 56,
  'homepage': 1024,
  'version': 36
};
export const HOME_DIMENSION_TABS: Array<DimensionTabItem> = [
  { value: LibraryDimension.Song, label: '歌曲' },
  { value: LibraryDimension.Artist, label: '歌手' },
  { value: LibraryDimension.Album, label: '专辑' },
  { value: LibraryDimension.Folder, label: '文件夹' }
];
export const MAIN_TABS: Array<MainTabItem> = [
  { value: MainTab.Home, label: '首页', icon: $r('app.media.ic_home') },
  { value: MainTab.Explore, label: '音乐厅', icon: $r('app.media.ic_discover') },
  { value: MainTab.Profile, label: '我的', icon: $r('app.media.ic_user') }
];
export const MINI_PLACEHOLDER_TRACK: MusicTrack = {
  id: 'mini-placeholder',
  title: '未在播放',
  artist: '导入本地音乐后即可播放',
  album: '',
  folder: '',
  sourceUri: '',
  filePath: '',
  rawFileName: '',
  accentColor: '#3A3A3A',
  isFavorite: false,
  isImported: false,
  playCount: 0,
  lastPlayedAt: 0
};
