import { http } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { COLOR_PALETTE, ONLINE_DOWNLOAD_MAX_BYTES, getBuiltinBoardList } from '../constants/AppConstants';
import { MainTab, MusicSourceConfig, MusicSourceQuality, MusicSourceTrack, MusicTrack, SourceBoardItem } from '../models/AppModels';
import {
  buildSourceTrackImportKey,
  filterSupportedExploreSources,
  isSupportedExploreSource,
  sourceDisplayName
} from '../utils/MusicSourceUtils';
import { t } from '../utils/I18nUtil';
import { fetchBoardTrackPage, searchSourceTrackPage } from '../services/MusicSourceApiService';
import { fetchBuiltInSourceLyrics } from '../services/SourceLyricsService';
import { resolveSourceTrackQuality, SourceLyricResult } from '../services/QuickJsSourceService';
import { BaseViewModel } from './BaseViewModel';
import { SourceState } from './SourceViewModel';

class SourceImportTask {
  key: string;
  source: MusicSourceConfig;
  track: MusicSourceTrack;
  constructor(key: string, source: MusicSourceConfig, track: MusicSourceTrack) {
    this.key = key;
    this.source = source;
    this.track = track;
  }
}

@Observed
export class ExploreState {
  activeSourceId: string = '';
  activeSearchSource: string = '';
  sourceTracks: MusicSourceTrack[] = [];
  sourceTracksLoading: boolean = false;
  sourceSearchKeyword: string = '';
  sourceCurrentPage: number = 1;
  sourceTotal: number = 0;
  sourceImportingTrackKeys: string[] = [];
  sourceBoardList: SourceBoardItem[] = [];
  sourceBoardsLoading: boolean = false;
  activeBoardId: string = '';
  exploreMode: string = 'board';
  showSourceBrowser: boolean = false;
}

export class ExploreViewModel extends BaseViewModel {
  private sourceImportQueue: SourceImportTask[] = [];
  private isProcessingSourceImportQueue: boolean = false;

  // Callbacks
  onStateChanged: ((state: ExploreState) => void) | null = null;
  onRequestMusicUrl: ((source: MusicSourceConfig, track: MusicSourceTrack, quality: string) => Promise<string>) | null = null;
  onRequestLyric: ((source: MusicSourceConfig, track: MusicSourceTrack) => Promise<SourceLyricResult | null>) | null = null;
  onLocalTracksChanged: ((tracks: MusicTrack[]) => void) | null = null;
  onSaveTrackLyricSidecars: ((filePath: string, lyricResult: SourceLyricResult) => boolean) | null = null;
  onSyncTrackMetadataCaches: (() => void) | null = null;

  private notifyStateChanged(state: ExploreState): void {
    if (this.onStateChanged) {
      this.onStateChanged(state);
    }
  }

  clearExploreResults(state: ExploreState): void {
    state.sourceTracks = [];
    state.sourceTotal = 0;
    state.sourceCurrentPage = 1;
    state.sourceBoardList = [];
    state.activeBoardId = '';
    state.sourceBoardsLoading = false;
    state.sourceTracksLoading = false;
    this.notifyStateChanged(state);
  }

  ensureExploreSourceReady(sourceState: SourceState, exploreState: ExploreState, triggerFetch: boolean): MusicSourceConfig | undefined {
    if (sourceState.musicSources.length === 0) {
      exploreState.activeSourceId = '';
      exploreState.activeSearchSource = '';
      this.clearExploreResults(exploreState);
      return undefined;
    }
    let source = sourceState.musicSources.find((item: MusicSourceConfig) => item.id === exploreState.activeSourceId) ?? sourceState.musicSources[0];
    if (exploreState.activeSourceId !== source.id) exploreState.activeSourceId = source.id;
    let supportedSources = filterSupportedExploreSources(source.musicSources);
    if (supportedSources.length === 0) {
      exploreState.activeSearchSource = '';
      this.clearExploreResults(exploreState);
      return source;
    }
    let nextSearchSource = exploreState.activeSearchSource;
    if (!supportedSources.some((s: MusicSourceQuality) => s.source === nextSearchSource)) {
      nextSearchSource = supportedSources[0].source;
    }
    let shouldRefreshBoards = exploreState.activeSearchSource !== nextSearchSource || exploreState.sourceBoardList.length === 0;
    exploreState.activeSearchSource = nextSearchSource;
    if (triggerFetch && exploreState.exploreMode === 'board' && shouldRefreshBoards && !exploreState.sourceBoardsLoading) {
      void this.fetchBoardList(source, nextSearchSource, exploreState);
    }
    return source;
  }

