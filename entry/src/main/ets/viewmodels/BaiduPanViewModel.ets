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
import { appendImportedTrackIfMissing, hasTrackWithSourceImportKey } from '../utils/ImportStateUtils';
import { t } from '../utils/I18nUtil';
import { BaseViewModel } from './BaseViewModel';

class BaiduPanImportTask {
  key: string;
  entry: BaiduPanEntry;
  constructor(key: string, entry: BaiduPanEntry) {
    this.key = key;
    this.entry = entry;
  }
}

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
  private baiduPanImportQueue: BaiduPanImportTask[] = [];
  private isProcessingBaiduPanImportQueue: boolean = false;

  // Callbacks
  onGetLocalTracks: (() => MusicTrack[]) | null = null;
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

  private latestLocalTracks(): MusicTrack[] {
    return this.onGetLocalTracks ? this.onGetLocalTracks() : [];
  }

  async importBaiduPanEntry(state: BaiduPanState, entry: BaiduPanEntry): Promise<void> {
    if (entry.isDirectory) { await this.enterBaiduPanDirectory(state, entry); return; }
    let importKey = this.baiduPanEntryImportKey(entry);
    if (state.baiduPanImportingKeys.indexOf(importKey) >= 0) return;
    let alreadyImported = hasTrackWithSourceImportKey(this.latestLocalTracks(), importKey);
    if (alreadyImported) { this.showToast(t('baidu.entry_imported', entry.name)); return; }
    let accessToken = state.baiduPanAccessToken.trim();
    if (accessToken.length === 0) { this.showToast(t('baidu.auth_required')); return; }

    this.baiduPanImportQueue.push(new BaiduPanImportTask(importKey, entry));
    state.baiduPanImportingKeys = state.baiduPanImportingKeys.concat([importKey]);
    this.showToast(t('import.queue_added', entry.name));
    void this.processBaiduPanImportQueue(state);
  }

  private async processBaiduPanImportQueue(state: BaiduPanState): Promise<void> {
    if (this.isProcessingBaiduPanImportQueue) return;
    this.isProcessingBaiduPanImportQueue = true;
    try {
      while (this.baiduPanImportQueue.length > 0) {
        let task = this.baiduPanImportQueue.shift();
        if (!task) continue;
        await this.performBaiduPanImport(state, task.entry, task.key);
      }
    } finally {
      this.isProcessingBaiduPanImportQueue = false;
    }
  }

  private async performBaiduPanImport(state: BaiduPanState, entry: BaiduPanEntry, importKey: string): Promise<void> {
    try {
      if (hasTrackWithSourceImportKey(this.latestLocalTracks(), importKey)) return;
      let accessToken = state.baiduPanAccessToken.trim();
      if (accessToken.length === 0) throw new Error(t('baidu.auth_required'));

      let context = this.context();
      let downloadDirectory = `${context.filesDir}/downloads`;
      try { if (!fs.accessSync(downloadDirectory)) fs.mkdirSync(downloadDirectory, true); } catch (_) {}
      let targetFileName = `${Date.now()}-${sanitizeFileName(entry.name)}`;
      let targetPath = `${downloadDirectory}/${targetFileName}`;
      let audioBuffer = await downloadBaiduPanAudio(accessToken, entry.path);
      if (fs.accessSync(targetPath)) fs.unlinkSync(targetPath);
      let outputFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try { fs.writeSync(outputFile.fd, audioBuffer); } finally { fs.closeSync(outputFile); }

      let currentLocalTracks = this.latestLocalTracks();
      let importedTrack = buildDownloadedTrack(targetPath, `https://pan.baidu.com${entry.path}`, currentLocalTracks.length);
      let folderLabel = baiduPanParentLabel(entry.path);
      importedTrack.folder = folderLabel;
      importedTrack.album = folderLabel;
      importedTrack.sourceImportKey = importKey;

      let latestLocalTracks = this.latestLocalTracks();
      let hasImportedTrack = hasTrackWithSourceImportKey(latestLocalTracks, importKey);
      if (!hasImportedTrack) {
        let updatedTracks = appendImportedTrackIfMissing(latestLocalTracks, importedTrack);
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
