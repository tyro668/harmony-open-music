import { image } from '@kit.ImageKit';

import { AppThemeAppearance, MusicTrack } from '../../models/AppModels';
import { t } from '../../utils/I18nUtil';
import { formatDurationMs } from '../../utils/TrackUtils';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct MiniPlayerBar {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop isDocked: boolean = false;
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
  @Prop currentLyricText: string = '';
  @Prop secondaryLyricText: string = '';
  @Prop isLoadingLyrics: boolean = false;
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

  private lyricHintText(): string {
    if (this.isLoadingLyrics) {
      return t('lyric.loading_preview');
    }
    if (this.currentLyricText.trim().length > 0) {
      return this.currentLyricText;
    }
    if (this.secondaryLyricText.trim().length > 0) {
      return this.secondaryLyricText;
    }
    return t('lyric.no_lyric_hint');
  }

  private lyricHintColor(): string {
    if (this.isLoadingLyrics) {
      return this.theme().secondaryText;
    }
    if (this.currentLyricText.trim().length > 0) {
      return this.theme().accent;
    }
    return this.theme().tertiaryText;
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
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.placeholderDiscFaceColor())
        .border({
          width: 1,
          color: this.placeholderDiscGrooveColor()
        })

      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], (tick: number) => {
        Column() {
          Row()
            .width(tick % 3 === 0 ? 2 : 1)
            .height(tick % 3 === 0 ? 6 : 4)
            .backgroundColor(this.placeholderDiscTickColor())
            .borderRadius(1)
            .opacity(tick % 3 === 0 ? 0.95 : 0.72)

          Blank().layoutWeight(1)
        }
        .width(36)
        .height(36)
        .padding({ top: 3 })
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
          .height(10)
          .backgroundColor(this.placeholderDiscMarkerColor())
          .borderRadius(1)
          .opacity(0.9)
        Blank().layoutWeight(1)
      }
      .width(2)
      .height(36)
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
          .height(12)
          .backgroundColor(this.placeholderDiscMinuteHandColor())
          .borderRadius(1)
          .opacity(0.92)
        Blank().layoutWeight(1)
      }
      .width(2)
      .height(36)
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
          .height(13)
          .backgroundColor(this.placeholderDiscSecondHandColor())
          .borderRadius(1)
          .opacity(0.96)
        Blank().layoutWeight(1)
      }
      .width(1)
      .height(36)
      .rotate({
        angle: 214,
        x: 0,
        y: 0,
        z: 1,
        centerX: '50%',
        centerY: '50%'
      })

      Row()
        .width(7)
        .height(7)
        .backgroundColor(this.placeholderDiscMarkerColor())
        .borderRadius(3.5)
        .border({
          width: 1,
          color: this.placeholderDiscTickColor()
        })

      Row()
        .width(24)
        .height(24)
        .borderRadius(12)
        .border({
          width: 1,
          color: this.placeholderDiscInnerGrooveColor()
        })
        .opacity(0.74)
    }
    .width(36)
    .height(36)
  }

  @Builder
  private discArtwork() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(52)
        .height(52)
        .backgroundColor(this.track.accentColor)
        .borderRadius(26)
        .linearGradient({
          angle: 135,
          colors: [
            [this.track.accentColor, 0],
            [this.discGradientTail(), 1]
          ]
        })

      if (this.hasTrackCover(this.track.id)) {
        Image(this.trackCover(this.track.id))
          .width(40)
          .height(40)
          .objectFit(ImageFit.Cover)
          .borderRadius(20)

        Row()
          .width(42)
          .height(42)
          .borderRadius(21)
          .border({
            width: 1,
            color: this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFF24' : '#00000018'
          })
      } else if (this.track.pic.length > 0) {
        Image(this.track.pic)
          .width(40)
          .height(40)
          .objectFit(ImageFit.Cover)
          .borderRadius(20)

        Row()
          .width(42)
          .height(42)
          .borderRadius(21)
          .border({
            width: 1,
            color: this.themeAppearance === AppThemeAppearance.Dark ? '#FFFFFF24' : '#00000018'
          })
      } else {
        this.placeholderClockDisc()
      }

      Row()
        .width(10)
        .height(10)
        .backgroundColor(this.theme().panelBackground)
        .borderRadius(5)
    }
    .width(52)
    .height(52)
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
        .width(46)
        .height(46)
        .backgroundColor(this.theme().controlPrimaryBackground)
        .borderRadius(23)
        .opacity(this.isPlayButtonTransitioning ? 0.88 : 1)

      if (this.isPlaying) {
        Row()
          .width(46)
          .height(46)
          .borderRadius(23)
          .border({
            width: 1,
            color: this.themeAppearance === AppThemeAppearance.Dark ? this.theme().accentSoftBorder : '#FFFFFF22'
          })
          .opacity(0.6)
      }

      if (this.playButtonShowsPause) {
        Image($r('app.media.ic_pause'))
          .width(18)
          .height(18)
          .fillColor(this.theme().controlPrimaryForeground)
          .opacity(0.96)
          .transition({ type: TransitionType.Insert, opacity: 0 })
          .transition({ type: TransitionType.Delete, opacity: 0 })
      } else {
        Image($r('app.media.ic_play'))
          .width(18)
          .height(18)
          .fillColor(this.theme().controlPrimaryForeground)
          .opacity(0.96)
          .transition({ type: TransitionType.Insert, opacity: 0 })
          .transition({ type: TransitionType.Delete, opacity: 0 })
      }
    }
    .width(46)
    .height(46)
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
        .width(20)
        .height(20)
        .fillColor(this.theme().controlSecondaryForeground)
        .opacity(0.88)
    }
    .width(38)
    .height(38)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme().controlSecondaryBackground)
    .borderRadius(19)
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
    Column({ space: 2 }) {
      Row({ space: 12 }) {
        this.discArtwork()

        Column({ space: 2 }) {
          Text(this.track.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.track.artist)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme().secondaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => {
          this.onTapTrackInfo();
        })

        Row({ space: 8 }) {
          this.controlPlain($r('app.media.ic_next'), () => {
            this.onNext();
          }, this.nextButtonScale, (event: TouchEvent) => {
            this.onNextButtonTouch(event);
          })
          this.controlCircle(() => {
            this.onPlayPause();
          }, (event: TouchEvent) => {
            this.onPlayButtonTouch(event);
          })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })

      Slider({
        value: this.playbackProgressMs,
        min: 0,
        max: Math.max(this.playbackDurationMs, 1),
        style: SliderStyle.OutSet
      })
        .showTips(false)
        .trackThickness(3)
        .trackBorderRadius(2)
        .selectedBorderRadius(2)
        .blockSize({ width: 12, height: 12 })
        .trackColor(this.theme().sliderTrack)
        .selectedColor(this.theme().sliderActiveTrack)
        .blockColor(this.theme().sliderThumb)
        .enabled(this.track.isImported && this.playbackDurationMs > 0)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.onSeekChange(value, mode);
        })
        .width('100%')
        .padding({ left: 12, right: 12 })

      Row({ space: 8 }) {
        Text(this.progressTimeText())
          .width(40)
          .fontSize(11)
          .fontColor(this.theme().secondaryText)
          .fontWeight(FontWeight.Medium)

        Text(this.lyricHintText())
          .layoutWeight(1)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.lyricHintColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)

        Text(this.durationTimeText())
          .width(40)
          .fontSize(11)
          .fontColor(this.theme().tertiaryText)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ left: 14, right: 14, bottom: 10 })
      .onClick(() => {
        this.onTapTrackInfo();
      })
    }
    .width('100%')
    .backgroundColor(this.isDocked ? Color.Transparent : this.theme().floatingSurface)
    .backdropBlur(this.isDocked ? 0 : (this.themeAppearance === AppThemeAppearance.Dark ? 30 : 12))
    .borderRadius(this.isDocked ? 0 : 24)
    .border({
      width: this.isDocked ? 0 : 1,
      color: this.isDocked ? Color.Transparent : this.theme().floatingSurfaceBorder
    })
    .shadow({
      radius: this.isDocked ? 0 : (this.themeAppearance === AppThemeAppearance.Dark ? 10 : 14),
      color: this.isDocked ? Color.Transparent : this.theme().floatingSurfaceShadow,
      offsetX: 0,
      offsetY: this.isDocked ? 0 : 6
    })
  }
}
