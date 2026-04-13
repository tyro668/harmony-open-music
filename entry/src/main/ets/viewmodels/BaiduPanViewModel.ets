import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { BaiduPanEntry, MusicTrack } from '../models/AppModels';
import {
  buildBaiduPanOAuthAuthorizeUrl,
  baiduPanParentLabel,
  downloadBaiduPanAudio,
  fetchBaiduPanDirectory,
  normalizeBaiduPanPath,
  parseBaiduPanOAuthPayload,
  parentBaiduPanPath
} from '../services/BaiduPanService';
import { buildDownloadedTrack, sanitizeFileName } from '../utils/TrackUtils';
import { t } from '../utils/I18nUtil';
import { BaseViewModel } from './BaseViewModel';

@Observed
export class BaiduPanState {
  showBaiduPanImportPanel: boolean = false;
  showBaiduPanAuthPanel: boolean = false;
  baiduPanAppKey: string = '';
  baiduPanAccessToken: string = '';
  baiduPanCurrentDir: string = '/';
  baiduPanEntries: BaiduPanEntry[] = [];
  baiduPanLoading: boolean = false;
  baiduPanAuthUrl: string = '';
  baiduPanImportingKeys: string[] = [];
}

export class BaiduPanViewModel extends BaseViewModel {
  private baiduPanLastAuthMessage: string = '';

  // Callbacks
  onLocalTracksChanged: ((tracks: MusicTrack[]) => void) | null = null;
  onSyncTrackMetadataCaches: (() => void) | null = null;

  baiduPanEntryImportKey(entry: BaiduPanEntry): string {
    return `baidupan:${entry.fsId}`;
  }

  baiduPanImportedKeySnapshot(localTracks: MusicTrack[]): string {
    return localTracks
      .map((track: MusicTrack) => track.sourceImportKey ?? '')
      .filter((value: string) => value.startsWith('baidupan:'))
      .join('|');
  }

  openBaiduPanImportPanel(state: BaiduPanState): void {
    state.showBaiduPanImportPanel = true;
    if (state.baiduPanAccessToken.trim().length > 0 && !state.baiduPanLoading) {
      void this.loadBaiduPanDirectory(state, state.baiduPanCurrentDir);
    }
  }

  closeBaiduPanImportPanel(state: BaiduPanState): void {
    state.showBaiduPanImportPanel = false;
    this.schedulePersist();
  }

  openBaiduPanAuthPanel(state: BaiduPanState): void {
    state.showBaiduPanAuthPanel = true;
    if (state.baiduPanAppKey.trim().length > 0 && state.baiduPanAuthUrl.trim().length === 0) {
      this.startBaiduPanAuth(state);
    }
  }

  closeBaiduPanAuthPanel(state: BaiduPanState): void {
    state.showBaiduPanAuthPanel = false;
    state.baiduPanAuthUrl = '';
    this.baiduPanLastAuthMessage = '';
    this.schedulePersist();
  }

  startBaiduPanAuth(state: BaiduPanState): void {
    let appKey = state.baiduPanAppKey.trim();
    if (appKey.length === 0) { this.showToast(t('baidu.appkey_required')); return; }
    state.baiduPanAuthUrl = buildBaiduPanOAuthAuthorizeUrl(appKey, `${Date.now()}`);
    this.baiduPanLastAuthMessage = '';
    this.schedulePersist();
  }

  handleBaiduPanAuthPayload(state: BaiduPanState, payload: string): void {
    let result = parseBaiduPanOAuthPayload(payload);
    if (result.accessToken.length > 0) {
      let accessTokenChanged = result.accessToken !== state.baiduPanAccessToken.trim();
      state.baiduPanAccessToken = result.accessToken;
      state.baiduPanEntries = [];
      state.baiduPanCurrentDir = '/';
      state.baiduPanAuthUrl = '';
      state.showBaiduPanAuthPanel = false;
      this.baiduPanLastAuthMessage = '';
      this.schedulePersist();
      this.showToast(accessTokenChanged ? t('baidu.auth_success') : t('baidu.auth_restored'));
      void this.loadBaiduPanDirectory(state, '/');
      return;
    }
    if (result.errorMessage.length === 0 || result.errorMessage === this.baiduPanLastAuthMessage) return;
    this.baiduPanLastAuthMessage = result.errorMessage;
    this.showToast(t('baidu.auth_fail', result.errorMessage));
  }

