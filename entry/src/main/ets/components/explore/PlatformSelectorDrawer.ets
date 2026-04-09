import { MusicSourceQuality } from '../../models/AppModels';
import { sourceDisplayName } from '../../utils/MusicSourceUtils';

@Component
export struct PlatformSelectorDrawer {
  @Prop subSources: MusicSourceQuality[] = [];
  @Prop activeSearchSource: string = '';
  onClose: () => void = () => {};
  onSelectSubSource: (sourceCode: string) => void = (_: string) => {};

  private isActive(sourceCode: string): boolean {
    return this.activeSearchSource === sourceCode;
  }

  private accentColor(sourceCode: string): string {
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

  private tintColor(sourceCode: string): string {
    if (sourceCode === 'kw') {
      return '#17353B';
    }
    if (sourceCode === 'kg') {
      return '#183223';
    }
    if (sourceCode === 'tx') {
      return '#173145';
    }
    if (sourceCode === 'mg') {
      return '#392714';
    }
    if (sourceCode === 'wy') {
      return '#3B1E23';
    }
    return '#193038';
  }

  private itemBorderColor(sourceCode: string): string {
    if (sourceCode === 'kw') {
      return '#2F7F8C';
    }
    if (sourceCode === 'kg') {
      return '#2D7748';
    }
    if (sourceCode === 'tx') {
      return '#366EAA';
    }
    if (sourceCode === 'mg') {
      return '#9A6228';
    }
    if (sourceCode === 'wy') {
      return '#9C4A54';
    }
    return '#356B77';
  }

  private badgeText(sourceCode: string): string {
    return sourceCode.toUpperCase();
  }

  @Builder
  private platformItem(item: MusicSourceQuality) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(this.badgeText(item.source))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isActive(item.source) ? '#FFFFFF' : this.accentColor(item.source))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.isActive(item.source) ? '#FFFFFF1A' : '#101010')
          .borderRadius(10)

        Text(sourceDisplayName(item.source))
          .fontSize(16)
          .fontWeight(this.isActive(item.source) ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.isActive(item.source) ? '#F7F9FA' : '#D2D2D2')
          .layoutWeight(1)
          .maxLines(1)

        if (this.isActive(item.source)) {
          Text('当前')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        } else {
          Image($r('app.media.ic_chevron_right'))
            .width(14)
            .height(14)
            .fillColor('#6E6E6E')
        }
      }
      .width('100%')

      Text(`${item.qualitys.length} 种音质`)
        .fontSize(12)
        .fontColor(this.isActive(item.source) ? '#C7D6DB' : '#6D6D6D')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 18, right: 18, top: 14, bottom: 14 })
    .backgroundColor(this.isActive(item.source) ? this.tintColor(item.source) : '#161616')
    .borderRadius(20)
      .border({
      width: 1,
      color: this.isActive(item.source) ? this.itemBorderColor(item.source) : '#242424'
    })
    .onClick(() => {
      this.onSelectSubSource(item.source);
    })
  }

  build() {
    Stack() {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#00000088')
        .transition(TransitionEffect.opacity(0))
        .onClick(() => {
          this.onClose();
        })

      Row() {
        Column() {
          Row() {
            Column({ space: 6 }) {
              Text('音乐平台')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F4F7F8')

              Text('选择当前音源下的音乐平台')
                .fontSize(13)
                .fontColor('#6C7378')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('关闭')
              .fontSize(15)
              .fontColor('#5DB8C9')
              .onClick(() => {
                this.onClose();
              })
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 26, bottom: 18 })

          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.subSources, (item: MusicSourceQuality) => {
                this.platformItem(item)
              }, (item: MusicSourceQuality) => item.source)
            }
            .width('100%')
            .padding({ left: 22, right: 22, bottom: 28 })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .layoutWeight(1)
          .width('100%')
        }
        .width('74%')
        .height('100%')
        .backgroundColor('#101214F2')
        .backdropBlur(18)
        .border({
          width: 1,
          color: '#242A2D'
        })
        .borderRadius({ topRight: 30, bottomRight: 30 })
        .transition(
          TransitionEffect.translate({ x: -320 })
            .combine(TransitionEffect.opacity(0))
        )

        Blank()
          .layoutWeight(1)
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
