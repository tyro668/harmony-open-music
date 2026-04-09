import { MusicTrack } from '../../models/AppModels';

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
    isFavorite: false,
    isImported: false,
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
  onPlayPause: () => void = () => {};
  onNext: () => void = () => {};
  onPlayButtonTouch: (event: TouchEvent) => void = (_: TouchEvent) => {};
  onNextButtonTouch: (event: TouchEvent) => void = (_: TouchEvent) => {};

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
    Stack({ alignContent: Alignment.BottomStart }) {
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
      .padding({ left: 20, right: 18, top: 20, bottom: 26 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(4)
          .backgroundColor('#444341')
          .borderRadius(2)

        Row()
          .width(`${this.progressRatio * 100}%`)
          .height(4)
          .backgroundColor('#F1F1F1')
          .borderRadius(2)
      }
      .width('100%')
      .height(4)
      .padding({ left: 20, right: 20, bottom: 12 })
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
