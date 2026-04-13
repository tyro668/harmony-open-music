import fs from '@ohos.file.fs';
import { MusicTrack, MusicSourceTrack } from '../models/AppModels';
import { LyricLine, parseLrcLyrics, findCurrentLyricIndex } from '../utils/LyricsParser';
import { extractTrackLyrics } from '../services/TrackArtworkService';
import { fetchBuiltInSourceLyrics } from '../services/SourceLyricsService';
import { searchSourceTrackPage } from '../services/MusicSourceApiService';
import { buildSourceTrackImportKey } from '../utils/MusicSourceUtils';
import { t } from '../utils/I18nUtil';
import { BaseViewModel } from './BaseViewModel';
import { SourceLyricResult } from '../services/QuickJsSourceService';

const LYRIC_REPAIR_SEARCH_SOURCES: string[] = ['kw', 'kg', 'tx', 'wy', 'mg'];
const LYRIC_REPAIR_MIN_MATCH_SCORE: number = 145;
const LYRIC_REPAIR_STRONG_MATCH_SCORE: number = 190;

@Observed
export class LyricState {
  currentLyrics: LyricLine[] = [];
  currentLyricIndex: number = -1;
  isLoadingLyrics: boolean = false;
  lyricRepairingTrackIds: string[] = [];
  showLyricsPanel: boolean = false;
}

export class LyricViewModel extends BaseViewModel {
  private lyricsTrackId: string = '';

  // Callbacks
  onLiveViewUpdateNeeded: ((playing: boolean) => void) | null = null;
  onAVSessionUpdateNeeded: (() => void) | null = null;
  onBackgroundNotificationUpdateNeeded: (() => void) | null = null;
  onTrackSourceImportKeyUpdate: ((trackId: string, key: string) => void) | null = null;

  async loadTrackLyrics(state: LyricState, track: MusicTrack): Promise<void> {
    if (this.lyricsTrackId === track.id) return;
    this.lyricsTrackId = track.id;
    state.currentLyrics = [];
    state.currentLyricIndex = -1;
    state.isLoadingLyrics = true;
    try {
      let lyricsResult = await extractTrackLyrics(track);
      if (this.lyricsTrackId !== track.id) return;
      let mainLyric = lyricsResult.lxlyric.length > 0 ? lyricsResult.lxlyric : lyricsResult.lyric;
      if (mainLyric.length > 0) {
        let extendedLyrics: string[] = [];
        if (lyricsResult.tlyric.length > 0) extendedLyrics.push(lyricsResult.tlyric);
        if (lyricsResult.rlyric.length > 0) extendedLyrics.push(lyricsResult.rlyric);
        state.currentLyrics = parseLrcLyrics(mainLyric, extendedLyrics);
        state.currentLyricIndex = findCurrentLyricIndex(state.currentLyrics, 0);
      } else {
        state.currentLyrics = [];
        state.currentLyricIndex = -1;
      }
    } catch (_) {
      state.currentLyrics = [];
      state.currentLyricIndex = -1;
    } finally {
      if (this.lyricsTrackId === track.id) state.isLoadingLyrics = false;
    }
  }

  updateLyricIndex(state: LyricState, timeMs: number): boolean {
    if (state.currentLyrics.length === 0) return false;
    let lyricIdx = findCurrentLyricIndex(state.currentLyrics, timeMs);
    if (lyricIdx !== state.currentLyricIndex) {
      state.currentLyricIndex = lyricIdx;
      return true;
    }
    return false;
  }

  activeLyricLine(state: LyricState): LyricLine | null {
    if (state.currentLyrics.length === 0) return null;
    if (state.currentLyricIndex >= 0 && state.currentLyricIndex < state.currentLyrics.length) return state.currentLyrics[state.currentLyricIndex];
    return state.currentLyrics[0];
  }

  private nextLyricLine(state: LyricState): LyricLine | null {
    if (state.currentLyrics.length === 0) return null;
    let nextIndex = state.currentLyricIndex >= 0 ? state.currentLyricIndex + 1 : 1;
    if (nextIndex >= 0 && nextIndex < state.currentLyrics.length) return state.currentLyrics[nextIndex];
    return null;
  }

  private lyricLinePreviewText(line: LyricLine | null): string {
    if (!line) return '';
    let primaryText = line.text.trim();
    if (primaryText.length > 0) return primaryText;
    if (line.extendedLyrics.length > 0) return line.extendedLyrics[0].trim();
    return '';
  }

  currentLyricPreviewText(state: LyricState): string {
    return this.lyricLinePreviewText(this.activeLyricLine(state));
  }

  currentLyricSecondaryText(state: LyricState): string {
    let activeLine = this.activeLyricLine(state);
    if (activeLine && activeLine.extendedLyrics.length > 0) {
      let extendedText = activeLine.extendedLyrics[0].trim();
      if (extendedText.length > 0 && extendedText !== this.currentLyricPreviewText(state)) return extendedText;
    }
    return this.lyricLinePreviewText(this.nextLyricLine(state));
  }

