import { MusicSourceQuality, MusicSourceTrack } from '../../models/AppModels';
import { sourceDisplayName } from '../../utils/MusicSourceUtils';

@Component
export struct SourceBrowserPanel {
  title: string = '音源浏览';
  subSources: MusicSourceQuality[] = [];
  activeSearchSource: string = '';
  sourceSearchKeyword: string = '';
  sourceTracks: MusicSourceTrack[] = [];
  sourceTracksLoading: boolean = false;
  sourceTotal: number = 0;
  sourceCurrentPage: number = 1;
  sourceDownloadingId: string = '';
  onClose: () => void = () => {};
  onSelectSubSource: (sourceCode: string) => void = (_: string) => {};
  onSearchKeywordChange: (value: string) => void = (_: string) => {};
  onSearch: () => void = () => {};
  onLoadMore: () => void = () => {};
  onPlayTrack: (track: MusicSourceTrack) => void = (_: MusicSourceTrack) => {};

  private formatDuration(seconds: number): string {
    let minutes = Math.floor(seconds / 60);
    let remainSeconds = seconds % 60;
    return `${minutes}:${remainSeconds < 10 ? '0' : ''}${remainSeconds}`;
  }

  build() {
    Column() {
      Column() {
        Row() {
          Text('← ')
            .fontSize(20)
            .fontColor('#5DB8C9')
            .onClick(() => {
              this.onClose();
            })
          Text(this.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F5F5F5')
            .layoutWeight(1)
          Text('关闭')
            .fontSize(15)
            .fontColor('#5DB8C9')
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 12 })

        if (this.subSources.length > 0) {
          Scroll() {
            Row({ space: 6 }) {
              ForEach(this.subSources, (item: MusicSourceQuality) => {
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
          .padding({ left: 24, right: 24, bottom: 10 })

          Row({ space: 10 }) {
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
              .backgroundColor('#1C1C1C')
              .borderRadius(12)
              .padding({ left: 14, right: 14 })

            Button('搜索')
              .height(40)
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
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 12 })
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
          .padding({ top: 60 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.subSources.length === 0) {
          Column({ space: 10 }) {
            Text('当前音源暂无可搜索曲库')
              .fontSize(18)
              .fontColor('#888')
            Text('Harmony 版当前支持酷我、酷狗、咪咕')
              .fontSize(13)
              .fontColor('#555')
          }
          .width('100%')
          .padding({ top: 60 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.sourceTracks.length === 0) {
          Column({ space: 10 }) {
            Text('搜索歌曲')
              .fontSize(18)
              .fontColor('#888')
            Text('输入关键词搜索音源中的歌曲')
              .fontSize(13)
              .fontColor('#555')
          }
          .width('100%')
          .padding({ top: 60 })
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column({ space: 0 }) {
              ForEach(this.sourceTracks, (track: MusicSourceTrack) => {
                Row({ space: 12 }) {
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
      .width('100%')
      .height('100%')
      .backgroundColor('#111111')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
