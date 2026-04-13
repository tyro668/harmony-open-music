import { getMainTabs } from '../../constants/AppConstants';
import { AppThemeAppearance, MainTab, MainTabItem } from '../../models/AppModels';
import { appThemePalette } from '../../utils/ThemeUtils';

@Component
export struct BottomNavigationBar {
  @StorageProp('appThemeAppearance') themeAppearance: AppThemeAppearance = AppThemeAppearance.Light;
  @Prop isDocked: boolean = false;
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
      ForEach(getMainTabs(), (tab: MainTabItem) => {
        Column({ space: 4 }) {
          Row()
            .width(16)
            .height(3)
            .backgroundColor(this.isActive(tab.value) ? this.theme().accent : Color.Transparent)
            .borderRadius(2)

          Image(tab.icon)
            .width(22)
            .height(22)
            .fillColor(this.isActive(tab.value) ? this.theme().navActiveIcon : this.theme().navInactiveIcon)
            .opacity(this.isActive(tab.value) ? 1 : 0.78)
          Text(tab.label)
            .fontSize(12)
            .fontWeight(this.isActive(tab.value) ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.isActive(tab.value) ? this.theme().navActiveText : this.theme().navInactiveText)
        }
        .layoutWeight(1)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
        .borderRadius(14)
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
    .padding({ left: 8, right: 8, top: this.isDocked ? 0 : 4, bottom: 4 })
    .backgroundColor(this.isDocked ? Color.Transparent : this.theme().panelBackground)
    .borderRadius(this.isDocked ? {
      topLeft: 0,
      topRight: 0,
      bottomLeft: 0,
      bottomRight: 0
    } : {
      topLeft: 14,
      topRight: 14,
      bottomLeft: 0,
      bottomRight: 0
    })
    .border({
      width: this.isDocked ? 0 : 1,
      color: this.isDocked ? Color.Transparent : this.theme().divider
    })
  }
}
