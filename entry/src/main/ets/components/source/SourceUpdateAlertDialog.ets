import { AppThemeAppearance } from '../../models/AppModels';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct SourceUpdateAlertDialog {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop name: string = ''
  @Prop log: string = ''
  @Prop updateUrl: string = ''
  onClose: () => void = () => {}

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme().maskBackground)
        .onClick(() => {
          this.onClose();
        })

      Column({ space: 14 }) {
        Text(this.name.length > 0 ? `${this.name} 有新提醒` : '音源更新提醒')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme().primaryText)
          .width('100%')

        Text(this.log)
          .fontSize(13)
          .fontColor(this.theme().secondaryText)
          .lineHeight(20)
          .width('100%')

        if (this.updateUrl.length > 0) {
          Column({ space: 6 }) {
            Text('更新链接')
              .fontSize(12)
              .fontColor(this.theme().secondaryText)
              .width('100%')
            Text(this.updateUrl)
              .fontSize(12)
              .fontColor(this.theme().accent)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
        }

        Row() {
          Text('关闭')
            .fontSize(15)
            .fontColor(this.theme().onAccent)
            .fontWeight(FontWeight.Bold)
            .padding({ left: 24, right: 24, top: 10, bottom: 10 })
            .backgroundColor(this.theme().accent)
            .borderRadius(14)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('82%')
      .padding({ left: 20, right: 20, top: 18, bottom: 18 })
      .backgroundColor(this.theme().panelBackground)
      .borderRadius(20)
      .border({ width: 1, color: this.theme().divider })
    }
    .width('100%')
    .height('100%')
  }
}
