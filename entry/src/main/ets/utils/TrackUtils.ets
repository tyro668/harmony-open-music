import { fileUri } from '@kit.CoreFileKit';

import { AUDIO_EXTENSIONS, COLOR_PALETTE } from '../constants/AppConstants';
import { MusicTrack } from '../models/AppModels';

export function copyTrack(track: MusicTrack): MusicTrack {
  return {
    id: track.id,
    title: track.title,
    artist: track.artist,
    album: track.album,
    durationMs: typeof track.durationMs === 'number' && track.durationMs > 0 ? track.durationMs : 0,
    folder: track.folder,
    sourceUri: track.sourceUri,
    filePath: track.filePath,
    rawFileName: track.rawFileName ?? '',
    accentColor: track.accentColor,
    pic: track.pic ?? '',
    isFavorite: track.isFavorite,
    isImported: track.isImported,
    inPlayQueue: track.inPlayQueue !== false,
    playCount: track.playCount,
    lastPlayedAt: track.lastPlayedAt,
    sourceImportKey: track.sourceImportKey
  };
}

export function safeDecode(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch (_) {
    return value;
  }
}

export function removeExtension(fileName: string): string {
  let lastDotIndex = fileName.lastIndexOf('.');
  if (lastDotIndex <= 0) {
    return fileName;
  }
  return fileName.substring(0, lastDotIndex);
}

export function folderFromPath(path: string): string {
  if (!path || path.length === 0) {
    return '本地音乐';
  }
  let parts = path.split('/');
  if (parts.length < 2) {
    return '本地音乐';
  }
  return safeDecode(parts[parts.length - 2]);
}

export function colorForSeed(seed: string): string {
  let total = 0;
  for (let index = 0; index < seed.length; index++) {
    total += seed.charCodeAt(index);
  }
  return COLOR_PALETTE[total % COLOR_PALETTE.length];
}

export function sanitizeFileName(fileName: string): string {
  let sanitized = fileName.replace(/[\\/:*?"<>|]/g, '_').trim();
  return sanitized.length > 0 ? sanitized : 'online-track.mp3';
}

export function originFromUrl(url: string): string {
  let protocolEnd = url.indexOf('://');
  if (protocolEnd < 0) {
    return '';
  }
  let hostStart = protocolEnd + 3;
  let pathStart = url.indexOf('/', hostStart);
  if (pathStart < 0) {
    return url;
  }
  return url.substring(0, pathStart);
}

export function fileNameFromUrl(url: string): string {
  let trimmed = url.trim();
  let hashIndex = trimmed.indexOf('#');
  if (hashIndex >= 0) {
    trimmed = trimmed.substring(0, hashIndex);
  }
  let queryIndex = trimmed.indexOf('?');
  if (queryIndex >= 0) {
    trimmed = trimmed.substring(0, queryIndex);
  }
  let lastSlashIndex = trimmed.lastIndexOf('/');
  let fileName = lastSlashIndex >= 0 ? trimmed.substring(lastSlashIndex + 1) : trimmed;
  fileName = sanitizeFileName(safeDecode(fileName));
  let lowerCaseFileName = fileName.toLowerCase();
  let hasSupportedExtension = AUDIO_EXTENSIONS.some((extension: string) => lowerCaseFileName.endsWith(extension));
  if (!hasSupportedExtension) {
    if (fileName.indexOf('.') < 0) {
      fileName = `${fileName}.mp3`;
    } else {
      throw new Error('unsupported online audio extension');
    }
  }
  return fileName;
}

export function buildDownloadedTrack(filePath: string, downloadUrl: string, currentCount: number): MusicTrack {
  let fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
  try {
    fileName = fileNameFromUrl(downloadUrl);
  } catch (_) {
    fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
  }
  let baseName = removeExtension(fileName);
  let title = safeDecode(baseName);
  let artist = '在线下载';
  let dividerIndex = title.indexOf(' - ');
  if (dividerIndex > 0 && dividerIndex < title.length - 3) {
    artist = title.substring(0, dividerIndex).trim();
    title = title.substring(dividerIndex + 3).trim();
  }
  return {
    id: `online-${currentCount}-${Date.now()}`,
    title: title.length > 0 ? title : fileName,
    artist: artist,
    album: '网络导入',
    durationMs: 0,
    folder: '在线下载',
    sourceUri: '',
    filePath: filePath,
    rawFileName: '',
    accentColor: colorForSeed(downloadUrl),
    pic: '',
    isFavorite: false,
    isImported: true,
    inPlayQueue: true,
    playCount: 0,
    lastPlayedAt: 0
  };
}

export function buildImportedTrack(uri: string, currentCount: number): MusicTrack {
  let uriObject = new fileUri.FileUri(uri);
  let realPath = uriObject.path;
  let rawName = uriObject.name;
  let fileName = safeDecode(rawName);
  let baseName = removeExtension(fileName);
  let title = baseName;
  let artist = '本地导入';
  let dividerIndex = baseName.indexOf(' - ');
  if (dividerIndex > 0 && dividerIndex < baseName.length - 3) {
    artist = baseName.substring(0, dividerIndex).trim();
    title = baseName.substring(dividerIndex + 3).trim();
  }
  let album = folderFromPath(realPath);
  return {
    id: `local-${currentCount}-${Date.now()}`,
    title: title.length > 0 ? title : fileName,
    artist: artist,
    album: album,
    durationMs: 0,
    folder: folderFromPath(realPath),
    sourceUri: uri,
    filePath: realPath,
    rawFileName: '',
    accentColor: colorForSeed(uri),
    pic: '',
    isFavorite: false,
    isImported: true,
    inPlayQueue: true,
    playCount: 0,
    lastPlayedAt: 0
  };
}

export function formatDurationMs(ms: number): string {
  if (ms <= 0) {
    return '00:00';
  }
  let totalSeconds = Math.floor(ms / 1000);
  let minutes = Math.floor(totalSeconds / 60);
  let seconds = totalSeconds % 60;
  let minuteText = minutes < 10 ? `0${minutes}` : `${minutes}`;
  let secondText = seconds < 10 ? `0${seconds}` : `${seconds}`;
  return `${minuteText}:${secondText}`;
}
