import { image } from '@kit.ImageKit';

import { AppThemeAppearance, MusicTrack } from '../../models/AppModels';
import { formatDurationMs } from '../../utils/TrackUtils';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct MiniPlayerBar {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop track: MusicTrack = {
    id: '',
    title: '',
    artist: '',
    album: '',
    durationMs: 0,
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
  onTapTrackInfo: () => void = () => {};
  coverForTrack: (trackId: string) => image.PixelMap | null = (_: string) => null;

  private hasTrackCover(trackId: string): boolean {
    return this.coveredTrackIds.indexOf(trackId) >= 0 && this.coverForTrack(trackId) !== null;
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
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

  private discGradientTail(): string {
    return this.themeAppearance === AppThemeAppearance.Dark ? '#17306C' : '#4B6FC8';
  }

  private placeholderDiscGrooveColor(): string {
    return this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFF1A' : '#FFFFFF88';
  }

  private placeholderDiscInnerGrooveColor(): string {
    return this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFF10' : '#FFFFFF55';
  }

  private placeholderDiscFaceColor(): string {
    return this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFF10' : '#F3F8FA';
  }

  private placeholderDiscTickColor(): string {
    return this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFFB8' : '#42616D';
  }

  private placeholderDiscMinuteHandColor(): string {
    return this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFFD8' : '#27424D';
  }

  private placeholderDiscSecondHandColor(): string {
    return this.themeAppearance === AppThemeAppearance.Dark ? '#79D8EA' : '#1F6F86';
  }

  private placeholderDiscMarkerColor(): string {
    return this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFFD4' : '#FFFFFFF2';
  }

  @Builder
  private placeholderClockDisc() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(this.placeholderDiscFaceColor())
        .border({
          width: 1,
          color: this.placeholderDiscGrooveColor()
        })

      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (tick: number) => {
        Column() {
          Row()
            .width(tick % 3 === 0 ? 2 : 1)
            .height(tick % 3 === 0 ? 7 : 4)
            .backgroundColor(this.placeholderDiscTickColor())
            .borderRadius(1)
            .opacity(tick % 3 === 0 ? 0.95 : 0.72)

          Blank().layoutWeight(1)
        }
        .width(40)
        .height(40)
        .padding({ top: 4 })
        .alignItems(HorizontalAlign.Center)
        .rotate({
          angle: tick * 30,
          x: 0,
          y: 0,
          z: 1,
          centerX: '50%',
          centerY: '50%'
        })
      }, (tick: number) => `clock-tick-${tick}`)

      Column() {
        Row()
          .width(2)
          .height(11)
          .backgroundColor(this.placeholderDiscMarkerColor())
          .borderRadius(1)
          .opacity(0.9)
        Blank().layoutWeight(1)
      }
      .width(2)
      .height(40)
      .rotate({
        angle: 28,
        x: 0,
        y: 0,
        z: 1,
        centerX: '50%',
        centerY: '50%'
      })

      Column() {
        Row()
          .width(2)
          .height(14)
          .backgroundColor(this.placeholderDiscMinuteHandColor())
          .borderRadius(1)
          .opacity(0.92)
        Blank().layoutWeight(1)
      }
      .width(2)
      .height(40)
      .rotate({
        angle: 136,
        x: 0,
        y: 0,
        z: 1,
        centerX: '50%',
        centerY: '50%'
      })

      Column() {
        Row()
          .width(1)
          .height(16)
          .backgroundColor(this.placeholderDiscSecondHandColor())
          .borderRadius(1)
          .opacity(0.96)
        Blank().layoutWeight(1)
      }
      .width(1)
      .height(40)
      .rotate({
        angle: 214,
        x: 0,
        y: 0,
        z: 1,
        centerX: '50%',
        centerY: '50%'
      })

      Row()
        .width(8)
        .height(8)
        .backgroundColor(this.placeholderDiscMarkerColor())
        .borderRadius(4)
        .border({
          width: 1,
          color: this.placeholderDiscTickColor()
        })

      Row()
        .width(28)
        .height(28)
        .borderRadius(14)
        .border({
          width: 1,
          color: this.placeholderDiscInnerGrooveColor()
        })
        .opacity(0.74)
    }
    .width(40)
    .height(40)
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
            [this.discGradientTail(), 1]
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
            color: this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFF24' : '#00000018'
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
            color: this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFF24' : '#00000018'
          })
      } else {
        this.placeholderClockDisc()
      }

      Row()
        .width(12)
        .height(12)
        .backgroundColor(this.theme().panelBackground)
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
        .backgroundColor(this.theme().controlPrimaryBackground)
        .borderRadius(26)
        .opacity(this.isPlayButtonTransitioning ? 0.88 : 1)

      if (this.isPlaying) {
        Row()
          .width(52)
          .height(52)
          .borderRadius(26)
          .border({
            width: 1,
            color: this.themeAppearance === AppThemeAppearance.Dark ? this.theme().accentSoftBorder : '#FFFFFF22'
          })
          .opacity(0.6)
      }

      if (this.playButtonShowsPause) {
        Image($r('app.media.ic_pause'))
          .width(20)
          .height(20)
          .fillColor(this.theme().controlPrimaryForeground)
          .opacity(0.96)
          .transition({ type: TransitionType.Insert, opacity: 0 })
          .transition({ type: TransitionType.Delete, opacity: 0 })
      } else {
        Image($r('app.media.ic_play'))
          .width(20)
          .height(20)
          .fillColor(this.theme().controlPrimaryForeground)
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
        .fillColor(this.theme().controlSecondaryForeground)
        .opacity(0.88)
    }
    .width(42)
    .height(42)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme().controlSecondaryBackground)
    .borderRadius(21)
    .border({
      width: 1,
      color: this.theme().controlSecondaryBorder
    })
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
            .fontColor(this.theme().primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.track.artist)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme().secondaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            Text(this.progressTimeText())
              .fontSize(12)
              .fontColor(this.theme().secondaryText)
              .fontWeight(FontWeight.Medium)
            Blank()
            Text(this.durationTimeText())
              .fontSize(12)
              .fontColor(this.theme().tertiaryText)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => {
          this.onTapTrackInfo();
        })

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
        .trackColor(this.theme().sliderTrack)
        .selectedColor(this.theme().sliderActiveTrack)
        .blockColor(this.theme().sliderThumb)
        .enabled(this.track.isImported && this.playbackDurationMs > 0)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.onSeekChange(value, mode);
        })
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 12 })
    }
    .width('100%')
    .backgroundColor(this.theme().floatingSurface)
    .backdropBlur(this.themeAppearance === AppThemeAppearance.Dark ? 30 : 12)
    .borderRadius(28)
    .border({
      width: 1,
      color: this.theme().floatingSurfaceBorder
    })
    .shadow({
      radius: this.themeAppearance === AppThemeAppearance.Dark ? 12 : 18,
      color: this.theme().floatingSurfaceShadow,
      offsetX: 0,
      offsetY: 8
    })
  }
}