  async loadBaiduPanDirectory(state: BaiduPanState, targetDir: string): Promise<void> {
    let accessToken = state.baiduPanAccessToken.trim();
    if (accessToken.length === 0) { this.showToast(t('baidu.auth_required')); return; }
    state.baiduPanLoading = true;
    try {
      let normalizedDir = normalizeBaiduPanPath(targetDir);
      let entries = await fetchBaiduPanDirectory(accessToken, normalizedDir);
      state.baiduPanCurrentDir = normalizedDir;
      state.baiduPanEntries = entries;
      this.schedulePersist();
    } catch (error) {
      let message = error instanceof Error ? error.message : String(error);
      this.showToast(message.length > 0 ? message : t('baidu.dir_read_fail'));
    } finally {
      state.baiduPanLoading = false;
    }
  }

  async enterBaiduPanDirectory(state: BaiduPanState, entry: BaiduPanEntry): Promise<void> {
    if (!entry.isDirectory) return;
    await this.loadBaiduPanDirectory(state, entry.path);
  }

  async goParentBaiduPanDirectory(state: BaiduPanState): Promise<void> {
    await this.loadBaiduPanDirectory(state, parentBaiduPanPath(state.baiduPanCurrentDir));
  }

  async importBaiduPanEntry(state: BaiduPanState, entry: BaiduPanEntry, localTracks: MusicTrack[]): Promise<void> {
    if (entry.isDirectory) { await this.enterBaiduPanDirectory(state, entry); return; }
    let importKey = this.baiduPanEntryImportKey(entry);
    if (state.baiduPanImportingKeys.indexOf(importKey) >= 0) return;
    let alreadyImported = localTracks.some((track: MusicTrack) => track.sourceImportKey === importKey);
    if (alreadyImported) { this.showToast(t('baidu.entry_imported', entry.name)); return; }
    let accessToken = state.baiduPanAccessToken.trim();
    if (accessToken.length === 0) { this.showToast(t('baidu.auth_required')); return; }

    state.baiduPanImportingKeys = state.baiduPanImportingKeys.concat([importKey]);
    try {
      let context = this.context();
      let downloadDirectory = `${context.filesDir}/downloads`;
      try { if (!fs.accessSync(downloadDirectory)) fs.mkdirSync(downloadDirectory, true); } catch (_) {}
      let targetFileName = `${Date.now()}-${sanitizeFileName(entry.name)}`;
      let targetPath = `${downloadDirectory}/${targetFileName}`;
      let audioBuffer = await downloadBaiduPanAudio(accessToken, entry.path);
      if (fs.accessSync(targetPath)) fs.unlinkSync(targetPath);
      let outputFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try { fs.writeSync(outputFile.fd, audioBuffer); } finally { fs.closeSync(outputFile); }

      let importedTrack = buildDownloadedTrack(targetPath, `https://pan.baidu.com${entry.path}`, localTracks.length);
      let folderLabel = baiduPanParentLabel(entry.path);
      importedTrack.folder = folderLabel;
      importedTrack.album = folderLabel;
      importedTrack.sourceImportKey = importKey;

      let hasImportedTrack = localTracks.some((track: MusicTrack) => track.sourceImportKey === importKey);
      if (!hasImportedTrack) {
        let updatedTracks = localTracks.concat([importedTrack]);
        if (this.onLocalTracksChanged) this.onLocalTracksChanged(updatedTracks);
        if (this.onSyncTrackMetadataCaches) this.onSyncTrackMetadataCaches();
      }
      this.schedulePersist();
      this.showToast(t('baidu.import_success', entry.name));
    } catch (error) {
      let message = error instanceof Error ? error.message : String(error);
      this.showToast(message.length > 0 ? message : t('baidu.import_fail'));
    } finally {
      state.baiduPanImportingKeys = state.baiduPanImportingKeys.filter((key: string) => key !== importKey);
    }
  }
}
