import { image } from '@kit.ImageKit';

import { AppThemeAppearance, MusicTrack, PlayMode } from '../../models/AppModels';
import { formatDurationMs } from '../../utils/TrackUtils';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct CarPlayerBar {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop track: MusicTrack = {
    id: '', title: '', artist: '', album: '', durationMs: 0,
    folder: '', sourceUri: '', filePath: '', rawFileName: '',
    accentColor: '#333333', pic: '', isFavorite: false,
    isImported: false, inPlayQueue: false, playCount: 0, lastPlayedAt: 0
  };
  @Prop isPlaying: boolean = false;
  @Prop playbackProgressMs: number = 0;
  @Prop playbackDurationMs: number = 0;
  @Prop playMode: PlayMode = PlayMode.Sequential;
  @Prop coveredTrackIds: string[] = [];
  onPlayPause: () => void = () => {};
  onPrevious: () => void = () => {};
  onNext: () => void = () => {};
  onSeekChange: (value: number, mode: SliderChangeMode) => void = (_: number, __: SliderChangeMode) => {};
  onSelectPlayMode: () => void = () => {};
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

  private playModeIcon(): Resource {
    if (this.playMode === PlayMode.Shuffle) {
      return $r('app.media.ic_shuffle');
    }
    if (this.playMode === PlayMode.Loop) {
      return $r('app.media.ic_loop');
    }
    return $r('app.media.ic_sequential');
  }

  build() {
    Column() {
      // 进度条
      Slider({
        value: this.playbackProgressMs,
        min: 0,
        max: this.playbackDurationMs > 0 ? this.playbackDurationMs : 1,
        step: 1000,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .trackThickness(6)
        .blockSize({ width: 20, height: 20 })
        .trackColor(this.theme().sliderTrack)
        .selectedColor(this.theme().sliderActiveTrack)
        .blockColor(this.theme().sliderThumb)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.onSeekChange(value, mode);
        })

      // 主控制区
      Row() {
        // 封面
        Stack() {
          Row()
            .width(80)
            .height(80)
            .borderRadius(12)
            .backgroundColor(this.theme().controlSecondaryBackground)
          if (this.hasTrackCover(this.track.id)) {
            Image(this.trackCover(this.track.id))
              .width(80)
              .height(80)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          }
        }
        .margin({ right: 20 })

        // 歌曲信息
        Column({ space: 6 }) {
          Text(this.track.title)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.track.artist)
            .fontSize(16)
            .fontColor(this.theme().secondaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 12 }) {
            Text(formatDurationMs(this.playbackProgressMs))
              .fontSize(14)
              .fontColor(this.theme().tertiaryText)
            Text(formatDurationMs(this.playbackDurationMs))
              .fontSize(14)
              .fontColor(this.theme().tertiaryText)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 播放模式
        Row() {
          Image(this.playModeIcon())
            .width(28)
            .height(28)
            .fillColor(this.theme().controlSecondaryForeground)
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme().controlSecondaryBackground)
        .onClick(() => this.onSelectPlayMode())

        // 上一首
        Row() {
          Image($r('app.media.ic_previous'))
            .width(28)
            .height(28)
            .fillColor(this.theme().controlSecondaryForeground)
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme().controlSecondaryBackground)
        .onClick(() => this.onPrevious())

        // 播放/暂停
        Row() {
          Image(this.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
            .width(32)
            .height(32)
            .fillColor(this.theme().controlPrimaryForeground)
        }
        .width(80)
        .height(80)
        .borderRadius(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme().controlPrimaryBackground)
        .onClick(() => this.onPlayPause())

        // 下一首
        Row() {
          Image($r('app.media.ic_next'))
            .width(28)
            .height(28)
            .fillColor(this.theme().controlSecondaryForeground)
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme().controlSecondaryBackground)
        .onClick(() => this.onNext())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: 32, right: 32, top: 16, bottom: 16 })
    .backgroundColor(this.theme().panelBackground)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({
      radius: 16,
      color: this.theme().floatingSurfaceShadow,
      offsetX: 0,
      offsetY: -4
    })
  }
}
