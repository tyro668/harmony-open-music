import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { WantAgent } from '@ohos.app.ability.wantAgent';
import wantAgent from '@ohos.app.ability.wantAgent';
import { picker, fileUri, fileShare } from '@kit.CoreFileKit';
import { liveViewManager } from '@kit.LiveViewKit';
import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import fs from '@ohos.file.fs';

enum MainTab {
  Home = 0,
  Explore = 1,
  Profile = 2
}

enum LibraryDimension {
  Song = 0,
  Artist = 1,
  Album = 2,
  Folder = 3
}

enum CollectionMode {
  Library = 0,
  Favorites = 1,
  Recent = 2
}

interface MusicTrack {
  id: string;
  title: string;
  artist: string;
  album: string;
  folder: string;
  sourceUri: string;
  filePath: string;
  rawFileName: string;
  accentColor: string;
  isFavorite: boolean;
  isImported: boolean;
  playCount: number;
  lastPlayedAt: number;
}

interface LibraryGroup {
  id: string;
  title: string;
  subtitle: string;
  count: number;
}

interface DimensionTabItem {
  value: LibraryDimension;
  label: string;
}

interface MainTabItem {
  value: MainTab;
  label: string;
  icon: Resource;
}

const AUDIO_FILTERS: Array<string> = ['音乐|.mp3,.flac,.wav,.m4a,.aac,.ogg,.ape,.amr'];
const AUDIO_EXTENSIONS: Array<string> = ['.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.ape', '.amr'];
const COLOR_PALETTE: Array<string> = ['#BC5B12', '#157CB7', '#9C2B25', '#7430D8', '#10934B', '#C21869', '#1C54D6'];
const LISTENING_SEED_MS: number = 128 * 60 * 60 * 1000;
const ONLINE_DOWNLOAD_MAX_BYTES: number = 64 * 1024 * 1024;
const BUNDLED_TRACK_FILE_NAME: string = 'netease_demo_import.mp3';
const PREFERENCES_FILE_NAME: string = 'local_music_player_state';
const PREF_KEY_LOCAL_TRACKS: string = 'local_tracks';
const PREF_KEY_RECENT_TRACK_IDS: string = 'recent_track_ids';
const PREF_KEY_CURRENT_TRACK_ID: string = 'current_track_id';
const PREF_KEY_COLLECTION_MODE: string = 'collection_mode';
const PREF_KEY_TOTAL_LISTENING_MS: string = 'total_listening_ms';
const MAX_RECENT_TRACKS: number = 20;
const HOME_DIMENSION_TABS: Array<DimensionTabItem> = [
  { value: LibraryDimension.Song, label: '歌曲' },
  { value: LibraryDimension.Artist, label: '歌手' },
  { value: LibraryDimension.Album, label: '专辑' },
  { value: LibraryDimension.Folder, label: '文件夹' }
];
const MAIN_TABS: Array<MainTabItem> = [
  { value: MainTab.Home, label: '首页', icon: $r('app.media.ic_home') },
  { value: MainTab.Explore, label: '音乐厅', icon: $r('app.media.ic_discover') },
  { value: MainTab.Profile, label: '我的', icon: $r('app.media.ic_user') }
];
const MINI_PLACEHOLDER_TRACK: MusicTrack = {
  id: 'mini-placeholder',
  title: '夜曲',
  artist: '周杰伦',
  album: '十一月的萧邦',
  folder: '示例歌单',
  sourceUri: '',
  filePath: '',
  rawFileName: '',
  accentColor: '#1E52D6',
  isFavorite: false,
  isImported: false,
  playCount: 0,
  lastPlayedAt: 0
};
const BUNDLED_TRACK: MusicTrack = {
  id: 'bundled-track-netease-demo',
  title: '下载的 MP3',
  artist: '已自动导入',
  album: '本地示例',
  folder: '应用内置',
  sourceUri: '',
  filePath: '',
  rawFileName: BUNDLED_TRACK_FILE_NAME,
  accentColor: '#1C54D6',
  isFavorite: false,
  isImported: true,
  playCount: 0,
  lastPlayedAt: 0
};
const DEMO_TRACKS: Array<MusicTrack> = [
  createDemoTrack('demo-1', 'Hotel California', 'Eagles', 'Hotel California', '经典摇滚', true, '#BC5B12'),
  createDemoTrack('demo-2', 'Shape of You', 'Ed Sheeran', '÷ (Divide)', '欧美流行', false, '#157CB7'),
  createDemoTrack('demo-3', '渡口', '蔡琴', '民歌蔡琴', '华语经典', false, '#9C2B25'),
  createDemoTrack('demo-4', 'Billie Jean', 'Michael Jackson', 'Thriller', '流行金曲', true, '#7430D8'),
  createDemoTrack('demo-5', '挪威的森林', '伍佰 & China Blue', '爱情的尽头', '华语摇滚', false, '#10934B'),
  createDemoTrack('demo-6', 'Bohemian Rhapsody', 'Queen', 'A Night at the Opera', '殿堂现场', false, '#C21869')
];

function createDemoTrack(id: string, title: string, artist: string, album: string, folder: string, isFavorite: boolean,
  accentColor: string): MusicTrack {
  return {
    id: id,
    title: title,
    artist: artist,
    album: album,
    folder: folder,
    sourceUri: '',
    filePath: '',
    rawFileName: '',
    accentColor: accentColor,
    isFavorite: isFavorite,
    isImported: false,
    playCount: 0,
    lastPlayedAt: 0
  };
}

function copyTrack(track: MusicTrack): MusicTrack {
  return {
    id: track.id,
    title: track.title,
    artist: track.artist,
    album: track.album,
    folder: track.folder,
    sourceUri: track.sourceUri,
    filePath: track.filePath,
    rawFileName: track.rawFileName ?? '',
    accentColor: track.accentColor,
    isFavorite: track.isFavorite,
    isImported: track.isImported,
    playCount: track.playCount,
    lastPlayedAt: track.lastPlayedAt
  };
}

function safeDecode(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch (_) {
    return value;
  }
}

function removeExtension(fileName: string): string {
  let lastDotIndex = fileName.lastIndexOf('.');
  if (lastDotIndex <= 0) {
    return fileName;
  }
  return fileName.substring(0, lastDotIndex);
}

function folderFromPath(path: string): string {
  if (!path || path.length === 0) {
    return '本地音乐';
  }
  let parts = path.split('/');
  if (parts.length < 2) {
    return '本地音乐';
  }
  return safeDecode(parts[parts.length - 2]);
}

function colorForSeed(seed: string): string {
  let total = 0;
  for (let index = 0; index < seed.length; index++) {
    total += seed.charCodeAt(index);
  }
  return COLOR_PALETTE[total % COLOR_PALETTE.length];
}