  currentLyricMetadataText(state: LyricState): string {
    return this.currentLyricPreviewText(state).trim();
  }

  currentLyricContentText(state: LyricState): string {
    if (state.currentLyrics.length === 0) return '';
    let lines: string[] = [];
    for (let index = 0; index < state.currentLyrics.length; index++) {
      let line = state.currentLyrics[index];
      let totalMinutes = Math.floor(Math.max(0, line.timeMs) / 60000);
      let seconds = Math.floor((Math.max(0, line.timeMs) % 60000) / 1000);
      let hundredths = Math.floor((Math.max(0, line.timeMs) % 1000) / 10);
      let timeTag = `[${totalMinutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}.${hundredths.toString().padStart(2, '0')}]`;
      let primaryText = line.text.trim();
      if (primaryText.length > 0) lines.push(`${timeTag}${primaryText}`);
      for (let extendedIndex = 0; extendedIndex < line.extendedLyrics.length; extendedIndex++) {
        let extendedText = line.extendedLyrics[extendedIndex].trim();
        if (extendedText.length === 0 || extendedText === primaryText) continue;
        lines.push(`${timeTag}${extendedText}`);
      }
    }
    return lines.join('\n');
  }

  async refreshLyricsForTrack(state: LyricState, trackId: string, localTracks: MusicTrack[]): Promise<void> {
    if (trackId !== localTracks.find((t: MusicTrack) => t.id === trackId)?.id) return;
    let currentTrack = localTracks.find((track: MusicTrack) => track.id === trackId);
    if (!currentTrack) return;
    this.lyricsTrackId = '';
    await this.loadTrackLyrics(state, currentTrack);
  }

  // Sidecar file management
  private removeManagedFileIfExists(path: string): void {
    try { if (fs.accessSync(path)) fs.unlinkSync(path); } catch (_) {}
  }

  private writeManagedTextFile(path: string, content: string): void {
    this.removeManagedFileIfExists(path);
    let outputFile = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    try { fs.writeSync(outputFile.fd, content); } finally { fs.closeSync(outputFile); }
  }

  saveTrackLyricSidecars(filePath: string, lyricResult: SourceLyricResult): boolean {
    if (filePath.trim().length === 0) return false;
    let hasUsableLyric = lyricResult.lyric.trim().length > 0 || lyricResult.lxlyric.trim().length > 0;
    if (!hasUsableLyric) return false;
    let mainLyricPath = filePath.replace(/\.[^.]+$/, '.lrc');
    let translatedLyricPath = filePath.replace(/\.[^.]+$/, '.tlyric.lrc');
    let romanizedLyricPath = filePath.replace(/\.[^.]+$/, '.rlyric.lrc');
    let lineLyricPath = filePath.replace(/\.[^.]+$/, '.lxlyric.lrc');
    if (lyricResult.lyric.trim().length > 0) this.writeManagedTextFile(mainLyricPath, lyricResult.lyric);
    else this.removeManagedFileIfExists(mainLyricPath);
    if (lyricResult.tlyric.trim().length > 0) this.writeManagedTextFile(translatedLyricPath, lyricResult.tlyric);
    else this.removeManagedFileIfExists(translatedLyricPath);
    if (lyricResult.rlyric.trim().length > 0) this.writeManagedTextFile(romanizedLyricPath, lyricResult.rlyric);
    else this.removeManagedFileIfExists(romanizedLyricPath);
    if (lyricResult.lxlyric.trim().length > 0) this.writeManagedTextFile(lineLyricPath, lyricResult.lxlyric);
    else this.removeManagedFileIfExists(lineLyricPath);
    return true;
  }

  // Lyric repair
  async repairMissingImportedTrackLyrics(state: LyricState, localTracks: MusicTrack[]): Promise<void> {
    if (state.lyricRepairingTrackIds.length > 0) return;
    let missingLyricTracks: MusicTrack[] = [];
    let candidateTracks = localTracks.filter((track: MusicTrack) => this.isLyricRepairTrackCandidate(track));
    for (let index = 0; index < candidateTracks.length; index++) {
      let track = candidateTracks[index];
      let lyricResult = await extractTrackLyrics(track);
      if (lyricResult.lyric.trim().length === 0 && lyricResult.lxlyric.trim().length === 0) missingLyricTracks.push(track);
    }
    if (missingLyricTracks.length === 0) { this.showToast(t('lyric.no_repair_needed')); return; }
    let repairedCount = 0;
    let failedCount = 0;
    state.lyricRepairingTrackIds = missingLyricTracks.map((track: MusicTrack) => track.id);
    try {
      for (let index = 0; index < missingLyricTracks.length; index++) {
        let track = missingLyricTracks[index];
        try {
          let repaired = await this.repairLyricsForTrack(track, localTracks);
          if (repaired) repairedCount += 1; else failedCount += 1;
        } catch (_) { failedCount += 1; }
        finally { state.lyricRepairingTrackIds = state.lyricRepairingTrackIds.filter((trackId: string) => trackId !== track.id); }
      }
    } finally { state.lyricRepairingTrackIds = []; }
    if (repairedCount > 0 && failedCount > 0) this.showToast(t('lyric.repair_result', `${repairedCount}`, `${failedCount}`));
    else if (repairedCount > 0) this.showToast(t('lyric.repair_result_only', `${repairedCount}`));
    else this.showToast(t('lyric.no_match'));
  }

