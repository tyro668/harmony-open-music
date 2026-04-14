import { image } from '@kit.ImageKit';
import { MusicTrack } from '../models/AppModels';
import { copyTrack } from '../utils/TrackUtils';
import {
  extractTrackDuration,
  extractTrackArtwork,
  releaseTrackArtwork as releaseExtractedTrackArtwork
} from '../services/TrackArtworkService';
import { t } from '../utils/I18nUtil';
import { BaseViewModel } from './BaseViewModel';

@Observed
export class TrackMetadataState {
  trackArtworkIds: string[] = [];
}

export class TrackMetadataViewModel extends BaseViewModel {
  private trackArtworkMap: Map<string, image.PixelMap> = new Map();
  private trackArtworkOwnerMap: Map<string, string> = new Map();
  private trackArtworkLoadingIds: Set<string> = new Set();
  private trackArtworkUnavailableIds: Set<string> = new Set();
  private trackDurationLoadingIds: Set<string> = new Set();
  private trackDurationUnavailableIds: Set<string> = new Set();

  // Callbacks
  onTrackDurationCached: ((trackId: string, durationMs: number) => void) | null = null;
  onCurrentTrackArtworkLoaded: ((trackId: string) => void) | null = null;

  trackArtworkForTrack(trackId: string): image.PixelMap | null {
    let ownerTrackId = this.trackArtworkOwnerMap.get(trackId) ?? trackId;
    return this.trackArtworkMap.get(ownerTrackId) ?? null;
  }

  syncTrackMetadataCaches(state: TrackMetadataState, localTracks: Array<MusicTrack>, currentTrackId: string): void {
    this.syncTrackArtworkCache(state, localTracks, currentTrackId);
    this.syncTrackDurationCache(localTracks, currentTrackId);
  }