  openSourceBrowser(source: MusicSourceConfig, exploreState: ExploreState): void {
    exploreState.activeSourceId = source.id;
    exploreState.sourceTracks = [];
    exploreState.sourceSearchKeyword = '';
    exploreState.sourceCurrentPage = 1;
    let supportedSources = filterSupportedExploreSources(source.musicSources);
    exploreState.activeSearchSource = supportedSources.length > 0 ? supportedSources[0].source : '';
    exploreState.showSourceBrowser = true;
    this.notifyStateChanged(exploreState);
  }

  closeSourceBrowser(exploreState: ExploreState): void {
    exploreState.showSourceBrowser = false;
    exploreState.sourceTracks = [];
    exploreState.sourceSearchKeyword = '';
    this.notifyStateChanged(exploreState);
  }

  async fetchBoardList(source: MusicSourceConfig, subSource: string, state: ExploreState): Promise<void> {
    state.sourceBoardsLoading = true;
    state.sourceBoardList = [];
    state.activeBoardId = '';
    state.sourceTracks = [];
    state.sourceTotal = 0;
    this.notifyStateChanged(state);
    try {
      if (!isSupportedExploreSource(subSource)) {
        return;
      }
      let boardList: Record<string, SourceBoardItem[]> = getBuiltinBoardList();
      let boards: SourceBoardItem[] | undefined = boardList[subSource];
      if (!boards || boards.length === 0) {
        return;
      }
      let hasSource = source.musicSources.some((s: MusicSourceQuality) => s.source === subSource);
      if (!hasSource) {
        return;
      }
      state.sourceBoardList = boards;
      state.activeBoardId = boards[0].bangid;
      this.notifyStateChanged(state);
      void this.fetchBoardTracks(subSource, boards[0].bangid, 1, state);
    } catch (error) {
      console.error(`fetch board list failed: ${JSON.stringify(error)}`);
    } finally {
      state.sourceBoardsLoading = false;
      this.notifyStateChanged(state);
    }
  }

  async fetchBoardTracks(subSource: string, bangid: string, page: number, state: ExploreState): Promise<void> {
    if (!isSupportedExploreSource(subSource)) { this.showToast(t('import.board_unsupported', sourceDisplayName(subSource))); return; }
    state.sourceTracksLoading = true;
    this.notifyStateChanged(state);
    try {
      let result = await fetchBoardTrackPage(subSource, bangid, page);
      state.sourceTotal = result.total;
      state.sourceTracks = page === 1 ? result.tracks : state.sourceTracks.concat(result.tracks);
      state.sourceCurrentPage = result.page;
    } catch (error) {
      if (page === 1) state.sourceTracks = [];
      this.showToast(t('import.board_fail'));
    } finally {
      state.sourceTracksLoading = false;
      this.notifyStateChanged(state);
    }
  }

  async searchSourceTracks(keyword: string, searchSource: string, page: number, state: ExploreState): Promise<void> {
    if (keyword.trim().length === 0) { this.showToast(t('import.search_keyword_required')); return; }
    if (!isSupportedExploreSource(searchSource)) { this.showToast(t('import.search_unsupported', sourceDisplayName(searchSource))); return; }
    state.sourceTracksLoading = true;
    this.notifyStateChanged(state);
    try {
      let result = await searchSourceTrackPage(keyword, searchSource, page);
      state.sourceTotal = result.total;
      state.sourceTracks = page === 1 ? result.tracks : state.sourceTracks.concat(result.tracks);
      state.sourceCurrentPage = result.page;
    } catch (error) {
      this.showToast(t('import.search_fail'));
    } finally {
      state.sourceTracksLoading = false;
      this.notifyStateChanged(state);
    }
  }

  sourceTrackImportKey(track: MusicSourceTrack): string {
    return buildSourceTrackImportKey(track);
  }

  findImportedSourceTrack(track: MusicSourceTrack, localTracks: MusicTrack[]): MusicTrack | undefined {
    let importKey = this.sourceTrackImportKey(track);
    return localTracks.find((item: MusicTrack) => {
      if ((item.sourceImportKey ?? '') === importKey) return true;
      return item.folder === 'downloads' && item.title === track.name && item.artist === track.singer && item.album === track.album;
    });
  }

  sourceTrackActionLabel(track: MusicSourceTrack, localTracks: MusicTrack[], importingKeys: string[]): string {
    if (this.findImportedSourceTrack(track, localTracks)) return t('common.imported');
    if (importingKeys.indexOf(this.sourceTrackImportKey(track)) >= 0) return t('common.importing');
    return t('common.import');
  }

