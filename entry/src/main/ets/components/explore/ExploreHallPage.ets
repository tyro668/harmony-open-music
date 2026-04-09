import { MusicSourceConfig, MusicSourceQuality, MusicSourceTrack, SourceBoardItem } from '../../models/AppModels';
import { filterSupportedExploreSources, sourceDisplayName } from '../../utils/MusicSourceUtils';
import { PlatformSelectorDrawer } from './PlatformSelectorDrawer';

@Component
export struct ExploreHallPage {
  @Prop musicSources: MusicSourceConfig[] = [];
  @Prop activeSourceId: string = '';
  @Prop activeSearchSource: string = '';
  @Prop sourceTracks: MusicSourceTrack[] = [];
  @Prop sourceTracksLoading: boolean = false;
  @Prop sourceSearchKeyword: string = '';
  @Prop sourceCurrentPage: number = 1;
  @Prop sourceTotal: number = 0;
  @Prop sourceBoardList: SourceBoardItem[] = [];
  @Prop sourceBoardsLoading: boolean = false;
  @Prop activeBoardId: string = '';
  @Prop exploreMode: string = 'board';
  @Prop bottomInset: number = 0;
  @Prop sourceImportingTrackKeys: string[] = [];
  @State showPlatformDrawer: boolean = false;
  onGoToProfile: () => void = () => {};
  onSelectSource: (source: MusicSourceConfig) => void = (_: MusicSourceConfig) => {};
  onSelectSubSource: (sourceCode: string) => void = (_: string) => {};
  onToggleMode: () => void = () => {};
  onSearchKeywordChange: (value: string) => void = (_: string) => {};
  onSearch: () => void = () => {};
  onSelectBoard: (board: SourceBoardItem) => void = (_: SourceBoardItem) => {};
  onImportTrack: (track: MusicSourceTrack) => void = (_: MusicSourceTrack) => {};
  onLoadMore: () => void = () => {};
  sourceTrackActionLabel: (track: MusicSourceTrack) => string = (_: MusicSourceTrack) => '导入';
  sourceTrackActionEnabled: (track: MusicSourceTrack) => boolean = (_: MusicSourceTrack) => true;

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

  private isSourceActive(sourceId: string): boolean {
    return this.activeSourceId === sourceId;
  }

  private isPlatformActive(sourceCode: string): boolean {
    return this.activeSearchSource === sourceCode;
  }

  private isBoardActive(boardId: string): boolean {
    return this.activeBoardId === boardId;
  }

  private platformAccentColor(sourceCode: string): string {
    if (sourceCode === 'kw') {
      return '#4CC7D8';
    }
    if (sourceCode === 'kg') {
      return '#53C77A';
    }
    if (sourceCode === 'tx') {
      return '#5EA7FF';
    }
    if (sourceCode === 'mg') {
      return '#F2AE5B';
    }
    if (sourceCode === 'wy') {
      return '#E97B88';
    }
    return '#5DB8C9';
  }

  private currentPlatformCode(): string {
    if (this.activeSearchSource.length > 0) {
      return this.activeSearchSource;
    }
    let subSources = this.availableSubSources();
    return subSources.length > 0 ? subSources[0].source : '';
  }

  private closePlatformDrawer(): void {
    this.showPlatformDrawer = false;
  }

  private openPlatformDrawer(): void {
    if (this.availableSubSources().length === 0) {
      return;
    }
    this.showPlatformDrawer = true;
  }

  private handleSelectSource(source: MusicSourceConfig): void {
    this.showPlatformDrawer = false;
    this.onSelectSource(source);
  }

  private handleSelectSubSource(sourceCode: string): void {
    this.showPlatformDrawer = false;
    this.onSelectSubSource(sourceCode);
  }

  @Builder
  private sourceCatalogChip(source: MusicSourceConfig) {
    Row({ space: 8 }) {
      Row()
        .width(7)
        .height(7)
        .backgroundColor(this.isSourceActive(source.id) ? '#5DB8C9' : '#2B2B2B')
        .borderRadius(4)

      Text(source.name)
        .fontSize(13)
        .fontWeight(this.isSourceActive(source.id) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.isSourceActive(source.id) ? '#F4F8F9' : '#8B8B8B')
    }
    .padding({ left: 14, right: 16, top: 10, bottom: 10 })
    .backgroundColor(this.isSourceActive(source.id) ? '#1B1E23' : '#121212')
    .borderRadius(18)
    .border({
      width: 1,
      color: this.isSourceActive(source.id) ? '#2A4348' : '#202020'
    })
    .onClick(() => {
      this.handleSelectSource(source);
    })
  }

  @Builder
  private platformTriggerIcon() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Row() {
        Image($r('app.media.ic_list'))
          .width(18)
          .height(18)
          .fillColor(this.currentPlatformCode().length > 0 ? this.platformAccentColor(this.currentPlatformCode()) : '#7A8388')
      }
      .width(42)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#17191B')
      .borderRadius(14)
      .border({
        width: 1,
        color: '#24282B'
      })

