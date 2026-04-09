import { MusicSourceConfig, MusicSourceQuality, MusicSourceTrack, SourceBoardItem } from '../../models/AppModels';
import { filterSupportedExploreSources, sourceDisplayName } from '../../utils/MusicSourceUtils';

@Component
export struct ExploreHallPage {
  musicSources: MusicSourceConfig[] = [];
  activeSourceId: string = '';
  activeSearchSource: string = '';
  sourceTracks: MusicSourceTrack[] = [];
  sourceTracksLoading: boolean = false;
  sourceSearchKeyword: string = '';
  sourceCurrentPage: number = 1;
  sourceTotal: number = 0;
  sourceDownloadingId: string = '';
  sourceBoardList: SourceBoardItem[] = [];
  sourceBoardsLoading: boolean = false;
  activeBoardId: string = '';
  exploreMode: string = 'board';
  onGoToProfile: () => void = () => {};
  onSelectSource: (source: MusicSourceConfig) => void = (_: MusicSourceConfig) => {};
  onSelectSubSource: (sourceCode: string) => void = (_: string) => {};
  onToggleMode: () => void = () => {};
  onSearchKeywordChange: (value: string) => void = (_: string) => {};
  onSearch: () => void = () => {};
  onSelectBoard: (board: SourceBoardItem) => void = (_: SourceBoardItem) => {};
  onPlayTrack: (track: MusicSourceTrack) => void = (_: MusicSourceTrack) => {};
  onLoadMore: () => void = () => {};

  private activeSource(): MusicSourceConfig | undefined {
    return this.musicSources.find((source: MusicSourceConfig) => source.id === this.activeSourceId);
  }

  private availableSubSources(): MusicSourceQuality[] {
    let source = this.activeSource();
    return source ? filterSupportedExploreSources(source.musicSources) : [];
  }

  private formatDuration(seconds: number): string {
    let minutes = Math.floor(seconds / 60);
    let remainSeconds = seconds % 60;
    return `${minutes}:${remainSeconds < 10 ? '0' : ''}${remainSeconds}`;
  }