function sanitizeFileName(fileName: string): string {
  let sanitized = fileName.replace(/[\\/:*?"<>|]/g, '_').trim();
  return sanitized.length > 0 ? sanitized : 'online-track.mp3';
}

function originFromUrl(url: string): string {
  let protocolEnd = url.indexOf('://');
  if (protocolEnd < 0) {
    return '';
  }
  let hostStart = protocolEnd + 3;
  let pathStart = url.indexOf('/', hostStart);
  if (pathStart < 0) {
    return url;
  }
  return url.substring(0, pathStart);
}

function fileNameFromUrl(url: string): string {
  let trimmed = url.trim();
  let hashIndex = trimmed.indexOf('#');
  if (hashIndex >= 0) {
    trimmed = trimmed.substring(0, hashIndex);
  }
  let queryIndex = trimmed.indexOf('?');
  if (queryIndex >= 0) {
    trimmed = trimmed.substring(0, queryIndex);
  }
  let lastSlashIndex = trimmed.lastIndexOf('/');
  let fileName = lastSlashIndex >= 0 ? trimmed.substring(lastSlashIndex + 1) : trimmed;
  fileName = sanitizeFileName(safeDecode(fileName));
  let lowerCaseFileName = fileName.toLowerCase();
  let hasSupportedExtension = AUDIO_EXTENSIONS.some((extension: string) => lowerCaseFileName.endsWith(extension));
  if (!hasSupportedExtension) {
    if (fileName.indexOf('.') < 0) {
      fileName = `${fileName}.mp3`;
    } else {
      throw new Error('unsupported online audio extension');
    }
  }
  return fileName;
}

function buildDownloadedTrack(filePath: string, downloadUrl: string, currentCount: number): MusicTrack {
  let fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
  try {
    fileName = fileNameFromUrl(downloadUrl);
  } catch (_) {
    fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
  }
  let baseName = removeExtension(fileName);
  let title = safeDecode(baseName);
  let artist = '在线下载';
  let dividerIndex = title.indexOf(' - ');
  if (dividerIndex > 0 && dividerIndex < title.length - 3) {
    artist = title.substring(0, dividerIndex).trim();
    title = title.substring(dividerIndex + 3).trim();
  }
  return {
    id: `online-${currentCount}-${Date.now()}`,
    title: title.length > 0 ? title : fileName,
    artist: artist,
    album: '网络导入',
    folder: '在线下载',
    sourceUri: '',
    filePath: filePath,
    rawFileName: '',
    accentColor: colorForSeed(downloadUrl),
    isFavorite: false,
    isImported: true,
    playCount: 0,
    lastPlayedAt: 0
  };
}

function buildImportedTrack(uri: string, currentCount: number): MusicTrack {
  let uriObject = new fileUri.FileUri(uri);
  let realPath = uriObject.path;
  let rawName = uriObject.name;
  let fileName = safeDecode(rawName);
  let baseName = removeExtension(fileName);
  let title = baseName;
  let artist = '本地导入';
  let dividerIndex = baseName.indexOf(' - ');
  if (dividerIndex > 0 && dividerIndex < baseName.length - 3) {
    artist = baseName.substring(0, dividerIndex).trim();
    title = baseName.substring(dividerIndex + 3).trim();
  }
  let album = folderFromPath(realPath);
  return {
    id: `local-${currentCount}-${Date.now()}`,
    title: title.length > 0 ? title : fileName,
    artist: artist,
    album: album,
    folder: folderFromPath(realPath),
    sourceUri: uri,
    filePath: realPath,
    rawFileName: '',
    accentColor: colorForSeed(uri),
    isFavorite: false,
    isImported: true,
    playCount: 0,
    lastPlayedAt: 0
  };
}

function formatDuration(ms: number): string {
  if (ms <= 0) {
    return '00:00';
  }
  let totalSeconds = Math.floor(ms / 1000);
  let minutes = Math.floor(totalSeconds / 60);
  let seconds = totalSeconds % 60;
  let minuteText = minutes < 10 ? `0${minutes}` : `${minutes}`;
  let secondText = seconds < 10 ? `0${seconds}` : `${seconds}`;
  return `${minuteText}:${secondText}`;
}

@Entry
@Component
struct Index {
  @State activeMainTab: MainTab = MainTab.Home;
  @State activeLibraryDimension: LibraryDimension = LibraryDimension.Song;
  @State collectionMode: CollectionMode = CollectionMode.Library;
  @State localTracks: Array<MusicTrack> = [];
  @State recentTrackIds: Array<string> = [];
  @State currentTrackId: string = MINI_PLACEHOLDER_TRACK.id;
  @State showSearchBar: boolean = false;
  @State searchKeyword: string = '';
  @State showOnlineDownloadPanel: boolean = false;
  @State onlineDownloadUrl: string = '';
  @State showOnlineDownloadAdvanced: boolean = false;
  @State onlineDownloadReferer: string = 'https://music.163.com/';
  @State onlineDownloadCookie: string = '';
  @State onlineDownloadUserAgent: string = 'Mozilla/5.0 (HarmonyOS Local Music Player)';
  @State isDownloadingOnlineTrack: boolean = false;
  @State onlineDownloadReceivedBytes: number = 0;
  @State onlineDownloadTotalBytes: number = 0;
  @State onlineDownloadTargetFileName: string = '';
  @State isPlaying: boolean = false;
  @State playButtonShowsPause: boolean = false;
  @State isPlayButtonTransitioning: boolean = false;
  @State discRotationAngle: number = 0;
  @State playButtonScale: number = 1;
  @State nextButtonScale: number = 1;
  @State playbackProgressMs: number = 0;
  @State playbackDurationMs: number = 0;
  @State totalListeningMs: number = LISTENING_SEED_MS;

  private player: media.AVPlayer | null = null;
  private openedFile: fs.File | null = null;
  private openedRawFileName: string = '';
  private appPreferences: preferences.Preferences | null = null;
  private playerSession: number = 0;
  private loadedTrackId: string = '';
  private autoPlayAfterPrepare: boolean = false;
  private lastProgressSnapshotMs: number = 0;
  private discRotationTimer: number = -1;
  private hasInitializedState: boolean = false;
  private isRestoringState: boolean = false;
  private isPersistingState: boolean = false;
  private pendingPersistState: boolean = false;
  private liveView: liveViewManager.LiveView | null = null;
  private liveViewSequence: number = 0;

  aboutToAppear(): void {
    if (this.hasInitializedState) {
      return;
    }
    this.hasInitializedState = true;
    void this.initializeAppState();
  }

  aboutToDisappear(): void {
    this.schedulePersistState();
    void this.stopMusicLiveView();
    this.releasePlayer().catch(() => {
      console.error('release player failed');
    });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.pageContent()
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 168 })

      Column({ space: 12 }) {
        this.miniPlayer()
        this.bottomNavigation()
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050505')
  }

  @Builder
  private pageContent() {
    if (this.activeMainTab === MainTab.Home) {
      this.homePage()
    } else if (this.activeMainTab === MainTab.Explore) {
      this.explorePage()
    } else {
      this.profilePage()
    }
  }

  @Builder
  private homePage() {
    Scroll() {
      Column({ space: 4 }) {
        if (this.visibleTracks().length === 0) {
          this.emptyLibraryState('当前没有歌曲', '前往“我的”页导入本地音乐或在线下载音频')
        } else {
          ForEach(this.visibleTracks(), (track: MusicTrack, index: number) => {
            this.trackRow(track, index)
          }, (track: MusicTrack) => track.id)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 14, bottom: 20 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }

  @Builder
  private explorePage() {
    Column() {
      Blank()
        .layoutWeight(1)

      Column({ space: 18 }) {
        Row() {
          Image($r('app.media.ic_discover'))
            .width(46)
            .height(46)
            .opacity(0.7)
        }
        .width(92)
        .height(92)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#111111')
        .borderRadius(46)

        Text('音乐厅')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7F7F7')

        Text('发现更多精选播客与电台')
          .fontSize(16)
          .fontColor('#6C6C6C')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 32, bottom: 24 })
  }

  @Builder
  private profilePage() {
    Scroll() {
      Column({ space: 22 }) {
        Row({ space: 18 }) {
          Row() {
            Image($r('app.media.ic_user'))
              .width(34)
              .height(34)
              .opacity(0.7)
          }
          .width(84)
          .height(84)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#242424')
          .borderRadius(42)

          Column({ space: 8 }) {
            Text('本地听众')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7F7F7')

            Text(`听歌时长 ${this.totalHours()} 小时`)
              .fontSize(15)
              .fontColor('#6C6C6C')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        this.profileActionCard('我的收藏', '快速查看已标记喜欢的歌曲', () => {
          this.collectionMode = CollectionMode.Favorites;
          this.activeLibraryDimension = LibraryDimension.Song;
          this.activeMainTab = MainTab.Home;
          this.schedulePersistState();
        })
        this.profileActionCard('最近播放', '回到最近听过的内容', () => {
          this.collectionMode = CollectionMode.Recent;
          this.activeLibraryDimension = LibraryDimension.Song;
          this.activeMainTab = MainTab.Home;
          this.schedulePersistState();
        })
        this.profileActionCard('本地导入设置', '重新选择本地音乐文件', () => {
          void this.importLocalMusic();
        })
        this.profileActionCard('在线下载导入', '输入音频链接并自动加入曲库', () => {
          this.activeMainTab = MainTab.Home;
          this.collectionMode = CollectionMode.Library;
          this.showOnlineDownloadPanel = true;
        })
        this.profileActionCard('均衡器调节', '当前版本先保留入口', () => {
          this.showToast('均衡器调节将在下一版补充')
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 26, bottom: 20 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }

  @Builder
  private homeHeader() {
    Row() {
      Column({ space: 6 }) {
        Text('本地音乐')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F9F9F9')

        if (this.localTracks.length > 0) {
          Text(`已导入 ${this.localTracks.length} 首音乐`)
            .fontSize(13)
            .fontColor('#6C6C6C')
        } else {
          Text('导入后即可播放手机中的本地歌曲')
            .fontSize(13)
            .fontColor('#6C6C6C')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 12 }) {
        this.iconAction($r('app.media.ic_search'), () => {
          this.showSearchBar = !this.showSearchBar;
          if (!this.showSearchBar) {
            this.searchKeyword = '';
          }
        })
        this.iconAction($r('app.media.ic_plus'), () => {
          void this.importLocalMusic();
        })
      }
    }
    .width('100%')
  }

  @Builder
  private homeDimensionTabs() {
    Column({ space: 16 }) {
      Row({ space: 28 }) {
        ForEach(HOME_DIMENSION_TABS, (tab: DimensionTabItem) => {
          Column({ space: 8 }) {
            Text(tab.label)
              .fontSize(18)
              .fontWeight(this.activeLibraryDimension === tab.value ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.activeLibraryDimension === tab.value ? '#F7F7F7' : '#8A8A8A')

            Row()
              .width(this.activeLibraryDimension === tab.value ? 28 : 0)
              .height(4)
              .borderRadius(2)
              .backgroundColor('#F7F7F7')
          }
          .onClick(() => {
            this.activeLibraryDimension = tab.value;
          })
          .alignItems(HorizontalAlign.Center)
        }, (tab: DimensionTabItem) => `${tab.value}`)
      }
      .justifyContent(FlexAlign.Start)
      .width('100%')

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#1A1A1A')
    }
    .width('100%')
  }

  @Builder
  private searchBox() {
    Row({ space: 10 }) {
      Image($r('app.media.ic_search'))
        .width(18)
        .height(18)
        .opacity(0.6)

      TextInput({ text: this.searchKeyword, placeholder: '搜索歌曲、歌手、专辑或文件夹' })
        .placeholderColor('#5E5E5E')
        .fontSize(15)
        .fontColor('#F5F5F5')
        .backgroundColor(Color.Transparent)
        .caretColor('#F5F5F5')
        .layoutWeight(1)
        .onChange((value: string) => {
          this.searchKeyword = value;
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#141414')
    .borderRadius(20)
  }

  @Builder
  private collectionBanner() {
    Row() {
      Column({ space: 6 }) {
        Text(this.collectionBannerTitle())
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Text(this.collectionBannerDescription())
          .fontSize(13)
          .fontColor('#8B8B8B')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('恢复')
        .fontSize(14)
        .fontColor('#D1D1D1')
        .onClick(() => {
          this.collectionMode = CollectionMode.Library;
          this.schedulePersistState();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#121212')
    .borderRadius(20)
  }

  @Builder
  private importHintCard() {
    Column({ space: 12 }) {
      Text('当前列表展示的是设计稿示例数据')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      Text('点击右上角 + 选择 `mp3 / flac / wav / m4a` 等音频文件后，首页会自动切换为真实本地音乐。')
        .fontSize(13)
        .fontColor('#8B8B8B')
        .lineHeight(20)
      Row({ space: 12 }) {
        Button('导入本地音乐')
          .layoutWeight(1)
          .height(38)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#252525')
          .borderRadius(19)
          .onClick(() => {
            void this.importLocalMusic();
          })

        Button(this.showOnlineDownloadPanel ? '收起在线下载' : '在线下载')
          .layoutWeight(1)
          .height(38)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#1C54D6')
          .borderRadius(19)
          .onClick(() => {
            this.showOnlineDownloadPanel = !this.showOnlineDownloadPanel;
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#101010')
    .borderRadius(22)
  }

  @Builder
  private onlineDownloadCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('在线下载')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          Text('输入可直接访问的音频链接，下载完成后会自动导入到当前曲库。')
            .fontSize(13)
            .fontColor('#8B8B8B')
            .lineHeight(20)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.showOnlineDownloadPanel ? '收起' : '展开')
          .fontSize(14)
          .fontColor('#D0D0D0')
          .onClick(() => {
            if (!this.isDownloadingOnlineTrack) {
              this.showOnlineDownloadPanel = !this.showOnlineDownloadPanel;
            }
          })
      }
      .width('100%')

      TextInput({ text: this.onlineDownloadUrl, placeholder: 'https://example.com/music/demo.mp3' })
        .placeholderColor('#5E5E5E')
        .fontSize(15)
        .fontColor('#F5F5F5')
        .backgroundColor('#141414')
        .caretColor('#F5F5F5')
        .borderRadius(18)
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .enabled(!this.isDownloadingOnlineTrack)
        .onChange((value: string) => {
          this.onlineDownloadUrl = value;
        })

      Button(this.isDownloadingOnlineTrack ? '下载中...' : '下载并导入')
        .width('100%')
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.isDownloadingOnlineTrack ? '#3B3B3B' : '#1C54D6')
        .borderRadius(21)
        .enabled(!this.isDownloadingOnlineTrack)
        .onClick(() => {
          void this.downloadOnlineTrack();
        })

      Row() {
        Text(this.showOnlineDownloadAdvanced ? '收起高级请求头' : '展开高级请求头')
          .fontSize(13)
          .fontColor('#9FA6B2')
          .onClick(() => {
            this.showOnlineDownloadAdvanced = !this.showOnlineDownloadAdvanced;
          })
      }
      .width('100%')

      if (this.showOnlineDownloadAdvanced) {
        Column({ space: 10 }) {
          TextInput({ text: this.onlineDownloadReferer, placeholder: 'Referer，可选，例如 https://music.163.com/' })
            .placeholderColor('#5E5E5E')
            .fontSize(14)
            .fontColor('#F5F5F5')
            .backgroundColor('#141414')
            .caretColor('#F5F5F5')
            .borderRadius(16)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .enabled(!this.isDownloadingOnlineTrack)
            .onChange((value: string) => {
              this.onlineDownloadReferer = value;
            })

          TextInput({ text: this.onlineDownloadCookie, placeholder: 'Cookie，可选，用于需要登录态的下载链接' })
            .placeholderColor('#5E5E5E')
            .fontSize(14)
            .fontColor('#F5F5F5')
            .backgroundColor('#141414')
            .caretColor('#F5F5F5')
            .borderRadius(16)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .enabled(!this.isDownloadingOnlineTrack)
            .onChange((value: string) => {
              this.onlineDownloadCookie = value;
            })

          TextInput({ text: this.onlineDownloadUserAgent, placeholder: 'User-Agent，可选' })
            .placeholderColor('#5E5E5E')
            .fontSize(14)
            .fontColor('#F5F5F5')
            .backgroundColor('#141414')
            .caretColor('#F5F5F5')
            .borderRadius(16)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .enabled(!this.isDownloadingOnlineTrack)
            .onChange((value: string) => {
              this.onlineDownloadUserAgent = value;
            })
        }
        .width('100%')
      }

      if (this.isDownloadingOnlineTrack) {
        Column({ space: 8 }) {
          Row() {
            Text(this.onlineDownloadTargetFileName.length > 0 ? this.onlineDownloadTargetFileName : '正在准备下载')
              .fontSize(13)
              .fontColor('#F0F0F0')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')

          Row()
            .width('100%')
            .height(4)
            .backgroundColor('#2C2C2C')
            .borderRadius(2)

          Row()
            .width(`${this.onlineDownloadProgressRatio() * 100}%`)
            .height(4)
            .backgroundColor('#FFFFFF')
            .borderRadius(2)
            .margin({ top: -12 })

          Text(this.onlineDownloadStatusText())
            .fontSize(12)
            .fontColor('#8B8B8B')
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#101010')
    .borderRadius(22)
  }

  @Builder
  private shuffleRow() {
    Row() {
      Row({ space: 14 }) {
        Row() {
          Image($r('app.media.ic_play'))
            .width(20)
            .height(20)
            .opacity(0.9)
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#242424')
        .borderRadius(24)

        Text('随机播放全部')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F5F5F5')
      }
      .onClick(() => {
        void this.shufflePlayAll();
      })

      Blank()
        .layoutWeight(1)

      Image($r('app.media.ic_list'))
        .width(22)
        .height(22)
        .opacity(0.45)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  private trackRow(track: MusicTrack, index: number) {
    Row({ space: 14 }) {
      this.coverArt(track, 58)

      Column({ space: 6 }) {
        Text(track.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F3F3F3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`${track.artist} · ${track.album}`)
          .fontSize(14)
          .fontColor('#888888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .backgroundColor(this.currentTrackId === track.id ? '#111111' : '#070707')
    .borderRadius(18)
    .border({
      width: this.currentTrackId === track.id ? 1 : 0,
      color: '#232323'
    })
    .opacity(index < 10 ? 1 : 0.98)
    .onClick(() => {
      void this.handleTrackTap(track);
    })
  }

  @Builder
  private groupRow(group: LibraryGroup) {
    Row({ space: 14 }) {
      Column({ space: 6 }) {
        Text(group.title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F3F3F3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(group.subtitle)
          .fontSize(14)
          .fontColor('#818181')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${group.count}`)
        .fontSize(16)
        .fontColor('#666666')

      Image($r('app.media.ic_chevron_right'))
        .width(16)
        .height(16)
        .opacity(0.5)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor('#111111')
    .borderRadius(22)
    .onClick(() => {
      this.activeLibraryDimension = LibraryDimension.Song;
      this.searchKeyword = group.title;
      this.showSearchBar = true;
    })
  }

  @Builder
  private emptyLibraryState(title: string, description: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F0F0F0')
      Text(description)
        .fontSize(14)
        .fontColor('#777777')
        .textAlign(TextAlign.Center)
        .lineHeight(22)
    }
    .width('100%')
    .padding({ top: 56, bottom: 56, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private profileActionCard(title: string, subtitle: string, action: () => void) {
    Row({ space: 14 }) {
      Column({ space: 6 }) {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F5F5F5')
        Text(subtitle)
          .fontSize(13)
          .fontColor('#707070')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.ic_chevron_right'))
        .width(18)
        .height(18)
        .opacity(0.45)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 20, bottom: 20 })
    .backgroundColor('#171717')
    .borderRadius(24)
    .onClick(action)
  }

  @Builder
  private miniPlayer() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Row({ space: 16 }) {
        this.discArtwork(this.currentTrack())

        Column({ space: 4 }) {
          Text(this.currentTrack().title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F4F4F4')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.currentTrack().artist)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B7B7B7')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.miniControlCircle(() => {
          void this.handleMiniPlayPause();
        }, (event: TouchEvent) => {
          this.handlePlayButtonTouch(event);
        })
        this.miniControlPlain($r('app.media.ic_next'), () => {
          void this.playNextTrack();
        }, this.nextButtonScale, (event: TouchEvent) => {
          this.handleNextButtonTouch(event);
        })
      }
      .width('100%')
      .padding({ left: 20, right: 18, top: 20, bottom: 26 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(4)
          .backgroundColor('#444341')
          .borderRadius(2)

        Row()
          .width(`${this.progressRatio() * 100}%`)
          .height(4)
          .backgroundColor('#F1F1F1')
          .borderRadius(2)
      }
      .width('100%')
      .height(4)
      .padding({ left: 20, right: 20, bottom: 12 })
    }
    .width('100%')
    .backgroundColor('#2A2928')
    .borderRadius(28)
    .border({
      width: 1,
      color: '#3A3937'
    })
  }

  @Builder
  private bottomNavigation() {
    Row() {
      ForEach(MAIN_TABS, (tab: MainTabItem) => {
        Column({ space: 8 }) {
          Image(tab.icon)
            .width(24)
            .height(24)
            .opacity(this.activeMainTab === tab.value ? 1 : 0.42)
          Text(tab.label)
            .fontSize(13)
            .fontWeight(this.activeMainTab === tab.value ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.activeMainTab === tab.value ? '#F7F7F7' : '#707070')
        }
        .layoutWeight(1)
        .height(74)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.activeMainTab = tab.value;
        })
      }, (tab: MainTabItem) => `${tab.value}`)
    }
    .width('100%')
    .padding({ left: 6, right: 6 })
    .backgroundColor('#141518')
    .borderRadius(26)
  }

  @Builder
  private coverArt(track: MusicTrack, size: number) {
    Row() {
      Image($r('app.media.ic_note'))
        .width(size * 0.34)
        .height(size * 0.34)
        .opacity(0.45)
    }
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(track.accentColor)
    .borderRadius(14)
  }

  @Builder
  private discArtwork(track: MusicTrack) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(60)
        .height(60)
        .backgroundColor(track.accentColor)
        .borderRadius(30)
        .linearGradient({
          angle: 135,
          colors: [
            [track.accentColor, 0],
            ['#17306C', 1]
          ]
        })

      Row()
        .width(40)
        .height(40)
        .borderRadius(20)
        .border({
          width: 1,
          color: '#FFFFFF16'
        })
        .opacity(0.65)

      Row()
        .width(12)
        .height(12)
        .backgroundColor('#121212')
        .borderRadius(6)
    }
    .width(60)
    .height(60)
    .rotate({
      angle: this.discRotationAngle,
      x: 0,
      y: 0,
      z: 1,
      centerX: '50%',
      centerY: '50%'
    })
    .animation({
      duration: 140,
      curve: Curve.Linear
    })
  }

  @Builder
  private iconAction(icon: Resource, action: () => void) {
    Row() {
      Image(icon)
        .width(24)
        .height(24)
        .opacity(0.85)
    }
    .width(36)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .onClick(action)
  }

  @Builder
  private miniControlCircle(action: () => void, touchAction: (event: TouchEvent) => void) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(52)
        .height(52)
        .backgroundColor(this.isPlaying ? '#4B4A49' : '#434240')
        .borderRadius(26)
        .opacity(this.isPlayButtonTransitioning ? 0.88 : 1)

      if (this.isPlaying) {
        Row()
          .width(52)
          .height(52)
          .borderRadius(26)
          .border({
            width: 1,
            color: '#5B5A58'
          })
          .opacity(0.6)
      }

      if (this.playButtonShowsPause) {
        Image($r('app.media.ic_pause'))
          .width(20)
          .height(20)
          .opacity(0.96)
          .transition({ type: TransitionType.Insert, opacity: 0 })
          .transition({ type: TransitionType.Delete, opacity: 0 })
      } else {
        Image($r('app.media.ic_play'))
          .width(20)
          .height(20)
          .opacity(0.96)
          .transition({ type: TransitionType.Insert, opacity: 0 })
          .transition({ type: TransitionType.Delete, opacity: 0 })
      }
    }
    .width(52)
    .height(52)
    .scale({
      x: this.playButtonScale,
      y: this.playButtonScale
    })
    .animation({
      duration: 140,
      curve: Curve.EaseOut
    })
    .onTouch(touchAction)
    .onClick(action)
  }

  @Builder
  private miniControlPlain(icon: Resource, action: () => void, scaleValue: number, touchAction: (event: TouchEvent) => void) {
    Row() {
      Image(icon)
        .width(24)
        .height(24)
        .opacity(0.86)
    }
    .width(42)
    .height(42)
    .justifyContent(FlexAlign.Center)
    .scale({
      x: scaleValue,
      y: scaleValue
    })
    .animation({
      duration: 140,
      curve: Curve.EaseOut
    })
    .onTouch(touchAction)
    .onClick(action)
  }

  private totalHours(): number {
    return Math.floor(this.totalListeningMs / (60 * 60 * 1000));
  }

  private onlineDownloadProgressRatio(): number {
    if (this.onlineDownloadTotalBytes <= 0) {
      return this.isDownloadingOnlineTrack ? 0.12 : 0;
    }
    let ratio = this.onlineDownloadReceivedBytes / this.onlineDownloadTotalBytes;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  private formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  private onlineDownloadStatusText(): string {
    if (!this.isDownloadingOnlineTrack) {
      return '等待输入音频链接';
    }
    if (this.onlineDownloadTotalBytes > 0) {
      return `${Math.floor(this.onlineDownloadProgressRatio() * 100)}% · ${this.formatFileSize(this.onlineDownloadReceivedBytes)} / ${this.formatFileSize(this.onlineDownloadTotalBytes)}`;
    }
    return `${this.formatFileSize(this.onlineDownloadReceivedBytes)} · 正在下载`;
  }

  private onlineDownloadFailureToast(error: Object): string {
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

  private collectionBannerTitle(): string {
    if (this.collectionMode === CollectionMode.Favorites) {
      return '我的收藏';
    }
    if (this.collectionMode === CollectionMode.Recent) {
      return '最近播放';
    }
    return '本地全部';
  }

  private collectionBannerDescription(): string {
    if (this.collectionMode === CollectionMode.Favorites) {
      return '这里只显示你收藏过的歌曲';
    }
    if (this.collectionMode === CollectionMode.Recent) {
      return '按照最近播放顺序回看你的收听记录';
    }
    return '展示当前导入的全部音乐';
  }

  private librarySource(): Array<MusicTrack> {
    return this.localTracks.length > 0 ? this.localTracks : DEMO_TRACKS;
  }

  private visibleTracks(): Array<MusicTrack> {
    let source = this.librarySource();
    let filtered: Array<MusicTrack> = [];
    if (this.collectionMode === CollectionMode.Favorites) {
      source.forEach((track: MusicTrack) => {
        if (track.isFavorite) {
          filtered.push(track);
        }
      });
    } else if (this.collectionMode === CollectionMode.Recent) {
      this.recentTrackIds.forEach((trackId: string) => {
        let found = source.find((track: MusicTrack) => track.id === trackId);
        if (found) {
          filtered.push(found);
        }
      });
    } else {
      filtered = source.slice();
    }

    let keyword = this.searchKeyword.trim().toLowerCase();
    if (keyword.length === 0) {
      return filtered;
    }
    return filtered.filter((track: MusicTrack) => {
      let target = `${track.title} ${track.artist} ${track.album} ${track.folder}`.toLowerCase();
      return target.indexOf(keyword) >= 0;
    });
  }

  private visibleGroups(): Array<LibraryGroup> {
    let groups: Record<string, Array<MusicTrack>> = {};
    this.visibleTracks().forEach((track: MusicTrack) => {
      let key = track.artist;
      if (this.activeLibraryDimension === LibraryDimension.Album) {
        key = track.album;
      } else if (this.activeLibraryDimension === LibraryDimension.Folder) {
        key = track.folder;
      }
      if (!groups[key]) {
        groups[key] = [];
      }
      groups[key].push(track);
    });

    let result: Array<LibraryGroup> = [];
    Object.keys(groups).forEach((key: string) => {
      let items = groups[key];
      let subtitle = `${items[0].artist} · ${items[0].album}`;
      if (this.activeLibraryDimension === LibraryDimension.Artist) {
        subtitle = `${items[0].album} 等 ${items.length} 首`;
      } else if (this.activeLibraryDimension === LibraryDimension.Album) {
        subtitle = `${items[0].artist} · ${items.length} 首音乐`;
      } else if (this.activeLibraryDimension === LibraryDimension.Folder) {
        subtitle = `${items.length} 首音乐`;
      }
      result.push({
        id: `${this.activeLibraryDimension}-${key}`,
        title: key,
        subtitle: subtitle,
        count: items.length
      });
    });

    return result.sort((left: LibraryGroup, right: LibraryGroup) => right.count - left.count);
  }

  private currentTrack(): MusicTrack {
    let allTracks = this.librarySource().concat([MINI_PLACEHOLDER_TRACK]);
    let found = allTracks.find((track: MusicTrack) => track.id === this.currentTrackId);
    if (found) {
      return found;
    }
    return MINI_PLACEHOLDER_TRACK;
  }

  private progressRatio(): number {
    if (this.playbackDurationMs <= 0) {
      return 0.32;
    }
    let ratio = this.playbackProgressMs / this.playbackDurationMs;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  private setMiniPlayButtonState(showPause: boolean, transitioning: boolean): void {
    this.playButtonShowsPause = showPause;
    this.isPlayButtonTransitioning = transitioning;
  }

  private handlePlayButtonTouch(event: TouchEvent): void {
    this.playButtonScale = event.type === TouchType.Down ? 0.92 : 1;
  }

  private handleNextButtonTouch(event: TouchEvent): void {
    this.nextButtonScale = event.type === TouchType.Down ? 0.92 : 1;
  }

  private async buildLiveViewClickAction(): Promise<WantAgent> {
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: 'com.opensource.metis.music',
          abilityName: 'EntryAbility'
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(wantAgentInfo);
  }

  private async startMusicLiveView(track: MusicTrack): Promise<void> {
    try {
      let enabled = await liveViewManager.isLiveViewEnabled();
      if (!enabled) {
        console.info('live view is disabled');
        return;
      }
      this.liveViewSequence = 1;
      let clickAction = await this.buildLiveViewClickAction();
      let view: liveViewManager.LiveView = {
        id: 1,
        event: 'MUSIC_PLAYBACK',
        sequence: this.liveViewSequence,
        liveViewData: {
          primary: {
            title: track.title,
            content: [{ text: `${track.artist} - ${track.album}` }],
            keepTime: 0,
            clickAction: clickAction,
            layoutData: {
              layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
              progress: 0,
              color: '#F1F1F1',
              backgroundColor: '#444341'
            }
          },
          capsule: {
            type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
            status: 1,
            title: track.title,
            icon: 'entry/resources/base/media/startIcon.png',
            backgroundColor: '#2A2928'
          }
        }
      };
      this.liveView = view;
      await liveViewManager.startLiveView(this.liveView);
      console.info('startMusicLiveView succeeded');
    } catch (error) {
      console.error(`startMusicLiveView failed: ${JSON.stringify(error)}`);
    }
  }

  private async updateMusicLiveView(playing: boolean): Promise<void> {
    if (!this.liveView) {
      return;
    }
    try {
      this.liveViewSequence += 1;
      this.liveView.sequence = this.liveViewSequence;
      let track = this.currentTrack();
      let progress = this.playbackDurationMs > 0 ? Math.round(this.playbackProgressMs / this.playbackDurationMs * 100) : 0;
      this.liveView.liveViewData.primary.title = track.title;
      this.liveView.liveViewData.primary.content = [{ text: `${track.artist} - ${track.album}` }];
      this.liveView.liveViewData.primary.layoutData = {
        layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
        progress: progress,
        color: '#F1F1F1',
        backgroundColor: '#444341'
      };
      this.liveView.liveViewData.capsule = {
        type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
        status: 1,
        title: playing ? '正在播放' : '已暂停',
        icon: 'entry/resources/base/media/startIcon.png',
        backgroundColor: '#2A2928'
      };
      await liveViewManager.updateLiveView(this.liveView);
    } catch (error) {
      console.error(`updateMusicLiveView failed: ${JSON.stringify(error)}`);
    }
  }

  private async stopMusicLiveView(): Promise<void> {
    if (!this.liveView) {
      return;
    }
    try {
      this.liveViewSequence += 1;
      this.liveView.sequence = this.liveViewSequence;
      this.liveView.liveViewData.primary.layoutData = {
        layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
        progress: 100,
        color: '#F1F1F1',
        backgroundColor: '#444341'
      };
      this.liveView.liveViewData.capsule = {
        type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
        status: 1,
        title: '播放结束',
        icon: 'entry/resources/base/media/startIcon.png',
        backgroundColor: '#2A2928'
      };
      await liveViewManager.stopLiveView(this.liveView);
      this.liveView = null;
      console.info('stopMusicLiveView succeeded');
    } catch (error) {
      console.error(`stopMusicLiveView failed: ${JSON.stringify(error)}`);
      this.liveView = null;
    }
  }

  private async startBackgroundTask(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await backgroundTaskManager.startBackgroundRunning(context);
      console.info('startBackgroundTask succeeded');
    } catch (error) {
      console.error(`startBackgroundTask failed: ${JSON.stringify(error)}`);
    }
  }

  private async stopBackgroundTask(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await backgroundTaskManager.stopBackgroundRunning(context);
      console.info('stopBackgroundTask succeeded');
    } catch (error) {
      console.error(`stopBackgroundTask failed: ${JSON.stringify(error)}`);
    }
  }

  private startDiscRotation(): void {
    if (this.discRotationTimer >= 0) {
      return;
    }
    this.discRotationTimer = setInterval(() => {
      this.discRotationAngle = (this.discRotationAngle + 8) % 360;
    }, 120) as number;
  }

  private stopDiscRotation(): void {
    if (this.discRotationTimer < 0) {
      return;
    }
    clearInterval(this.discRotationTimer);
    this.discRotationTimer = -1;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1800
      });
    } catch (error) {
      console.error(`show toast failed: ${JSON.stringify(error)}`);
    }
  }

  private async initializeAppState(): Promise<void> {
    let insertedBundledTrack = false;
    this.isRestoringState = true;
    try {
      await this.restorePersistedState();
      await this.activatePersistedUriPermissions();
      insertedBundledTrack = this.ensureBundledTrackInLibrary();
    } catch (error) {
      console.error(`initialize app state failed: ${JSON.stringify(error)}`);
    } finally {
      this.isRestoringState = false;
    }
    if (insertedBundledTrack) {
      this.schedulePersistState();
    }
  }

  private async ensurePreferences(): Promise<preferences.Preferences> {
    if (this.appPreferences !== null) {
      return this.appPreferences;
    }
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.appPreferences = await preferences.getPreferences(context, { name: PREFERENCES_FILE_NAME });
      return this.appPreferences;
    } catch (error) {
      console.error(`ensure preferences failed: ${JSON.stringify(error)}`);
      throw new Error('ensure preferences failed');
    }
  }

  private async restorePersistedState(): Promise<void> {
    let store = await this.ensurePreferences();
    try {
      let trackPayload = await store.get(PREF_KEY_LOCAL_TRACKS, '[]');
      if (typeof trackPayload === 'string' && trackPayload.length > 0) {
        try {
          let parsedTracks = JSON.parse(trackPayload) as Array<MusicTrack>;
          this.localTracks = parsedTracks.map((track: MusicTrack) => copyTrack(track));
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
          this.recentTrackIds = parsedRecent.slice(0, MAX_RECENT_TRACKS);
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
        this.currentTrackId = currentTrackPayload;
      }
    } catch (error) {
      console.error(`read current track from preferences failed: ${JSON.stringify(error)}`);
    }

    try {
      let collectionModePayload = await store.get(PREF_KEY_COLLECTION_MODE, CollectionMode.Library);
      if (typeof collectionModePayload === 'number' && collectionModePayload >= CollectionMode.Library &&
        collectionModePayload <= CollectionMode.Recent) {
        this.collectionMode = collectionModePayload as CollectionMode;
      }
    } catch (error) {
      console.error(`read collection mode from preferences failed: ${JSON.stringify(error)}`);
    }

    try {
      let listeningPayload = await store.get(PREF_KEY_TOTAL_LISTENING_MS, LISTENING_SEED_MS);
      if (typeof listeningPayload === 'number' && listeningPayload > 0) {
        this.totalListeningMs = listeningPayload;
      }
    } catch (error) {
      console.error(`read listening duration from preferences failed: ${JSON.stringify(error)}`);
    }

    if (this.localTracks.length > 0) {
      let hasTrack = this.localTracks.some((track: MusicTrack) => track.id === this.currentTrackId);
      if (!hasTrack) {
        this.currentTrackId = this.localTracks[0].id;
      }
    } else {
      this.currentTrackId = MINI_PLACEHOLDER_TRACK.id;
    }
  }

  private createReadPolicies(uris: Array<string>): Array<fileShare.PolicyInfo> {
    let policies: Array<fileShare.PolicyInfo> = [];
    uris.forEach((uri: string) => {
      policies.push({
        uri: uri,
        operationMode: fileShare.OperationMode.READ_MODE
      });
    });
    return policies;
  }

  private async persistUriPermissions(uris: Array<string>): Promise<void> {
    if (uris.length === 0) {
      return;
    }
    try {
      let policies = this.createReadPolicies(uris);
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
    } catch (error) {
      console.error(`persist uri permissions failed: ${JSON.stringify(error)}`);
      this.showToast('已导入歌曲，但系统未保存文件授权');
    }
  }

  private async activatePersistedUriPermissions(): Promise<void> {
    let trackUris = this.localTracks.filter((track: MusicTrack) => track.sourceUri.length > 0)
      .map((track: MusicTrack) => track.sourceUri);
    if (trackUris.length === 0) {
      return;
    }
    try {
      let policies = this.createReadPolicies(trackUris);
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

  private schedulePersistState(): void {
    if (this.isRestoringState || !this.hasInitializedState) {
      return;
    }
    void this.persistState();
  }

  private async persistState(): Promise<void> {
    if (this.isPersistingState) {
      this.pendingPersistState = true;
      return;
    }
    this.isPersistingState = true;
    try {
      do {
        this.pendingPersistState = false;
        let store = await this.ensurePreferences();
        let serializedTracks = JSON.stringify(this.localTracks.map((track: MusicTrack) => copyTrack(track)));
        let serializedRecent = JSON.stringify(this.recentTrackIds);
        await store.put(PREF_KEY_LOCAL_TRACKS, serializedTracks);
        await store.put(PREF_KEY_RECENT_TRACK_IDS, serializedRecent);
        await store.put(PREF_KEY_CURRENT_TRACK_ID, this.currentTrackId);
        await store.put(PREF_KEY_COLLECTION_MODE, this.collectionMode);
        await store.put(PREF_KEY_TOTAL_LISTENING_MS, this.totalListeningMs);
        await store.flush();
      } while (this.pendingPersistState);
    } catch (error) {
      console.error(`persist state failed: ${JSON.stringify(error)}`);
    } finally {
      this.isPersistingState = false;
    }
  }

  private async importLocalMusic(): Promise<void> {
    try {
      let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      let options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 50;
      options.fileSuffixFilters = AUDIO_FILTERS;
      let documentPicker = new picker.DocumentViewPicker(context);
      let uris = await documentPicker.select(options);
      if (!uris || uris.length === 0) {
        return;
      }

      let mergedTracks = this.localTracks.slice();
      let importedCount = 0;
      let newUris: Array<string> = [];
      uris.forEach((uri: string) => {
        let duplicated = mergedTracks.some((track: MusicTrack) => track.sourceUri === uri);
        if (!duplicated) {
          mergedTracks.unshift(buildImportedTrack(uri, mergedTracks.length));
          importedCount += 1;
          newUris.push(uri);
        }
      });

      this.localTracks = mergedTracks;
      this.collectionMode = CollectionMode.Library;
      this.activeLibraryDimension = LibraryDimension.Song;
      this.activeMainTab = MainTab.Home;
      if (this.localTracks.length > 0 && this.currentTrackId === MINI_PLACEHOLDER_TRACK.id) {
        this.currentTrackId = this.localTracks[0].id;
      }
      await this.persistUriPermissions(newUris);
      this.schedulePersistState();
      if (importedCount > 0) {
        this.showToast(`已导入 ${importedCount} 首本地音乐`);
      } else {
        this.showToast('这些歌曲已经在列表里了');
      }
    } catch (error) {
      console.error(`import local music failed: ${JSON.stringify(error)}`);
      this.showToast('导入失败，请重新选择文件');
    }
  }

  private async downloadOnlineTrack(): Promise<void> {
    if (this.isDownloadingOnlineTrack) {
      return;
    }
    let trimmedUrl = this.onlineDownloadUrl.trim();
    if (!(trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://'))) {
      this.showToast('请输入有效的 http 或 https 音频链接');
      return;
    }

    let targetFileName = '';
    try {
      targetFileName = `${Date.now()}-${fileNameFromUrl(trimmedUrl)}`;
    } catch (_) {
      this.showToast('当前仅支持直接下载 mp3 等音频链接');
      return;
    }

    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let downloadDirectory = `${context.filesDir}/downloads`;
    let targetPath = `${downloadDirectory}/${targetFileName}`;
    let referer = this.onlineDownloadReferer.trim();
    let cookie = this.onlineDownloadCookie.trim();
    let userAgent = this.onlineDownloadUserAgent.trim();
    let requestHeaders: Record<string, string> = {
      'Accept': 'audio/*,*/*',
      'User-Agent': userAgent.length > 0 ? userAgent : 'Mozilla/5.0 (HarmonyOS Local Music Player)'
    };
    if (referer.length > 0) {
      requestHeaders['Referer'] = referer;
      let origin = originFromUrl(referer);
      if (origin.length > 0) {
        requestHeaders['Origin'] = origin;
      }
    }
    if (cookie.length > 0) {
      requestHeaders['Cookie'] = cookie;
    }

    this.isDownloadingOnlineTrack = true;
    this.showOnlineDownloadPanel = true;
    this.onlineDownloadTargetFileName = targetFileName;
    this.onlineDownloadReceivedBytes = 0;
    this.onlineDownloadTotalBytes = 0;

    try {
      if (!fs.accessSync(downloadDirectory)) {
        fs.mkdirSync(downloadDirectory, true);
      }
    } catch (error) {
      let errorText = JSON.stringify(error);
      if (errorText.indexOf('13900015') < 0) {
        console.error(`create download directory failed: ${errorText}`);
      }
    }

    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(trimmedUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 60000,
        connectTimeout: 60000,
        usingCache: false,
        priority: 1000,
        maxLimit: ONLINE_DOWNLOAD_MAX_BYTES,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        header: requestHeaders
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`http status ${response.responseCode}`);
      }

      let audioBuffer = response.result as ArrayBuffer;
      if (!(audioBuffer instanceof ArrayBuffer) || audioBuffer.byteLength === 0) {
        throw new Error('empty response buffer');
      }
      this.onlineDownloadReceivedBytes = audioBuffer.byteLength;
      this.onlineDownloadTotalBytes = audioBuffer.byteLength;
      if (fs.accessSync(targetPath)) {
        fs.unlinkSync(targetPath);
      }
      let outputFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try {
        fs.writeSync(outputFile.fd, audioBuffer);
      } finally {
        fs.closeSync(outputFile);
      }

      let importedTrack = buildDownloadedTrack(targetPath, trimmedUrl, this.localTracks.length);
      let alreadyExists = this.localTracks.some((track: MusicTrack) => track.filePath === targetPath);
      if (!alreadyExists) {
        this.localTracks = [importedTrack].concat(this.localTracks);
      }
      this.collectionMode = CollectionMode.Library;
      this.activeLibraryDimension = LibraryDimension.Song;
      this.activeMainTab = MainTab.Home;
      this.currentTrackId = alreadyExists ? this.currentTrackId : importedTrack.id;
      this.schedulePersistState();
      this.showToast('在线音频已下载并导入');
      this.onlineDownloadUrl = '';
    } catch (error) {
      console.error(`download online track failed: ${JSON.stringify(error)} / ${String(error)}`);
      this.showToast(this.onlineDownloadFailureToast(error as Object));
    } finally {
      httpRequest.destroy();
      this.isDownloadingOnlineTrack = false;
      this.onlineDownloadReceivedBytes = 0;
      this.onlineDownloadTotalBytes = 0;
      this.onlineDownloadTargetFileName = '';
    }
  }

  private async handleTrackTap(track: MusicTrack): Promise<void> {
    let isLoadedTrack = this.loadedTrackId === track.id;
    this.currentTrackId = track.id;
    this.pushRecentTrack(track.id);
    if (!track.isImported) {
      this.isPlaying = false;
      this.setMiniPlayButtonState(false, false);
      this.playbackProgressMs = 0;
      this.playbackDurationMs = 0;
      this.showToast('示例歌曲仅用于展示，导入本地音乐后即可真实播放');
      return;
    }

    if (this.player && isLoadedTrack && this.isPlaying) {
      await this.pauseCurrentTrack();
      return;
    }

    if (this.player && isLoadedTrack && !this.isPlaying && this.player.state === 'paused') {
      await this.resumeCurrentTrack();
      return;
    }

    await this.startTrackPlayback(track);
  }

  private async handleMiniPlayPause(): Promise<void> {
    let track = this.currentTrack();
    if (!track.isImported) {
      if (this.localTracks.length === 0) {
        this.showToast('请先导入本地音乐，再从底部播放器继续播放');
        return;
      }
      await this.startTrackPlayback(this.localTracks[0]);
      return;
    }

    let isLoadedTrack = this.loadedTrackId === track.id;
    if (this.isPlaying && isLoadedTrack) {
      await this.pauseCurrentTrack();
    } else if (this.player && isLoadedTrack && this.player.state === 'paused') {
      await this.resumeCurrentTrack();
    } else {
      await this.startTrackPlayback(track);
    }
  }

  private async shufflePlayAll(): Promise<void> {
    if (this.localTracks.length === 0) {
      this.showToast('请先导入本地音乐，再开始随机播放');
      return;
    }
    let randomIndex = Math.floor(Math.random() * this.localTracks.length);
    await this.startTrackPlayback(this.localTracks[randomIndex]);
  }

  private async playNextTrack(): Promise<void> {
    if (this.localTracks.length === 0) {
      this.showToast('当前没有可连续播放的本地音乐');
      return;
    }
    let index = this.localTracks.findIndex((track: MusicTrack) => track.id === this.currentTrackId);
    let nextIndex = index >= 0 ? (index + 1) % this.localTracks.length : 0;
    await this.startTrackPlayback(this.localTracks[nextIndex]);
  }

  private toggleFavorite(trackId: string): void {
    let localIndex = this.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (localIndex >= 0) {
      let updatedTracks = this.localTracks.slice();
      let selectedTrack = copyTrack(updatedTracks[localIndex]);
      selectedTrack.isFavorite = !selectedTrack.isFavorite;
      updatedTracks[localIndex] = selectedTrack;
      this.localTracks = updatedTracks;
      this.schedulePersistState();
      this.showToast(updatedTracks[localIndex].isFavorite ? '已加入收藏' : '已取消收藏');
      return;
    }

    let demoIndex = DEMO_TRACKS.findIndex((track: MusicTrack) => track.id === trackId);
    if (demoIndex >= 0) {
      DEMO_TRACKS[demoIndex].isFavorite = !DEMO_TRACKS[demoIndex].isFavorite;
      this.showToast(DEMO_TRACKS[demoIndex].isFavorite ? '已标记示例收藏' : '已取消示例收藏');
    }
  }

  private pushRecentTrack(trackId: string): void {
    let nextRecent = this.recentTrackIds.filter((id: string) => id !== trackId);
    nextRecent.unshift(trackId);
    this.recentTrackIds = nextRecent.slice(0, MAX_RECENT_TRACKS);
    this.schedulePersistState();
  }

  private ensureBundledTrackInLibrary(): boolean {
    let exists = this.localTracks.some((track: MusicTrack) => track.rawFileName === BUNDLED_TRACK_FILE_NAME);
    if (exists) {
      return false;
    }
    let updatedTracks = this.localTracks.slice();
    updatedTracks.unshift(copyTrack(BUNDLED_TRACK));
    this.localTracks = updatedTracks;
    if (this.currentTrackId === MINI_PLACEHOLDER_TRACK.id) {
      this.currentTrackId = BUNDLED_TRACK.id;
    }
    return true;
  }

  private async startTrackPlayback(track: MusicTrack): Promise<void> {
    this.currentTrackId = track.id;
    this.pushRecentTrack(track.id);
    this.playbackProgressMs = 0;
    this.playbackDurationMs = 0;
    this.lastProgressSnapshotMs = 0;
    this.setMiniPlayButtonState(true, true);
    this.schedulePersistState();
    void this.startMusicLiveView(track);

    await this.releasePlayer();
    this.autoPlayAfterPrepare = true;
    this.setMiniPlayButtonState(true, true);

    try {
      let player = await media.createAVPlayer();
      let sessionId = this.playerSession + 1;
      this.playerSession = sessionId;
      this.player = player;
      this.loadedTrackId = track.id;
      this.registerPlayerCallbacks(player, sessionId);
      await this.attachTrackSource(player, track);
      this.markTrackPlayed(track.id);
    } catch (error) {
      console.error(`start playback failed: ${JSON.stringify(error)}`);
      await this.releasePlayer();
      this.setMiniPlayButtonState(false, false);
      this.showToast('这首歌曲暂时无法播放，请尝试其他文件');
    }
  }

  private async attachTrackSource(player: media.AVPlayer, track: MusicTrack): Promise<void> {
    try {
      console.info(`attachTrackSource start: trackId=${track.id}, raw=${track.rawFileName}, sourceUri=${track.sourceUri}, filePath=${track.filePath}`);
      if (track.rawFileName.length > 0) {
        let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        let rawFileDescriptor = await context.resourceManager.getRawFd(track.rawFileName);
        this.openedRawFileName = track.rawFileName;
        player.fdSrc = rawFileDescriptor;
        return;
      }
      let playablePath = this.resolveTrackPlayablePath(track);
      try {
        let file = fs.openSync(playablePath, fs.OpenMode.READ_ONLY);
        let stat = fs.statSync(file.fd);
        this.openedFile = file;
        player.fdSrc = {
          fd: file.fd,
          offset: 0,
          length: stat.size
        };
        console.info(`attachTrackSource using fdSrc: trackId=${track.id}, path=${playablePath}, length=${stat.size}`);
        return;
      } catch (fdError) {
        if (!this.canUseSandboxUri(track, playablePath)) {
          throw new Error(`open track file failed: ${String(fdError)}`);
        }
        let sandboxUri = fileUri.getUriFromPath(playablePath);
        player.url = sandboxUri;
        console.info(`attachTrackSource fallback to sandbox uri: trackId=${track.id}, uri=${sandboxUri}`);
      }
    } catch (error) {
      console.error(`attach track source failed: ${JSON.stringify(error)}`);
      throw new Error('attach track source failed');
    }
  }

  private resolveTrackPlayablePath(track: MusicTrack): string {
    if (track.filePath.length > 0) {
      return track.filePath;
    }
    if (track.sourceUri.length > 0) {
      return new fileUri.FileUri(track.sourceUri).path;
    }
    throw new Error('track source path is empty');
  }

  private canUseSandboxUri(track: MusicTrack, playablePath: string): boolean {
    if (track.sourceUri.length > 0) {
      return false;
    }
    if (track.filePath.length === 0) {
      return false;
    }
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return playablePath.startsWith(context.filesDir);
  }

  private registerPlayerCallbacks(player: media.AVPlayer, sessionId: number): void {
    player.on('stateChange', async (state: string) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      console.info(`player state changed: session=${sessionId}, state=${state}, loadedTrackId=${this.loadedTrackId}`);
      if (state === 'initialized') {
        try {
          await player.prepare();
        } catch (error) {
          console.error(`prepare failed: ${JSON.stringify(error)}`);
          this.showToast('播放器准备失败');
        }
      } else if (state === 'prepared') {
        this.playbackDurationMs = player.duration > 0 ? player.duration : this.playbackDurationMs;
        if (this.autoPlayAfterPrepare) {
          this.autoPlayAfterPrepare = false;
          try {
            await player.play();
          } catch (error) {
            console.error(`play failed: ${JSON.stringify(error)}`);
            this.showToast('开始播放失败');
          }
        }
      } else if (state === 'playing') {
        this.isPlaying = true;
        this.setMiniPlayButtonState(true, false);
        this.startDiscRotation();
        void this.updateMusicLiveView(true);
        void this.startBackgroundTask();
      } else if (state === 'paused') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        void this.updateMusicLiveView(false);
      } else if (state === 'completed') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        this.playbackProgressMs = this.playbackDurationMs;
        void this.stopMusicLiveView();
        void this.stopBackgroundTask();
        void this.playNextTrack();
      } else if (state === 'released') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        void this.stopMusicLiveView();
        void this.stopBackgroundTask();
      } else if (state === 'error') {
        this.isPlaying = false;
        this.setMiniPlayButtonState(false, false);
        this.stopDiscRotation();
        void this.stopMusicLiveView();
        void this.stopBackgroundTask();
        this.showToast('播放器发生错误');
      }
    });

    player.on('timeUpdate', (time: number) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      if (time >= this.lastProgressSnapshotMs && time - this.lastProgressSnapshotMs < 5000) {
        this.totalListeningMs += time - this.lastProgressSnapshotMs;
      }
      this.lastProgressSnapshotMs = time;
      this.playbackProgressMs = time;
      // 每5秒更新一次LiveView进度
      if (time % 5000 < 100) {
        void this.updateMusicLiveView(this.isPlaying);
      }
    });

    player.on('durationUpdate', (duration: number) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      this.playbackDurationMs = duration;
    });

    player.on('error', (error: BusinessError) => {
      if (sessionId !== this.playerSession) {
        return;
      }
      console.error(`player error: ${error.code}, ${error.message}`);
      this.showToast('音频文件格式暂不支持');
    });
  }

  private markTrackPlayed(trackId: string): void {
    let trackIndex = this.localTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (trackIndex < 0) {
      return;
    }
    let updated = this.localTracks.slice();
    let selectedTrack = copyTrack(updated[trackIndex]);
    selectedTrack.playCount = selectedTrack.playCount + 1;
    selectedTrack.lastPlayedAt = Date.now();
    updated[trackIndex] = selectedTrack;
    this.localTracks = updated;
    this.schedulePersistState();
  }

  private async pauseCurrentTrack(): Promise<void> {
    if (!this.player) {
      return;
    }
    this.setMiniPlayButtonState(false, true);
    try {
      await this.player.pause();
      this.isPlaying = false;
      this.setMiniPlayButtonState(false, false);
    } catch (error) {
      console.error(`pause failed: ${JSON.stringify(error)}`);
      this.setMiniPlayButtonState(true, false);
    }
  }

  private async resumeCurrentTrack(): Promise<void> {
    if (!this.player) {
      return;
    }
    this.setMiniPlayButtonState(true, true);
    try {
      await this.player.play();
      this.isPlaying = true;
      this.setMiniPlayButtonState(true, false);
    } catch (error) {
      console.error(`resume failed: ${JSON.stringify(error)}`);
      this.setMiniPlayButtonState(false, false);
    }
  }

  private async releasePlayer(): Promise<void> {
    let existingPlayer = this.player;
    let existingFile = this.openedFile;
    let existingRawFileName = this.openedRawFileName;
    this.player = null;
    this.openedFile = null;
    this.openedRawFileName = '';
    this.loadedTrackId = '';
    this.isPlaying = false;
    this.setMiniPlayButtonState(false, false);
    this.autoPlayAfterPrepare = false;
    this.lastProgressSnapshotMs = 0;
    this.stopDiscRotation();
    if (existingPlayer) {
      try {
        await existingPlayer.release();
      } catch (error) {
        console.error(`release existing player failed: ${JSON.stringify(error)}`);
      }
    }
    if (existingFile) {
      try {
        fs.closeSync(existingFile);
      } catch (error) {
        console.error(`close file failed: ${JSON.stringify(error)}`);
      }
    }
    if (existingRawFileName.length > 0) {
      try {
        let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        context.resourceManager.closeRawFdSync(existingRawFileName);
      } catch (error) {
        console.error(`close raw file failed: ${JSON.stringify(error)}`);
      }
    }
  }
}
