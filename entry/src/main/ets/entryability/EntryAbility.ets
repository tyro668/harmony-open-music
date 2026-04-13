import { AbilityConstant, common, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { resourceManager } from '@kit.LocalizationKit';
import { initI18n } from '../utils/I18nUtil';

const DOMAIN = 0x0000;
const HICAR_BUNDLE = 'com.huawei.hmos.hicar';
const HICAR_BUNDLE_LEGACY = 'com.huawei.hicar';
const CARLIFE_BUNDLE = 'com.baidu.carlife';

function detectCarMode(want: Want, context: common.UIAbilityContext): void {
  // 检测启动来源是否为 HiCar 或 CarLife
  let callerBundle = want.parameters?.['ohos.extra.callerBundleName'] as string | undefined;
  if (callerBundle === HICAR_BUNDLE || callerBundle === HICAR_BUNDLE_LEGACY || callerBundle === CARLIFE_BUNDLE) {
    AppStorage.setOrCreate('isCarMode', true);
    AppStorage.setOrCreate('carSource', callerBundle);
    hilog.info(DOMAIN, 'testTag', 'Car mode detected from caller: %{public}s', callerBundle);
    return;
  }
  if (want.parameters?.['ohos.extra.hicar'] === true) {
    AppStorage.setOrCreate('isCarMode', true);
    AppStorage.setOrCreate('carSource', HICAR_BUNDLE);
    hilog.info(DOMAIN, 'testTag', 'Car mode detected from hicar parameter');
    return;
  }
  // 检测设备类型是否为车机
  try {
    let capability = context.resourceManager.getDeviceCapabilitySync();
    if (capability.deviceType === resourceManager.DeviceType.DEVICE_TYPE_CAR) {
      AppStorage.setOrCreate('isCarMode', true);
      AppStorage.setOrCreate('carSource', 'car_device');
      hilog.info(DOMAIN, 'testTag', 'Car mode detected from device type');
    }
  } catch (err) {
    hilog.warn(DOMAIN, 'testTag', 'Failed to get device capability: %{public}s', JSON.stringify(err));
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    initI18n();
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    detectCarMode(want, this.context);

    // 诊断日志：输出完整的 Want 信息，帮助定位车机启动参数
    hilog.info(DOMAIN, 'testTag', 'Ability onCreate, want action=%{public}s, entities=%{public}s, params=%{public}s',
      want.action ?? 'null',
      JSON.stringify(want.entities ?? []),
      JSON.stringify(Object.keys(want.parameters ?? {}))
    );
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    detectCarMode(want, this.context);

    // 诊断日志：输出完整的 Want 信息
    hilog.info(DOMAIN, 'testTag', 'Ability onNewWant, want action=%{public}s, entities=%{public}s, params=%{public}s',
      want.action ?? 'null',
      JSON.stringify(want.entities ?? []),
      JSON.stringify(Object.keys(want.parameters ?? {}))
    );
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      // 如果是车机模式，设置横屏方向
      let isCarMode = AppStorage.get<boolean>('isCarMode') ?? false;
      if (isCarMode) {
        this.setCarWindowOrientation(windowStage);
      }
    });
  }

  private setCarWindowOrientation(windowStage: window.WindowStage): void {
    try {
      let mainWindow = windowStage.getMainWindowSync();
      mainWindow.setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE);
      hilog.info(DOMAIN, 'testTag', 'Car mode: set landscape orientation');
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'Failed to set car orientation: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
