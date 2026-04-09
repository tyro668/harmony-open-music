import { image } from '@kit.ImageKit';

import { MusicTrack } from '../../models/AppModels';
import { formatDurationMs } from '../../utils/TrackUtils';

@Component
export struct MiniPlayerBar {
  @Prop track: MusicTrack = {
    id: '',
    title: '',
    artist: '',
    album: '',
    folder: '',
    sourceUri: '',
    filePath: '',
    rawFileName: '',
    accentColor: '#333333',
    pic: '',
    isFavorite: false,
    isImported: false,
    inPlayQueue: false,
    playCount: 0,
    lastPlayedAt: 0
  };
  @Prop discRotationAngle: number = 0;
  @Prop isPlaying: boolean = false;
  @Prop isPlayButtonTransitioning: boolean = false;
  @Prop playButtonShowsPause: boolean = false;
  @Prop playButtonScale: number = 1;
  @Prop nextButtonScale: number = 1;
  @Prop progressRatio: number = 0;
  @Prop playbackProgressMs: number = 0;
  @Prop playbackDurationMs: number = 0;
  @Prop coveredTrackIds: string[] = [];
  onPlayPause: () => void = () => {};
  onNext: () => void = () => {};
  onSeekChange: (value: number, mode: SliderChangeMode) => void = (_: number, __: SliderChangeMode) => {};
  onPlayButtonTouch: (event: TouchEvent) => void = (_: TouchEvent) => {};
  onNextButtonTouch: (event: TouchEvent) => void = (_: TouchEvent) => {};
  coverForTrack: (trackId: string) => image.PixelMap | null = (_: string) => null;

  private hasTrackCover(trackId: string): boolean {
    return this.coveredTrackIds.indexOf(trackId) >= 0 && this.coverForTrack(trackId) !== null;
  }

  private trackCover(trackId: string): image.PixelMap {
    return this.coverForTrack(trackId) as image.PixelMap;
  }

  private progressTimeText(): string {
    return formatDurationMs(this.playbackProgressMs);
  }

  private durationTimeText(): string {
    return formatDurationMs(this.playbackDurationMs);
  }

  @Builder
  private discArtwork() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(60)
        .height(60)
        .backgroundColor(this.track.accentColor)
        .borderRadius(30)
        .linearGradient({
          angle: 135,
          colors: [
            [this.track.accentColor, 0],
            ['#17306C', 1]
          ]
        })

      if (this.hasTrackCover(this.track.id)) {
        Image(this.trackCover(this.track.id))
          .width(46)
          .height(46)
          .objectFit(ImageFit.Cover)
          .borderRadius(23)

        Row()
          .width(48)
          .height(48)
          .borderRadius(24)
          .border({
            width: 1,
            color: '#FFFFFF24'
          })
      } else if (this.track.pic.length > 0) {
        Image(this.track.pic)
          .width(46)
          .height(46)
          .objectFit(ImageFit.Cover)
          .borderRadius(23)

        Row()
          .width(48)
          .height(48)
          .borderRadius(24)
          .border({
            width: 1,
            color: '#FFFFFF24'
          })
      } else {
        Row()
          .width(40)
          .height(40)
          .borderRadius(20)
          .border({
            width: 1,
            color: '#FFFFFF16'
          })
          .opacity(0.65)
      }

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
  private controlCircle(action: () => void, touchAction: (event: TouchEvent) => void) {
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
    .scale({ x: this.playButtonScale, y: this.playButtonScale })
    .animation({
      duration: 140,
      curve: Curve.EaseOut
    })
    .onClick(action)
    .onTouch((event: TouchEvent) => {
      touchAction(event);
    })
  }

  @Builder
  private controlPlain(icon: Resource, action: () => void, scaleValue: number, touchAction: (event: TouchEvent) => void) {
    Row() {
      Image(icon)
        .width(24)
        .height(24)
        .opacity(0.88)
    }
    .width(42)
    .height(42)
    .justifyContent(FlexAlign.Center)
    .scale({ x: scaleValue, y: scaleValue })
    .animation({
      duration: 140,
      curve: Curve.EaseOut
    })
    .onClick(action)
    .onTouch((event: TouchEvent) => {
      touchAction(event);
    })
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 16 }) {
        this.discArtwork()

        Column({ space: 4 }) {
          Text(this.track.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F4F4F4')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.track.artist)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#B7B7B7')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            Text(this.progressTimeText())
              .fontSize(12)
              .fontColor('#8C8C8C')
              .fontWeight(FontWeight.Medium)
            Blank()
            Text(this.durationTimeText())
              .fontSize(12)
              .fontColor('#6F6F6F')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.controlCircle(() => {
          this.onPlayPause();
        }, (event: TouchEvent) => {
          this.onPlayButtonTouch(event);
        })
        this.controlPlain($r('app.media.ic_next'), () => {
          this.onNext();
        }, this.nextButtonScale, (event: TouchEvent) => {
          this.onNextButtonTouch(event);
        })
      }
      .width('100%')
      .padding({ left: 20, right: 18, top: 18 })

      Slider({
        value: this.playbackProgressMs,
        min: 0,
        max: Math.max(this.playbackDurationMs, 1),
        style: SliderStyle.OutSet
      })
        .showTips(false)
        .trackThickness(4)
        .trackBorderRadius(2)
        .selectedBorderRadius(2)
        .blockSize({ width: 14, height: 14 })
        .trackColor('#444341')
        .selectedColor('#F1F1F1')
        .blockColor('#FFFFFF')
        .enabled(this.track.isImported && this.playbackDurationMs > 0)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.onSeekChange(value, mode);
        })
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 12 })
    }
    .width('100%')
    .backgroundColor('#2A292880')
    .backdropBlur(30)
    .borderRadius(28)
    .border({
      width: 1,
      color: '#3A393760'
    })
  }
}