  private syncTrackArtworkCache(state: TrackMetadataState, localTracks: Array<MusicTrack>, currentTrackId: string): void {
    let activeTrackIds = localTracks.map((track: MusicTrack) => track.id);
    Array.from(this.trackArtworkMap.keys()).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) void this.releaseCachedTrackArtwork(trackId, state);
    });
    Array.from(this.trackArtworkOwnerMap.keys()).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) this.trackArtworkOwnerMap.delete(trackId);
    });
    Array.from(this.trackArtworkLoadingIds).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) this.trackArtworkLoadingIds.delete(trackId);
    });
    Array.from(this.trackArtworkUnavailableIds).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) this.trackArtworkUnavailableIds.delete(trackId);
    });
    this.refreshAlbumArtworkAliases(localTracks);
    this.refreshTrackArtworkIds(state, localTracks);
    let pendingTracks: MusicTrack[] = [];
    localTracks.forEach((track: MusicTrack) => {
      let hasPlayableFile = track.filePath.length > 0 || track.sourceUri.length > 0;
      if (!hasPlayableFile || this.trackArtworkForTrack(track.id) !== null || this.trackArtworkLoadingIds.has(track.id) || this.trackArtworkUnavailableIds.has(track.id)) return;
      pendingTracks.push(track);
    });
    if (currentTrackId.length > 0) {
      let currentIdx = pendingTracks.findIndex((t: MusicTrack) => t.id === currentTrackId);
      if (currentIdx > 0) { let current = pendingTracks.splice(currentIdx, 1); pendingTracks.unshift(current[0]); }
    }
    void this.processArtworkBatch(pendingTracks, state, localTracks, currentTrackId);
  }

  private async processArtworkBatch(tracks: MusicTrack[], state: TrackMetadataState, localTracks: Array<MusicTrack>, currentTrackId: string): Promise<void> {
    const CONCURRENCY = 3;
    let index = 0;
    let running = 0;
    let processNext: () => void = () => {};
    await new Promise<void>((resolve: (value: void) => void) => {
      processNext = () => {
        while (running < CONCURRENCY && index < tracks.length) {
          let track = tracks[index++];
          running++;
          this.loadTrackArtwork(track, state, localTracks, currentTrackId).then(() => { running--; processNext(); });
        }
        if (running === 0) resolve();
      };
      processNext();
    });
  }

  private syncTrackDurationCache(localTracks: Array<MusicTrack>, currentTrackId: string): void {
    let activeTrackIds = localTracks.map((track: MusicTrack) => track.id);
    Array.from(this.trackDurationLoadingIds).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) this.trackDurationLoadingIds.delete(trackId);
    });
    Array.from(this.trackDurationUnavailableIds).forEach((trackId: string) => {
      if (activeTrackIds.indexOf(trackId) < 0) this.trackDurationUnavailableIds.delete(trackId);
    });
    let pendingTracks: MusicTrack[] = [];
    localTracks.forEach((track: MusicTrack) => {
      let hasPlayableFile = track.filePath.length > 0 || track.sourceUri.length > 0;
      if (!hasPlayableFile || track.durationMs > 0 || this.trackDurationLoadingIds.has(track.id) || this.trackDurationUnavailableIds.has(track.id)) return;
      pendingTracks.push(track);
    });
    if (currentTrackId.length > 0) {
      let currentIdx = pendingTracks.findIndex((t: MusicTrack) => t.id === currentTrackId);
      if (currentIdx > 0) { let current = pendingTracks.splice(currentIdx, 1); pendingTracks.unshift(current[0]); }
    }
    void this.processDurationBatch(pendingTracks, localTracks);
  }

  private async processDurationBatch(tracks: MusicTrack[], localTracks: Array<MusicTrack>): Promise<void> {
    const CONCURRENCY = 3;
    let index = 0;
    let running = 0;
    let processNext: () => void = () => {};
    await new Promise<void>((resolve: (value: void) => void) => {
      processNext = () => {
        while (running < CONCURRENCY && index < tracks.length) {
          let track = tracks[index++];
          running++;
          this.loadTrackDuration(track, localTracks).then(() => { running--; processNext(); });
        }
        if (running === 0) resolve();
      };
      processNext();
    });
  }

  private async loadTrackDuration(track: MusicTrack, localTracks: Array<MusicTrack>): Promise<void> {
    this.trackDurationLoadingIds.add(track.id);
    try {
      let durationMs = await extractTrackDuration(track);
      if (!localTracks.some((item: MusicTrack) => item.id === track.id)) return;
      if (durationMs <= 0) { this.trackDurationUnavailableIds.add(track.id); return; }
      this.trackDurationUnavailableIds.delete(track.id);
      if (this.onTrackDurationCached) this.onTrackDurationCached(track.id, durationMs);
    } finally {
      this.trackDurationLoadingIds.delete(track.id);
    }
  }

  private async loadTrackArtwork(track: MusicTrack, state: TrackMetadataState, localTracks: Array<MusicTrack>, currentTrackId: string): Promise<void> {
    this.trackArtworkLoadingIds.add(track.id);
    try {
      let pixelMap = await extractTrackArtwork(track);
      if (!localTracks.some((item: MusicTrack) => item.id === track.id)) { await releaseExtractedTrackArtwork(pixelMap); return; }
      if (pixelMap === null) {
        this.refreshAlbumArtworkAliases(localTracks);
        this.refreshTrackArtworkIds(state, localTracks);
        if (currentTrackId.length > 0 && this.trackArtworkForTrack(currentTrackId) !== null && this.onCurrentTrackArtworkLoaded) {
          this.onCurrentTrackArtworkLoaded(currentTrackId);
        }
        if (this.trackArtworkForTrack(track.id) !== null) return;
        this.trackArtworkUnavailableIds.add(track.id);
        return;
      }
      let previous = this.trackArtworkMap.get(track.id);
      this.trackArtworkMap.set(track.id, pixelMap);
      this.trackArtworkOwnerMap.set(track.id, track.id);
      this.trackArtworkUnavailableIds.delete(track.id);
      this.refreshAlbumArtworkAliases(localTracks);
      this.refreshTrackArtworkIds(state, localTracks);
      await releaseExtractedTrackArtwork(previous);
      if (currentTrackId.length > 0 && this.trackArtworkForTrack(currentTrackId) !== null && this.onCurrentTrackArtworkLoaded) {
        this.onCurrentTrackArtworkLoaded(currentTrackId);
      }
    } finally {
      this.trackArtworkLoadingIds.delete(track.id);
    }
  }

  private async releaseCachedTrackArtwork(trackId: string, state: TrackMetadataState): Promise<void> {
    let pixelMap = this.trackArtworkMap.get(trackId);
    this.trackArtworkMap.delete(trackId);
    Array.from(this.trackArtworkOwnerMap.entries()).forEach((entry: [string, string]) => {
      if (entry[0] === trackId || entry[1] === trackId) this.trackArtworkOwnerMap.delete(entry[0]);
    });
    this.trackArtworkLoadingIds.delete(trackId);
    this.trackArtworkUnavailableIds.delete(trackId);
    await releaseExtractedTrackArtwork(pixelMap);
  }

  private refreshAlbumArtworkAliases(localTracks: Array<MusicTrack>): void {
    localTracks.forEach((track: MusicTrack) => {
      if (this.trackArtworkMap.has(track.id)) { this.trackArtworkOwnerMap.set(track.id, track.id); return; }
      let ownerId = this.findReusableArtworkOwner(track, localTracks);
      if (ownerId.length > 0) { this.trackArtworkOwnerMap.set(track.id, ownerId); this.trackArtworkUnavailableIds.delete(track.id); return; }
      this.trackArtworkOwnerMap.delete(track.id);
    });
  }

  private findReusableArtworkOwner(track: MusicTrack, localTracks: Array<MusicTrack>): string {
    for (let index = 0; index < localTracks.length; index++) {
      let candidate = localTracks[index];
      if (candidate.id === track.id) continue;
      if (!this.canShareArtworkBetweenTracks(track, candidate)) continue;
      let candidateOwnerId = this.trackArtworkOwnerMap.get(candidate.id) ?? candidate.id;
      if (this.trackArtworkMap.has(candidateOwnerId)) return candidateOwnerId;
    }
    return '';
  }

  private canShareArtworkBetweenTracks(track: MusicTrack, candidate: MusicTrack): boolean {
    let trackAlbum = this.normalizedArtworkAlbum(track);
    let candidateAlbum = this.normalizedArtworkAlbum(candidate);
    if (trackAlbum.length > 0 && candidateAlbum.length > 0) return trackAlbum === candidateAlbum;
    let trackFolder = this.normalizedArtworkFolder(track);
    let candidateFolder = this.normalizedArtworkFolder(candidate);
    return trackAlbum.length === 0 && candidateAlbum.length === 0 && trackFolder.length > 0 && trackFolder === candidateFolder;
  }

  private normalizedArtworkAlbum(track: MusicTrack): string {
    let album = track.album.trim().toLowerCase();
    if (album.length === 0 || album === t('track.network_import').trim().toLowerCase()) return '';
    return album;
  }

  private normalizedArtworkFolder(track: MusicTrack): string {
    let folder = track.folder.trim().toLowerCase();
    if (folder.length === 0 || folder === t('track.online_download').trim().toLowerCase() || folder === 'downloads') return '';
    return folder;
  }

  private refreshTrackArtworkIds(state: TrackMetadataState, localTracks: Array<MusicTrack>): void {
    state.trackArtworkIds = localTracks.filter((track: MusicTrack) => this.trackArtworkForTrack(track.id) !== null).map((track: MusicTrack) => track.id);
  }

  dispose(): void {
    Array.from(this.trackArtworkMap.values()).forEach((pixelMap: image.PixelMap) => {
      void releaseExtractedTrackArtwork(pixelMap);
    });
    this.trackArtworkMap.clear();
    this.trackArtworkOwnerMap.clear();
  }
}
