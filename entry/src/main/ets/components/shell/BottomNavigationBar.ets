import { MAIN_TABS } from '../../constants/AppConstants';
import { AppThemeAppearance, MainTab, MainTabItem } from '../../models/AppModels';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct BottomNavigationBar {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop activeMainTab: MainTab = MainTab.Home;
  onSelectTab: (tab: MainTab) => void = (_: MainTab) => {};

  private isActive(tab: MainTab): boolean {
    return this.activeMainTab === tab;
  }

  private theme() {
    return appThemePalette(this.themeAppearance);
  }

  build() {
    Row() {
      ForEach(MAIN_TABS, (tab: MainTabItem) => {
        Column({ space: 8 }) {
          Image(tab.icon)
            .width(24)
            .height(24)
            .fillColor(this.isActive(tab.value) ? this.theme().navActiveIcon : this.theme().navInactiveIcon)
            .opacity(this.isActive(tab.value) ? 1 : 0.78)
          Text(tab.label)
            .fontSize(13)
            .fontWeight(this.isActive(tab.value) ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.isActive(tab.value) ? this.theme().navActiveText : this.theme().navInactiveText)
        }
        .layoutWeight(1)
        .height(74)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.isActive(tab.value) ? this.theme().floatingActiveSurface : Color.Transparent)
        .borderRadius(20)
        .border({
          width: this.isActive(tab.value) ? 1 : 0,
          color: this.isActive(tab.value) ? this.theme().floatingSurfaceBorder : Color.Transparent
        })
        .shadow(this.isActive(tab.value) ? {
          radius: this.themeAppearance === AppThemeAppearance.Dark ? 8 : 12,
          color: this.theme().floatingSurfaceShadow,
          offsetX: 0,
          offsetY: 4
        } : {
          radius: 0,
          color: Color.Transparent,
          offsetX: 0,
          offsetY: 0
        })
        .animation({
          duration: 180,
          curve: Curve.EaseInOut
        })
        .onClick(() => {
          this.onSelectTab(tab.value);
        })
      }, (tab: MainTabItem) => `${tab.value}`)
    }
    .width('100%')
    .padding({ left: 6, right: 6 })
    .backgroundColor(this.theme().floatingSurface)
    .backdropBlur(this.themeAppearance === AppThemeAppearance.Dark ? 30 : 12)
    .borderRadius(26)
    .border({
      width: 1,
      color: this.theme().floatingSurfaceBorder
    })
    .shadow({
      radius: this.themeAppearance === AppThemeAppearance.Dark ? 10 : 16,
      color: this.theme().floatingSurfaceShadow,
      offsetX: 0,
      offsetY: 8
    })
  }
}
