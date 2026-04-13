import { AppThemeAppearance, AppThemeMode } from '../../models/AppModels';
import { t } from '../../utils/I18nUtil';
import { appThemeModeLabel, appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct ThemeModePanel {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop currentMode: AppThemeMode = AppThemeMode.Light;
  onClose: () => void = () => {};
  onSelectMode: (mode: AppThemeMode) => void = (_: AppThemeMode) => {};

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  private isSelected(mode: AppThemeMode): boolean {
    return this.currentMode === mode;
  }

  @Builder
  private optionRow(mode: AppThemeMode, subtitle: string) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(appThemeModeLabel(mode))
          .fontSize(16)
          .fontWeight(this.isSelected(mode) ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.isSelected(mode) ? this.theme().primaryText : this.theme().secondaryText)

        Text(subtitle)
          .fontSize(12)
          .fontColor(this.theme().tertiaryText)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.isSelected(mode)) {
        Text(t('common.current'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme().accent)
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.isSelected(mode) ? this.theme().accentSoftBackground : this.theme().panelSecondaryBackground)
    .borderRadius(16)
    .border({
      width: 1,
      color: this.isSelected(mode) ? this.theme().accentSoftBorder : this.theme().divider
    })
    .onClick(() => {
      this.onSelectMode(mode);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme().maskBackground)
        .onClick(() => {
          this.onClose();
        })

      Column({ space: 14 }) {
        Row() {
          Text(t('profile.theme_panel_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme().primaryText)
          Blank()
          Text(t('common.close'))
            .fontSize(14)
            .fontColor(this.theme().accent)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')

        this.optionRow(AppThemeMode.Light, t('profile.theme_light_desc'))
        this.optionRow(AppThemeMode.Dark, t('profile.theme_dark_desc'))
        this.optionRow(AppThemeMode.System, t('profile.theme_system_desc'))
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 28 })
      .backgroundColor(this.theme().panelBackground)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .border({
        width: 1,
        color: this.theme().divider
      })
    }
    .width('100%')
    .height('100%')
  }
}