      if (this.currentPlatformCode().length > 0) {
        Row()
          .width(10)
          .height(10)
          .backgroundColor(this.platformAccentColor(this.currentPlatformCode()))
          .borderRadius(5)
          .border({
            width: 2,
            color: '#17191B'
          })
      }
    }
    .onClick(() => {
      this.openPlatformDrawer();
    })
  }

  @Builder
  private boardChip(board: SourceBoardItem) {
    Row({ space: 8 }) {
      Row()
        .width(7)
        .height(7)
        .backgroundColor(this.isBoardActive(board.bangid) ? '#F7C27A' : '#2C2C2C')
        .borderRadius(4)

      Text(board.name)
        .fontSize(12)
        .fontWeight(this.isBoardActive(board.bangid) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.isBoardActive(board.bangid) ? '#FFF1DE' : '#949494')
    }
    .padding({ left: 14, right: 16, top: 9, bottom: 9 })
    .backgroundColor(this.isBoardActive(board.bangid) ? '#322313' : '#151515')
    .borderRadius(16)
    .border({
      width: 1,
      color: this.isBoardActive(board.bangid) ? '#85582A' : '#222222'
    })
    .onClick(() => {
      this.onSelectBoard(board);
    })
  }

  private resolvedTrackActionLabel(track: MusicSourceTrack): string {
    let importQueueSnapshot = this.sourceImportingTrackKeys.join('|');
    return importQueueSnapshot.length < 0 ? '导入' : this.sourceTrackActionLabel(track);
  }

  private resolvedTrackActionEnabled(track: MusicSourceTrack): boolean {
    let importQueueSnapshot = this.sourceImportingTrackKeys.join('|');
    return importQueueSnapshot.length < 0 ? true : this.sourceTrackActionEnabled(track);
  }

  private importButtonBackground(track: MusicSourceTrack): string {
    let label = this.resolvedTrackActionLabel(track);
    if (label === '已导入') {
      return '#213126';
    }
    if (label === '导入中') {
      return '#1E3A4A';
    }
    return '#5DB8C9';
  }

  private importButtonFontColor(track: MusicSourceTrack): string {
    let label = this.resolvedTrackActionLabel(track);
    if (label === '已导入') {
      return '#9FD3AC';
    }
    if (label === '导入中') {
      return '#7FB2BB';
    }
    return '#050505';
  }

  build() {
    Stack() {
      Column() {
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
                  this.sourceCatalogChip(source)
                }, (source: MusicSourceConfig) => source.id)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 6 })
          }

          if (this.availableSubSources().length > 0) {
            Row({ space: 10 }) {
              this.platformTriggerIcon()

              Row({ space: 8 }) {
                Image($r('app.media.ic_search'))
                  .width(16)
                  .height(16)
                .fillColor(this.sourceSearchKeyword.trim().length > 0 ? '#5DB8C9' : '#5F676C')

              TextInput({ placeholder: '搜索歌曲...', text: this.sourceSearchKeyword })
                .onChange((value: string) => {
                  this.onSearchKeywordChange(value);
                })
                .onSubmit(() => {
                  this.onSearch();
                })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .fontColor('#F0F0F0')
                .placeholderColor('#555')
                .backgroundColor(Color.Transparent)
                .padding({ left: 0, right: 0 })
            }
            .layoutWeight(1)
            .height(42)
            .padding({ left: 14, right: 14 })
            .backgroundColor('#17191B')
            .borderRadius(14)
            .border({
              width: 1,
              color: this.sourceSearchKeyword.trim().length > 0 ? '#27515A' : '#24282B'
            })

            Button('搜索')
              .height(42)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.sourceSearchKeyword.trim().length > 0 ? '#5DB8C9' : '#1E3A4A')
              .fontColor(this.sourceSearchKeyword.trim().length > 0 ? '#050505' : '#7FB2BB')
              .borderRadius(14)
              .padding({ left: 18, right: 18 })
              .onClick(() => {
                this.onSearch();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: this.musicSources.length > 1 ? 0 : 14, bottom: 8 })
        }

          if (this.sourceBoardsLoading) {
            Row() {
              LoadingProgress().width(20).height(20).color('#5DB8C9')
              Text('加载榜单...').fontSize(13).fontColor('#666').margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 24, right: 24, bottom: 12 })
          } else if (this.sourceBoardList.length > 0) {
            Row() {
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.sourceBoardList, (board: SourceBoardItem) => {
                    this.boardChip(board)
                  }, (board: SourceBoardItem) => board.bangid)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }
            .width('100%')
            .padding(4)
            .margin({ left: 24, right: 24, bottom: 12 })
            .backgroundColor('#11100F')
            .borderRadius(20)
            .border({
              width: 1,
              color: '#221E1A'
            })
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
              Text('当前音源暂无可浏览的子源')
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

                    Text(this.resolvedTrackActionLabel(track))
                      .fontSize(13)
                      .fontColor(this.importButtonFontColor(track))
                      .fontWeight(FontWeight.Medium)
                      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                      .backgroundColor(this.importButtonBackground(track))
                      .borderRadius(14)
                      .opacity(this.resolvedTrackActionEnabled(track) ? 1 : 0.86)
                      .onClick(() => {
                        if (this.resolvedTrackActionEnabled(track)) {
                          this.onImportTrack(track);
                        }
                      })
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
              .width('100%')
              .constraintSize({ minHeight: '100%' })
              .justifyContent(FlexAlign.Start)
              .padding({ bottom: this.bottomInset + 20 })
            }
            .scrollBar(BarState.Off)
            .align(Alignment.Top)
            .edgeEffect(EdgeEffect.None)
            .width('100%')
            .layoutWeight(1)
          }
        }
      }
      .width('100%')
      .height('100%')

      if (this.showPlatformDrawer && this.availableSubSources().length > 0) {
        PlatformSelectorDrawer({
          subSources: this.availableSubSources(),
          activeSearchSource: this.activeSearchSource,
          onClose: () => {
            this.closePlatformDrawer();
          },
          onSelectSubSource: (sourceCode: string) => {
            this.handleSelectSubSource(sourceCode);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
