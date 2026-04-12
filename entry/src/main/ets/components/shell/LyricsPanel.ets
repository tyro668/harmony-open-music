import { AppThemeAppearance } from '../../models/AppModels';
import { LyricLine } from '../../utils/LyricsParser';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct LyricsPanel {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop lyrics: LyricLine[] = [];
  @Prop @Watch('onCurrentIndexChanged') currentIndex: number = -1;
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
              Text(line.text.length > 0 ? line.text : '···')
                .fontSize(index === this.currentIndex ? 18 : 15)
                .fontColor(index === this.currentIndex ? this.theme().accent : this.theme().secondaryText)
                .fontWeight(index === this.currentIndex ? FontWeight.Bold : FontWeight.Normal)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 10, bottom: 10, left: 24, right: 24 })
                .opacity(index === this.currentIndex ? 1.0 : 0.6)
                .animation({
                  duration: 300,
                  curve: Curve.EaseOut
                })
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
        .onScrollIndex(() => {
          // allow manual scrolling
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().panelBackground)
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}
