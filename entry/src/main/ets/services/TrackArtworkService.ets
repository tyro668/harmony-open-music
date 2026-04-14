import { media } from '@kit.MediaKit';
import { fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import fs from '@ohos.file.fs';

import { MusicTrack } from '../models/AppModels';
import { lineLyricFromLxLyric } from '../utils/LyricsParser';

const TRACK_ARTWORK_DOWNLOAD_MAX_BYTES: number = 8 * 1024 * 1024;

function resolveTrackArtworkPath(track: MusicTrack): string {
  if (track.filePath.length > 0) {
    return track.filePath;
  }
  if (track.sourceUri.length > 0) {
    return new fileUri.FileUri(track.sourceUri).path;
  }
  return '';
}

export async function extractTrackDuration(track: MusicTrack): Promise<number> {
  let playablePath = resolveTrackArtworkPath(track);
  if (playablePath.length === 0) {
    return 0;
  }

  let extractor = await media.createAVMetadataExtractor();
  let openedFile: fs.File | null = null;
  try {
    openedFile = fs.openSync(playablePath, fs.OpenMode.READ_ONLY);
    let stat = fs.statSync(openedFile.fd);
    extractor.fdSrc = {
      fd: openedFile.fd,
      offset: 0,
      length: stat.size
    };
    let metadata = await extractor.fetchMetadata();
    let durationText = typeof metadata.duration === 'string' ? metadata.duration : '';
    let durationMs = parseInt(durationText, 10);
    return !isNaN(durationMs) && durationMs > 0 ? durationMs : 0;
  } catch (_) {
    return 0;
  } finally {
    try {
      await extractor.release();
    } catch (_) {
      // ignore extractor cleanup failures
    }
    if (openedFile !== null) {
      try {
        fs.closeSync(openedFile);
      } catch (_) {
        // ignore file cleanup failures
      }
    }
  }
}

function remoteTrackArtworkUrl(track: MusicTrack): string {
  let pic = track.pic.trim();
  if (pic.startsWith('https://') || pic.startsWith('http://')) {
    return pic;
  }
  return '';
}

async function extractEmbeddedTrackArtwork(track: MusicTrack): Promise<image.PixelMap | null> {
  let playablePath = resolveTrackArtworkPath(track);
  if (playablePath.length === 0) {
    return null;
  }

  let extractor = await media.createAVMetadataExtractor();
  let openedFile: fs.File | null = null;
  try {
    openedFile = fs.openSync(playablePath, fs.OpenMode.READ_ONLY);
    let stat = fs.statSync(openedFile.fd);
    extractor.fdSrc = {
      fd: openedFile.fd,
      offset: 0,
      length: stat.size
    };
    return await extractor.fetchAlbumCover();
  } catch (_) {
    return null;
  } finally {
    try {
      await extractor.release();
    } catch (_) {
      // ignore extractor cleanup failures
    }
    if (openedFile !== null) {
      try {
        fs.closeSync(openedFile);
      } catch (_) {
        // ignore file cleanup failures
      }
    }
  }
}

async function extractRemoteTrackArtwork(track: MusicTrack): Promise<image.PixelMap | null> {
  let coverUrl = remoteTrackArtworkUrl(track);
  if (coverUrl.length === 0) {
    return null;
  }

  let httpClient = http.createHttp();
  try {
    let response = await httpClient.request(coverUrl, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      readTimeout: 20000,
      connectTimeout: 10000,
      usingCache: false,
      maxLimit: TRACK_ARTWORK_DOWNLOAD_MAX_BYTES,
      header: { 'User-Agent': 'Mozilla/5.0 (HarmonyOS Music Player)' } as Record<string, string>
    });
    if (response.responseCode < 200 || response.responseCode >= 300) {
      return null;
    }
    let imageBuffer = response.result as ArrayBuffer;
    if (!(imageBuffer instanceof ArrayBuffer) || imageBuffer.byteLength === 0) {
      return null;
    }
    let imageSource = image.createImageSource(imageBuffer.slice(0, imageBuffer.byteLength));
    return await imageSource.createPixelMap();
  } catch (_) {
    return null;
  } finally {
    httpClient.destroy();
  }
}

export async function extractTrackArtwork(track: MusicTrack): Promise<image.PixelMap | null> {
  let embeddedArtwork = await extractEmbeddedTrackArtwork(track);
  if (embeddedArtwork !== null) {
    return embeddedArtwork;
  }
  return await extractRemoteTrackArtwork(track);
}

export async function savePixelMapToFile(pixelMap: image.PixelMap, filePath: string): Promise<void> {
  let imagePacker = image.createImagePacker();
  let packOpts: image.PackingOption = {
    format: 'image/jpeg',
    quality: 90
  };
  let arrayBuffer = await imagePacker.packing(pixelMap, packOpts);
  let file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
  try {
    fs.writeSync(file.fd, arrayBuffer);
  } finally {
    fs.closeSync(file.fd);
  }
}

export async function releaseTrackArtwork(pixelMap: image.PixelMap | null | undefined): Promise<void> {
  if (pixelMap === null || pixelMap === undefined) {
    return;
  }
  try {
    await pixelMap.release();
  } catch (_) {
    // ignore pixel map cleanup failures
  }
}

export interface TrackLyricsResult {
  lyric: string;
  tlyric: string;
  rlyric: string;
  lxlyric: string;
}

export async function extractTrackLyrics(track: MusicTrack): Promise<TrackLyricsResult> {
  let result: TrackLyricsResult = { lyric: '', tlyric: '', rlyric: '', lxlyric: '' };
  let playablePath = resolveTrackArtworkPath(track);
  if (playablePath.length === 0) {
    return result;
  }
  // Load main .lrc file
  let lrcPath = playablePath.replace(/\.[^.]+$/, '.lrc');
  try {
    let exists = fs.accessSync(lrcPath);
    if (exists) {
      let content = fs.readTextSync(lrcPath);
      if (content.length > 0) {
        result.lyric = content;
      }
    }
  } catch (_) {
    // .lrc file not found or unreadable
  }
  // Load line-by-line .lxlyric.lrc file and fall back to it if plain lrc is absent
  let lxlyricPath = playablePath.replace(/\.[^.]+$/, '.lxlyric.lrc');
  try {
    let exists = fs.accessSync(lxlyricPath);
    if (exists) {
      let content = fs.readTextSync(lxlyricPath);
      if (content.length > 0) {
        result.lxlyric = content;
      }
    }
  } catch (_) {
    // lxlyric file not found or unreadable
  }
  if (result.lyric.length === 0 && result.lxlyric.length > 0) {
    result.lyric = lineLyricFromLxLyric(result.lxlyric);
  }
  if (result.lyric.length === 0) {
    return result;
  }
  // Load translated .tlyric.lrc file
  let tlyricPath = playablePath.replace(/\.[^.]+$/, '.tlyric.lrc');
  try {
    let exists = fs.accessSync(tlyricPath);
    if (exists) {
      let content = fs.readTextSync(tlyricPath);
      if (content.length > 0) {
        result.tlyric = content;
      }
    }
  } catch (_) {
    // translated lyric file not found or unreadable
  }
  // Load romanized .rlyric.lrc file
  let rlyricPath = playablePath.replace(/\.[^.]+$/, '.rlyric.lrc');
  try {
    let exists = fs.accessSync(rlyricPath);
    if (exists) {
      let content = fs.readTextSync(rlyricPath);
      if (content.length > 0) {
        result.rlyric = content;
      }
    }
  } catch (_) {
    // romanized lyric file not found or unreadable
  }
  return result;
}
