import { ConfigurationConstant } from '@kit.AbilityKit';

import { AppThemeAppearance, AppThemeMode } from '../models/AppModels';

export interface AppThemePalette {
  appBackground: string;
  panelBackground: string;
  panelSecondaryBackground: string;
  floatingSurface: string;
  floatingSurfaceBorder: string;
  floatingSurfaceShadow: string;
  floatingActiveSurface: string;
  headerBackground: string;
  headerBorder: string;
  inputBackground: string;
  divider: string;
  primaryText: string;
  secondaryText: string;
  tertiaryText: string;
  mutedText: string;
  accent: string;
  onAccent: string;
  accentSoftBackground: string;
  accentSoftBorder: string;
  successBackground: string;
  successText: string;
  warningBackground: string;
  warningText: string;
  dangerBackground: string;
  dangerText: string;
  chipBackground: string;
  chipText: string;
  chipSelectedBackground: string;
  chipSelectedText: string;
  controlPrimaryBackground: string;
  controlPrimaryForeground: string;
  controlSecondaryBackground: string;
  controlSecondaryForeground: string;
  controlSecondaryBorder: string;
  sliderTrack: string;
  sliderActiveTrack: string;
  sliderThumb: string;
  navActiveIcon: string;
  navInactiveIcon: string;
  navActiveText: string;
  navInactiveText: string;
  frostedBackground: string;
  frostedActiveBackground: string;
  maskBackground: string;
  activeRowBackground: string;
  activeRowBorder: string;
  inactiveRowBackground: string;
}

const LIGHT_THEME: AppThemePalette = {
  appBackground: '#F1F5F7',
  panelBackground: '#FFFFFF',
  panelSecondaryBackground: '#E8F0F4',
  floatingSurface: '#F8FBFC',
  floatingSurfaceBorder: '#CDDAE1',
  floatingSurfaceShadow: '#102B3A18',
  floatingActiveSurface: '#D7E5EC',
  headerBackground: '#FFFFFF',
  headerBorder: '#CDD9DF',
  inputBackground: '#EAF1F4',
  divider: '#D2DEE4',
  primaryText: '#13212C',
  secondaryText: '#425661',
  tertiaryText: '#5F717B',
  mutedText: '#7D8E98',
  accent: '#1F6F86',
  onAccent: '#FFFFFF',
  accentSoftBackground: '#D3E7EE',
  accentSoftBorder: '#A9CAD5',
  successBackground: '#E3F2E7',
  successText: '#236A3F',
  warningBackground: '#F6E9CB',
  warningText: '#735514',
  dangerBackground: '#F8E3E6',
  dangerText: '#A1424A',
  chipBackground: '#E4EDF2',
  chipText: '#566974',
  chipSelectedBackground: '#CBE3EB',
  chipSelectedText: '#173F4C',
  controlPrimaryBackground: '#1D5B6E',
  controlPrimaryForeground: '#FFFFFF',
  controlSecondaryBackground: '#DDE7EC',
  controlSecondaryForeground: '#2E4D59',
  controlSecondaryBorder: '#C2D1D8',
  sliderTrack: '#D2DDE3',
  sliderActiveTrack: '#1F6F86',
  sliderThumb: '#FFFFFF',
  navActiveIcon: '#194B5C',
  navInactiveIcon: '#6E848F',
  navActiveText: '#163E4A',
  navInactiveText: '#556A75',
  frostedBackground: '#F8FBFC',
  frostedActiveBackground: '#D7E5EC',
  maskBackground: '#00000022',
  activeRowBackground: '#E0EDF2',
  activeRowBorder: '#B9D1DA',
  inactiveRowBackground: '#FFFFFF'
};

const DARK_THEME: AppThemePalette = {
  appBackground: '#050505',
  panelBackground: '#171717',
  panelSecondaryBackground: '#111111',
  floatingSurface: '#2A292880',
  floatingSurfaceBorder: '#3A393760',
  floatingSurfaceShadow: '#00000055',
  floatingActiveSurface: '#24262B',
  headerBackground: '#17191B',
  headerBorder: '#24282B',
  inputBackground: '#1A2A32',
  divider: '#222222',
  primaryText: '#F5F5F5',
  secondaryText: '#8A8A8A',
  tertiaryText: '#666666',
  mutedText: '#555555',
  accent: '#5DB8C9',
  onAccent: '#050505',
  accentSoftBackground: '#16333B',
  accentSoftBorder: '#27515A',
  successBackground: '#213126',
  successText: '#9FD3AC',
  warningBackground: '#2B2414',
  warningText: '#D6B65D',
  dangerBackground: '#221617',
  dangerText: '#D94040',
  chipBackground: '#1A1A1A',
  chipText: '#A9A9A9',
  chipSelectedBackground: '#5DB8C9',
  chipSelectedText: '#050505',
  controlPrimaryBackground: '#4B4A49',
  controlPrimaryForeground: '#FFFFFF',
  controlSecondaryBackground: '#2F3136',
  controlSecondaryForeground: '#F2F2F2',
  controlSecondaryBorder: '#4A4D53',
  sliderTrack: '#444341',
  sliderActiveTrack: '#5DB8C9',
  sliderThumb: '#FFFFFF',
  navActiveIcon: '#F7F7F7',
  navInactiveIcon: '#A8A8A8',
  navActiveText: '#F7F7F7',
  navInactiveText: '#707070',
  frostedBackground: '#14151880',
  frostedActiveBackground: '#24262B',
  maskBackground: '#00000088',
  activeRowBackground: '#1A1A30',
  activeRowBorder: '#2A2A44',
  inactiveRowBackground: '#0D0D1A'
};

export function appThemePalette(appearance: AppThemeAppearance): AppThemePalette {
  return appearance === AppThemeAppearance.Dark ? DARK_THEME : LIGHT_THEME;
}

export function resolveAppThemeAppearance(
  mode: AppThemeMode,
  systemColorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
): AppThemeAppearance {
  if (mode === AppThemeMode.Dark) {
    return AppThemeAppearance.Dark;
  }
  if (mode === AppThemeMode.System) {
    return systemColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      ? AppThemeAppearance.Dark
      : AppThemeAppearance.Light;
  }
  return AppThemeAppearance.Light;
}

export function appThemeModeToColorMode(mode: AppThemeMode): ConfigurationConstant.ColorMode {
  if (mode === AppThemeMode.Dark) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
  if (mode === AppThemeMode.System) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }
  return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
}

export function appThemeModeLabel(mode: AppThemeMode): string {
  if (mode === AppThemeMode.Dark) {
    return '深色';
  }
  if (mode === AppThemeMode.System) {
    return '跟随系统';
  }
  return '浅色';
}
