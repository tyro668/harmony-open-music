import { MAIN_TABS } from '../../constants/AppConstants';
import { MainTab, MainTabItem } from '../../models/AppModels';

@Component
export struct BottomNavigationBar {
  @Prop activeMainTab: MainTab = MainTab.Home;
  onSelectTab: (tab: MainTab) => void = (_: MainTab) => {};

  private isActive(tab: MainTab): boolean {
    return this.activeMainTab === tab;
  }

  build() {
    Row() {
      ForEach(MAIN_TABS, (tab: MainTabItem) => {
        Column({ space: 8 }) {
          Image(tab.icon)
            .width(24)
            .height(24)
            .opacity(this.isActive(tab.value) ? 1 : 0.42)
          Text(tab.label)
            .fontSize(13)
            .fontWeight(this.isActive(tab.value) ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.isActive(tab.value) ? '#F7F7F7' : '#707070')
        }
        .layoutWeight(1)
        .height(74)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.isActive(tab.value) ? '#24262B' : Color.Transparent)
        .borderRadius(20)
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
    .backgroundColor('#14151880')
    .backdropBlur(30)
    .borderRadius(26)
  }
}
