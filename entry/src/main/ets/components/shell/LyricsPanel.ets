import { AppThemeAppearance } from '../../models/AppModels';
import { LyricLine, LyricWord } from '../../utils/LyricsParser';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct LyricsPanel {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop lyrics: LyricLine[] = [];
  @Prop @Watch('onCurrentIndexChanged') currentIndex: number = -1;
  @Prop currentTimeMs: number = 0;
  @Prop isLoading: boolean = false;
  onClose: () => void = () => {};

  private scroller: Scroller = new Scroller();

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  onCurrentIndexChanged(): void {
    if (this.currentIndex >= 0) {
      // +1 to account for the spacer ListItem at index 0
      this.scroller.scrollToIndex(this.currentIndex + 1, true, ScrollAlign.CENTER);
    }
  }

  private usesWordTiming(line: LyricLine, index: number): boolean {
    return index === this.currentIndex && line.words.length > 0;
  }

  private wordProgress(line: LyricLine, word: LyricWord): number {
    let elapsedMs = this.currentTimeMs - line.timeMs;
    if (elapsedMs <= word.startTimeMs) {
      return 0;
    }
    if (word.durationMs <= 0) {
      return 1;
    }
    if (elapsedMs >= word.startTimeMs + word.durationMs) {
      return 1;
    }
    return (elapsedMs - word.startTimeMs) / word.durationMs;
  }

  private wordSplitIndex(line: LyricLine, word: LyricWord): number {
    let progress = this.wordProgress(line, word);
    if (progress <= 0) {
      return 0;
    }
    if (progress >= 1) {
      return word.text.length;
    }
    let splitIndex = Math.ceil(word.text.length * progress);
    if (splitIndex < 1) {
      return 1;
    }
    if (splitIndex > word.text.length) {
      return word.text.length;
    }
    return splitIndex;
  }

  private playedWordText(line: LyricLine, word: LyricWord): string {
    let splitIndex = this.wordSplitIndex(line, word);
    if (splitIndex <= 0) {
      return '';
    }
    return word.text.substring(0, splitIndex);
  }

  private pendingWordText(line: LyricLine, word: LyricWord): string {
    let splitIndex = this.wordSplitIndex(line, word);
    if (splitIndex >= word.text.length) {
      return '';
    }
    return word.text.substring(splitIndex);
  }

  @Builder
  private timedLyricLineContent(line: LyricLine, index: number) {
    Text() {
      ForEach(line.words, (word: LyricWord, wordIndex: number) => {
        if (this.playedWordText(line, word).length > 0) {
          Span(this.playedWordText(line, word))
            .fontColor(this.theme().accent)
        }
        if (this.pendingWordText(line, word).length > 0) {
          Span(this.pendingWordText(line, word))
            .fontColor(this.theme().primaryText)
        }
      }, (word: LyricWord, wordIndex: number) => `word_${wordIndex}_${word.startTimeMs}_${word.text}`)
    }
    .fontSize(index === this.currentIndex ? 18 : 15)
    .fontWeight(index === this.currentIndex ? FontWeight.Bold : FontWeight.Normal)
    .width('100%')
    .textAlign(TextAlign.Center)
    .opacity(index === this.currentIndex ? 1.0 : 0.6)
  }

  @Builder
  private lyricLineContent(line: LyricLine, index: number) {
    Column({ space: 4 }) {
      if (this.usesWordTiming(line, index)) {
        this.timedLyricLineContent(line, index)
      } else {
        Text(line.text.length > 0 ? line.text : '···')
          .fontSize(index === this.currentIndex ? 18 : 15)
          .fontColor(index === this.currentIndex ? this.theme().accent : this.theme().secondaryText)
          .fontWeight(index === this.currentIndex ? FontWeight.Bold : FontWeight.Normal)
          .width('100%')
          .textAlign(TextAlign.Center)
          .opacity(index === this.currentIndex ? 1.0 : 0.6)
      }

      ForEach(line.extendedLyrics, (extText: string) => {
        Text(extText)
          .fontSize(index === this.currentIndex ? 14 : 13)
          .fontColor(index === this.currentIndex ? this.theme().accent : this.theme().tertiaryText)
          .fontWeight(FontWeight.Normal)
          .width('100%')
          .textAlign(TextAlign.Center)
          .opacity(index === this.currentIndex ? 0.85 : 0.5)
      }, (extText: string, extIdx: number) => `ext_${extIdx}_${extText}`)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 24, right: 24 })
    .animation({
      duration: 300,
      curve: Curve.EaseOut
    })
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('歌词')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().primaryText)
        Blank()
        Text('关闭')
          .fontSize(14)
          .fontColor(this.theme().accent)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      if (this.isLoading) {
        Column() {
          Text('加载歌词中...')
            .fontSize(15)
            .fontColor(this.theme().tertiaryText)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.lyrics.length === 0) {
        Column() {
          Text('暂无歌词')
            .fontSize(15)
            .fontColor(this.theme().tertiaryText)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.scroller }) {
          ListItem() {
            Row().height(60)
          }

          ForEach(this.lyrics, (line: LyricLine, index: number) => {
            ListItem() {
              this.lyricLineContent(line, index)
            }
          }, (line: LyricLine, index: number) => `lyric_${index}_${line.timeMs}_${index === this.currentIndex}`)

          ListItem() {
            Row().height(60)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().panelBackground)
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}
