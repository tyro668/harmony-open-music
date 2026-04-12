import { image } from '@kit.ImageKit';

import { AppThemeAppearance, MusicTrack } from '../../models/AppModels';
import { formatDurationMs } from '../../utils/TrackUtils';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct CarTrackList {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop tracks: MusicTrack[] = [];
  @Prop currentTrackId: string = '';
  @Prop coveredTrackIds: string[] = [];
  @Prop title: string = '播放列表';
  onTrackTap: (track: MusicTrack) => void = (_: MusicTrack) => {};
  coverForTrack: (trackId: string) => image.PixelMap | null = (_: string) => null;

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private hasTrackCover(trackId: string): boolean {
    return this.coveredTrackIds.indexOf(trackId) >= 0 && this.coverForTrack(trackId) !== null;
  }

  private trackCover(trackId: string): image.PixelMap {
    return this.coverForTrack(trackId) as image.PixelMap;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().primaryText)
        Text(`${this.tracks.length} 首`)
          .fontSize(16)
          .fontColor(this.theme().tertiaryText)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 32, right: 32, top: 16, bottom: 8 })

      // 歌曲列表
      List({ space: 0 }) {
        ForEach(this.tracks, (track: MusicTrack) => {
          ListItem() {
            Row() {
              // 封面缩略图
              Stack() {
                Row()
                  .width(56)
                  .height(56)
                  .borderRadius(10)
                  .backgroundColor(this.theme().controlSecondaryBackground)
                if (this.hasTrackCover(track.id)) {
                  Image(this.trackCover(track.id))
                    .width(56)
                    .height(56)
                    .borderRadius(10)
                    .objectFit(ImageFit.Cover)
                }
              }
              .margin({ right: 16 })

              // 歌曲信息
              Column({ space: 4 }) {
                Text(track.title)
                  .fontSize(18)
                  .fontWeight(this.currentTrackId === track.id ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.currentTrackId === track.id ? this.theme().accent : this.theme().primaryText)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(track.artist)
                  .fontSize(14)
                  .fontColor(this.theme().secondaryText)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              // 时长
              Text(formatDurationMs(track.durationMs))
                .fontSize(14)
                .fontColor(this.theme().tertiaryText)
                .margin({ left: 12 })
            }
            .width('100%')
            .height(80)
            .padding({ left: 32, right: 32 })
            .alignItems(VerticalAlign.Center)
            .backgroundColor(this.currentTrackId === track.id ? this.theme().activeRowBackground : Color.Transparent)
            .borderRadius(12)
            .onClick(() => {
              this.onTrackTap(track);
            })
          }
        }, (track: MusicTrack) => track.id)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .divider({
        strokeWidth: 1,
        color: this.theme().divider,
        startMargin: 104,
        endMargin: 32
      })
    }
    .width('100%')
    .layoutWeight(1)
  }
}
