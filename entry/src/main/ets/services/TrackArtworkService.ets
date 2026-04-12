import { media } from '@kit.MediaKit';
import { fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import fs from '@ohos.file.fs';

import { MusicTrack } from '../models/AppModels';

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

export async function extractTrackArtwork(track: MusicTrack): Promise<image.PixelMap | null> {
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

export async function extractTrackLyrics(track: MusicTrack): Promise<string> {
  // Try external .lrc file next to the audio file
  let playablePath = resolveTrackArtworkPath(track);
  if (playablePath.length > 0) {
    let lrcPath = playablePath.replace(/\.[^.]+$/, '.lrc');
    try {
      let exists = fs.accessSync(lrcPath);
      if (exists) {
        let content = fs.readTextSync(lrcPath);
        if (content.length > 0) {
          return content;
        }
      }
    } catch (_) {
      // .lrc file not found or unreadable
    }
  }
  return '';
}