  build() {
    Column() {
      Row() {
        Text('音乐厅')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7F7F7')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 8 })

      if (this.musicSources.length === 0) {
        Column({ space: 18 }) {
          Blank().layoutWeight(1)
          Row() {
            Image($r('app.media.ic_discover'))
              .width(42)
              .height(42)
              .opacity(0.6)
          }
          .width(80)
          .height(80)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#111111')
          .borderRadius(40)

          Text('暂无音源')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#888')
          Text('请前往「我的」页面添加自定义音源')
            .fontSize(14)
            .fontColor('#555')
          Button('去我的')
            .height(42)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#1E3A4A')
            .fontColor('#5DB8C9')
            .borderRadius(14)
            .padding({ left: 24, right: 24 })
            .margin({ top: 8 })
            .onClick(() => {
              this.onGoToProfile();
            })
          Blank().layoutWeight(1)
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        if (this.musicSources.length > 1) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.musicSources, (source: MusicSourceConfig) => {
                Text(source.name)
                  .fontSize(14)
                  .fontWeight(this.activeSourceId === source.id ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.activeSourceId === source.id ? '#050505' : '#CCC')
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .backgroundColor(this.activeSourceId === source.id ? '#5DB8C9' : '#1C1C1C')
                  .borderRadius(18)
                  .onClick(() => {
                    this.onSelectSource(source);
                  })
              }, (source: MusicSourceConfig) => source.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .padding({ left: 24, right: 24, top: 4, bottom: 8 })
        }

        if (this.availableSubSources().length > 0) {
          Scroll() {
            Row({ space: 6 }) {
              ForEach(this.availableSubSources(), (item: MusicSourceQuality) => {
                Text(sourceDisplayName(item.source))
                  .fontSize(13)
                  .fontWeight(this.activeSearchSource === item.source ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.activeSearchSource === item.source ? '#050505' : '#AAA')
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .backgroundColor(this.activeSearchSource === item.source ? '#5DB8C9' : '#1C1C1C')
                  .borderRadius(16)
                  .onClick(() => {
                    this.onSelectSubSource(item.source);
                  })
              }, (item: MusicSourceQuality) => item.source)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 8 })
        }

        if (this.availableSubSources().length > 0) {
          Row({ space: 10 }) {
            Text(this.exploreMode === 'board' ? '榜单' : '搜索')
              .fontSize(13)
              .fontColor(this.exploreMode === 'board' ? '#5DB8C9' : '#F0A050')
              .fontWeight(FontWeight.Medium)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor(this.exploreMode === 'board' ? '#1E3A4A' : '#3A2A1A')
              .borderRadius(12)
              .onClick(() => {
                this.onToggleMode();
              })

            if (this.exploreMode === 'search') {
              TextInput({ placeholder: '搜索歌曲...', text: this.sourceSearchKeyword })
                .onChange((value: string) => {
                  this.onSearchKeywordChange(value);
                })
                .onSubmit(() => {
                  this.onSearch();
                })
                .layoutWeight(1)
                .height(38)
                .fontSize(14)
                .fontColor('#F0F0F0')
                .placeholderColor('#555')
                .backgroundColor('#1C1C1C')
                .borderRadius(12)
                .padding({ left: 14, right: 14 })

              Button('搜索')
                .height(38)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('#5DB8C9')
                .fontColor('#050505')
                .borderRadius(12)
                .padding({ left: 16, right: 16 })
                .onClick(() => {
                  this.onSearch();
                })
            }
          }
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 8 })
        }

        if (this.exploreMode === 'board') {
          if (this.sourceBoardsLoading) {
            Row() {
              LoadingProgress().width(20).height(20).color('#5DB8C9')
              Text('加载榜单...').fontSize(13).fontColor('#666').margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 10 })
          } else if (this.sourceBoardList.length > 0) {
            Scroll() {
              Row({ space: 6 }) {
                ForEach(this.sourceBoardList, (board: SourceBoardItem) => {
                  Text(board.name)
                    .fontSize(12)
                    .fontWeight(this.activeBoardId === board.bangid ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.activeBoardId === board.bangid ? '#050505' : '#999')
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .backgroundColor(this.activeBoardId === board.bangid ? '#F0A050' : '#1C1C1C')
                    .borderRadius(14)
                    .onClick(() => {
                      this.onSelectBoard(board);
                    })
                }, (board: SourceBoardItem) => board.bangid)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 10 })
          }
        }

        if (this.sourceTracksLoading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color('#5DB8C9')
            Text('加载中...')
              .fontSize(14)
              .fontColor('#666')
              .margin({ top: 10 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.availableSubSources().length === 0) {
          Column({ space: 10 }) {
            Text('当前音源暂无可浏览曲库')
              .fontSize(16)
              .fontColor('#888')
            Text('Harmony 版音乐厅当前支持酷我、酷狗、咪咕')
              .fontSize(13)
              .fontColor('#555')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.sourceTracks.length === 0 && !this.sourceBoardsLoading) {
          Column({ space: 10 }) {
            if (this.exploreMode === 'board') {
              Text('选择榜单浏览歌曲')
                .fontSize(16)
                .fontColor('#888')
              Text('切换子源或点击榜单查看排行')
                .fontSize(13)
                .fontColor('#555')
            } else {
              Text('搜索发现音乐')
                .fontSize(16)
                .fontColor('#888')
              Text('输入关键词搜索音源中的歌曲')
                .fontSize(13)
                .fontColor('#555')
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column({ space: 0 }) {
              ForEach(this.sourceTracks, (track: MusicSourceTrack, index: number) => {
                Row({ space: 12 }) {
                  if (this.exploreMode === 'board') {
                    Text(`${index + 1}`)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(index < 3 ? '#F0A050' : '#666')
                      .width(28)
                      .textAlign(TextAlign.Center)
                  }
                  Column({ space: 4 }) {
                    Text(track.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#F0F0F0')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Row({ space: 6 }) {
                      Text(track.singer)
                        .fontSize(13)
                        .fontColor('#888')
                        .maxLines(1)
                      if (track.album.length > 0) {
                        Text(`· ${track.album}`)
                          .fontSize(13)
                          .fontColor('#666')
                          .maxLines(1)
                      }
                      if (track.duration > 0) {
                        Text(this.formatDuration(track.duration))
                          .fontSize(12)
                          .fontColor('#555')
                      }
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  if (this.sourceDownloadingId === track.id) {
                    LoadingProgress()
                      .width(24)
                      .height(24)
                      .color('#5DB8C9')
                  } else {
                    Text('播放')
                      .fontSize(13)
                      .fontColor('#050505')
                      .fontWeight(FontWeight.Medium)
                      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                      .backgroundColor('#5DB8C9')
                      .borderRadius(14)
                      .onClick(() => {
                        this.onPlayTrack(track);
                      })
                  }
                }
                .width('100%')
                .padding({ left: 24, right: 24, top: 12, bottom: 12 })
              }, (track: MusicSourceTrack) => track.id)

              if (this.sourceTracks.length < this.sourceTotal) {
                Row() {
                  Button('加载更多')
                    .height(38)
                    .fontSize(14)
                    .backgroundColor('#1E3A4A')
                    .fontColor('#5DB8C9')
                    .borderRadius(14)
                    .padding({ left: 20, right: 20 })
                    .onClick(() => {
                      this.onLoadMore();
                    })
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ top: 16, bottom: 20 })
              }
            }
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