  sourceTrackActionEnabled(track: MusicSourceTrack, localTracks: MusicTrack[], importingKeys: string[]): boolean {
    return this.sourceTrackActionLabel(track, localTracks, importingKeys) === t('common.import');
  }

  enqueueSourceTrackImport(source: MusicSourceConfig, track: MusicSourceTrack, localTracks: MusicTrack[], state: ExploreState): void {
    if (this.findImportedSourceTrack(track, localTracks)) { this.showToast(t('import.track_imported', track.name)); return; }
    let importKey = this.sourceTrackImportKey(track);
    if (state.sourceImportingTrackKeys.indexOf(importKey) >= 0) return;
    this.sourceImportQueue.push(new SourceImportTask(importKey, source, track));
    state.sourceImportingTrackKeys = state.sourceImportingTrackKeys.concat([importKey]);
    this.notifyStateChanged(state);
    this.showToast(t('import.queue_added', track.name));
    void this.processSourceImportQueue(state, localTracks);
  }

  private async processSourceImportQueue(state: ExploreState, localTracks: MusicTrack[]): Promise<void> {
    if (this.isProcessingSourceImportQueue) return;
    this.isProcessingSourceImportQueue = true;
    try {
      while (this.sourceImportQueue.length > 0) {
        let task = this.sourceImportQueue.shift();
        if (!task) continue;
        await this.importSourceTrack(task.source, task.track, task.key, state, localTracks);
      }
    } finally {
      this.isProcessingSourceImportQueue = false;
    }
  }

  private async importSourceTrack(source: MusicSourceConfig, track: MusicSourceTrack, importKey: string, state: ExploreState, localTracks: MusicTrack[]): Promise<void> {
    try {
      if (this.findImportedSourceTrack(track, localTracks)) return;
      let quality = resolveSourceTrackQuality(source, track);
      if (!this.onRequestMusicUrl) throw new Error('no music url handler');
      let musicUrl = await this.onRequestMusicUrl(source, track, quality);
      if (!musicUrl || musicUrl.length === 0) throw new Error('empty music url');

      let context = this.context();
      let downloadDir = `${context.filesDir}/downloads`;
      try { if (!fs.accessSync(downloadDir)) fs.mkdirSync(downloadDir, true); } catch (_) {}
      let safeFileName = `${Date.now()}-${track.name.replace(/[\/\\:*?"<>|]/g, '_')}.mp3`;
      let targetPath = `${downloadDir}/${safeFileName}`;

      let downloadHttp = http.createHttp();
      try {
        let downloadResponse = await downloadHttp.request(musicUrl, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          readTimeout: 60000,
          connectTimeout: 15000,
          usingCache: false,
          maxLimit: ONLINE_DOWNLOAD_MAX_BYTES,
          header: { 'User-Agent': 'Mozilla/5.0 (HarmonyOS Music Player)' } as Record<string, string>
        });
        if (downloadResponse.responseCode < 200 || downloadResponse.responseCode >= 300) throw new Error(`download failed: http ${downloadResponse.responseCode}`);
        let audioBuffer = downloadResponse.result as ArrayBuffer;
        if (!(audioBuffer instanceof ArrayBuffer) || audioBuffer.byteLength === 0) throw new Error('empty audio buffer');
        let outputFile = fs.openSync(targetPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
        try { fs.writeSync(outputFile.fd, audioBuffer); } finally { fs.closeSync(outputFile); }
      } finally { downloadHttp.destroy(); }

      let importedTrack: MusicTrack = {
        id: `source-${Date.now()}`, title: track.name, artist: track.singer, album: track.album,
        durationMs: track.duration > 0 ? track.duration * 1000 : 0, folder: 'downloads',
        sourceUri: '', filePath: targetPath, rawFileName: '',
        accentColor: COLOR_PALETTE[localTracks.length % COLOR_PALETTE.length],
        pic: track.pic, isFavorite: false, isImported: true, inPlayQueue: true,
        playCount: 0, lastPlayedAt: 0, sourceImportKey: importKey
      };

      if (!this.findImportedSourceTrack(track, localTracks)) {
        let updatedTracks = localTracks.concat([importedTrack]);
        if (this.onLocalTracksChanged) this.onLocalTracksChanged(updatedTracks);
        if (this.onSyncTrackMetadataCaches) this.onSyncTrackMetadataCaches();
      }
      this.schedulePersist();
      this.showToast(t('import.track_imported', track.name));
    } catch (error) {
      let errMessage = (error instanceof Error) ? error.message : String(error);
      this.showToast(t('import.track_fail', errMessage));
    } finally {
      state.sourceImportingTrackKeys = state.sourceImportingTrackKeys.filter((key: string) => key !== importKey);
      this.notifyStateChanged(state);
    }
  }
}
