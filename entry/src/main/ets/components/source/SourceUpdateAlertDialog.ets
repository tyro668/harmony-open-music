import { AppThemeAppearance } from '../../models/AppModels';
import { t } from '../../utils/I18nUtil';
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
        Text(this.name.length > 0 ? t('source.update_dialog_title', this.name) : t('source.update_dialog_default_title'))
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
            Text(t('source.update_link'))
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
          Text(t('common.close'))
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