  private isLyricRepairTrackCandidate(track: MusicTrack): boolean {
    let sourceImportKey = track.sourceImportKey ?? '';
    if (!track.isImported || track.filePath.trim().length === 0) return false;
    if (sourceImportKey.startsWith('baidupan:')) return false;
    return track.folder === 'downloads' || sourceImportKey.length > 0;
  }

  private async repairLyricsForTrack(track: MusicTrack, localTracks: MusicTrack[]): Promise<boolean> {
    let matchedTracks = await this.findLyricRepairMatches(track);
    if (matchedTracks.length === 0) return false;
    for (let index = 0; index < matchedTracks.length; index++) {
      let matchedTrack = matchedTracks[index];
      try {
        let lyricResult = await fetchBuiltInSourceLyrics(matchedTrack);
        if (lyricResult === null || lyricResult.lyric.trim().length === 0) continue;
        if (!this.saveTrackLyricSidecars(track.filePath, lyricResult)) continue;
        if (this.onTrackSourceImportKeyUpdate) this.onTrackSourceImportKeyUpdate(track.id, buildSourceTrackImportKey(matchedTrack));
        return true;
      } catch (_) {}
    }
    return false;
  }

  private async findLyricRepairMatches(track: MusicTrack): Promise<MusicSourceTrack[]> {
    let keywords = [track.title.trim()];
    if (track.artist.trim().length > 0) keywords.unshift(`${track.title.trim()} ${track.artist.trim()}`);
    let scoredCandidates: [MusicSourceTrack, number][] = [];
    let seenKeys: Set<string> = new Set();
    for (let keyword of keywords) {
      for (let searchSource of LYRIC_REPAIR_SEARCH_SOURCES) {
        try {
          let result = await searchSourceTrackPage(keyword, searchSource, 1);
          for (let candidate of result.tracks.slice(0, 10)) {
            let candidateKey = `${candidate.source}:${candidate.songmid}`;
            if (seenKeys.has(candidateKey)) continue;
            seenKeys.add(candidateKey);
            let score = this.lyricRepairCandidateScore(track, candidate);
            if (score >= LYRIC_REPAIR_MIN_MATCH_SCORE) scoredCandidates.push([candidate, score]);
          }
        } catch (_) {}
      }
    }
    scoredCandidates.sort((a, b) => b[1] - a[1]);
    return scoredCandidates.map((pair) => pair[0]);
  }

  private lyricRepairCandidateScore(track: MusicTrack, candidate: MusicSourceTrack): number {
    let titleScore = this.lyricRepairFieldScore(track.title, candidate.name, 130, 98, 76);
    if (titleScore < 60) return titleScore;
    let artistScore = this.lyricRepairFieldScore(track.artist, candidate.singer, 75, 56, 34);
    let albumScore = this.lyricRepairFieldScore(track.album, candidate.album, 22, 14, 8);
    let durationScore = this.lyricRepairDurationScore(track, candidate);
    return titleScore + artistScore + albumScore + durationScore;
  }

  private lyricRepairFieldScore(target: string, candidate: string, exactScore: number, containScore: number, tokenScore: number): number {
    let normalizedTarget = target.trim().toLowerCase().replace(/[\s"'`~!！@#￥$%^&*()（）_\-+=|\\[\]{};:：,，.。/?？<>《》、·]/g, '');
    let normalizedCandidate = candidate.trim().toLowerCase().replace(/[\s"'`~!！@#￥$%^&*()（）_\-+=|\\[\]{};:：,，.。/?？<>《》、·]/g, '');
    if (normalizedTarget.length === 0 || normalizedCandidate.length === 0) return 0;
    if (normalizedTarget === normalizedCandidate) return exactScore;
    if (normalizedTarget.indexOf(normalizedCandidate) >= 0 || normalizedCandidate.indexOf(normalizedTarget) >= 0) return containScore;
    return 0;
  }

  private lyricRepairDurationScore(track: MusicTrack, candidate: MusicSourceTrack): number {
    let targetSeconds = Math.floor(track.durationMs / 1000);
    if (targetSeconds <= 0 || candidate.duration <= 0) return 0;
    let diff = Math.abs(targetSeconds - candidate.duration);
    if (diff <= 1) return 28;
    if (diff <= 3) return 22;
    if (diff <= 5) return 16;
    if (diff <= 8) return 8;
    if (diff >= 25) return -24;
    if (diff >= 15) return -12;
    return 0;
  }
}
