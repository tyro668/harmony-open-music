import {
  LxSourceParseResult,
  MusicQualityType,
  MusicSourceConfig,
  MusicSourceTrack,
  MusicSourceQuality,
  PersistedMusicSourceConfig
} from '../models/AppModels';
import { MUSIC_SOURCE_INFO_LIMITS } from '../constants/AppConstants';

export function normalizeMusicSourceQuality(item: MusicSourceQuality): MusicSourceQuality {
  let qualitys = Array.isArray(item.qualitys) ? item.qualitys.filter((quality: string) => typeof quality === 'string' && quality.length > 0) : [];
  return {
    source: typeof item.source === 'string' ? item.source : '',
    qualitys: qualitys
  };
}

export function defaultMusicSources(): MusicSourceQuality[] {
  let sources: MusicSourceQuality[] = [];
  let defaultNames: string[] = ['wy', 'kw', 'kg', 'tx', 'mg'];
  for (let index = 0; index < defaultNames.length; index++) {
    let source = defaultNames[index];
    sources.push({ source: source, qualitys: ['128k', '320k', 'flac'] });
  }
  return sources;
}

export function normalizeMusicSource(source: PersistedMusicSourceConfig): MusicSourceConfig {
  let normalizedSources = Array.isArray(source.musicSources)
    ? source.musicSources
      .filter((item: MusicSourceQuality) => item && typeof item.source === 'string' && item.source.length > 0)
      .map((item: MusicSourceQuality) => normalizeMusicSourceQuality(item))
    : [];
  return {
    id: source.id,
    name: typeof source.name === 'string' && source.name.length > 0 ? source.name : '自定义音源',
    description: typeof source.description === 'string' ? source.description : '',
    author: typeof source.author === 'string' ? source.author : '',
    homepage: typeof source.homepage === 'string' ? source.homepage : '',
    version: typeof source.version === 'string' && source.version.length > 0 ? source.version : '1.0.0',
    allowShowUpdateAlert: source.allowShowUpdateAlert !== false,
    apiUrl: typeof source.apiUrl === 'string' ? source.apiUrl : '',
    apiKey: typeof source.apiKey === 'string' ? source.apiKey : '',
    musicSources: normalizedSources.length > 0 ? normalizedSources : defaultMusicSources()
  };
}

export function isSupportedExploreSource(source: string): boolean {
  return source === 'kw' || source === 'kg' || source === 'mg' || source === 'tx' || source === 'wy';
}

export function filterSupportedExploreSources(sources: MusicSourceQuality[]): MusicSourceQuality[] {
  return sources.filter((item: MusicSourceQuality) => {
    return item.source !== 'local' && isSupportedExploreSource(item.source);
  });
}

export function parseLxSourceScriptInfo(script: string): Record<string, string> {
  let infos: Record<string, string> = {
    'name': '',
    'description': '',
    'author': '',
    'homepage': '',
    'version': ''
  };
  let commentMatch = /^\/\*[\S|\s]+?\*\//.exec(script);
  if (!commentMatch) {
    throw new Error('无效的自定义源文件');
  }
  let infoLines = commentMatch[0].split(/\r?\n/);
  let infoRegex = /^\s?\*\s?@(\w+)\s(.+)$/;
  for (let index = 0; index < infoLines.length; index++) {
    let line = infoLines[index];
    let match = infoRegex.exec(line);
    if (!match) {
      continue;
    }
    let key = match[1];
    if (MUSIC_SOURCE_INFO_LIMITS[key] == null) {
      continue;
    }
    infos[key] = match[2].trim();
  }

  let keys = Object.keys(MUSIC_SOURCE_INFO_LIMITS);
  for (let index = 0; index < keys.length; index++) {
    let key = keys[index];
    let maxLength = MUSIC_SOURCE_INFO_LIMITS[key];
    let value = infos[key] || '';
    if (value.length > maxLength) {
      infos[key] = `${value.substring(0, maxLength)}...`;
    }
  }
  return infos;
}

export function parseLxSourceScript(script: string): LxSourceParseResult {
  let info = parseLxSourceScriptInfo(script);
  return {
    name: info['name'],
    description: info['description'],
    author: info['author'],
    homepage: info['homepage'],
    version: info['version'],
    apiUrl: '',
    apiKey: '',
    musicSources: []
  };
}

export function simpleHash(str: string): string {
  let hash = 0;
  for (let index = 0; index < str.length; index++) {
    let char = str.charCodeAt(index);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return Math.abs(hash).toString(36);
}

export function buildSourceTrackImportKey(track: MusicSourceTrack): string {
  let identity = [
    track.source,
    track.id,
    track.songmid,
    track.hash,
    track.name,
    track.singer,
    track.album
  ].join('|');
  return `source-import-${simpleHash(identity)}`;
}

export function sourceDisplayName(code: string): string {
  if (code === 'wy') return '网易云';
  if (code === 'kw') return '酷我';
  if (code === 'kg') return '酷狗';
  if (code === 'tx') return 'QQ音乐';
  if (code === 'mg') return '咪咕';
  if (code === 'local') return '本地';
  return code;
}

export function formatSourceFileSize(size: number): string {
  if (size === 0) return '';
  if (size < 1024) return `${size}B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)}KB`;
  if (size < 1024 * 1024 * 1024) return `${(size / (1024 * 1024)).toFixed(2)}M`;
  return `${(size / (1024 * 1024 * 1024)).toFixed(2)}G`;
}

export function formatPlayTime(seconds: number): string {
  let min = Math.floor(seconds / 60);
  let sec = seconds % 60;
  return `${min < 10 ? '0' : ''}${min}:${sec < 10 ? '0' : ''}${sec}`;
}

export function buildKgQualityTypes(item: Record<string, Object>): [MusicQualityType[], Record<string, MusicQualityType>] {
  let types: MusicQualityType[] = [];
  let typeMap: Record<string, MusicQualityType> = {};
  let h128 = item['hash'] as string || '';
  let s128 = item['filesize'] as number || 0;
  let h320 = item['320hash'] as string || '';
  let s320 = item['320filesize'] as number || 0;
  let hFlac = item['sqhash'] as string || '';
  let sFlac = item['sqfilesize'] as number || 0;
  let hFlac24 = item['hash_high'] as string || '';
  let sFlac24 = item['filesize_high'] as number || 0;
  if (hFlac24.length > 0 && sFlac24 > 0) {
    let quality: MusicQualityType = { type: 'flac24bit', size: formatSourceFileSize(sFlac24), hash: hFlac24 };
    types.push(quality); typeMap['flac24bit'] = quality;
  }
  if (hFlac.length > 0 && sFlac > 0) {
    let quality: MusicQualityType = { type: 'flac', size: formatSourceFileSize(sFlac), hash: hFlac };
    types.push(quality); typeMap['flac'] = quality;
  }
  if (h320.length > 0 && s320 > 0) {
    let quality: MusicQualityType = { type: '320k', size: formatSourceFileSize(s320), hash: h320 };
    types.push(quality); typeMap['320k'] = quality;
  }
  if (h128.length > 0 && s128 > 0) {
    let quality: MusicQualityType = { type: '128k', size: formatSourceFileSize(s128), hash: h128 };
    types.push(quality); typeMap['128k'] = quality;
  }
  return [types, typeMap];
}

export function buildKgSearchQualityTypes(item: Record<string, Object>): [MusicQualityType[], Record<string, MusicQualityType>] {
  let types: MusicQualityType[] = [];
  let typeMap: Record<string, MusicQualityType> = {};
  let h128 = item['FileHash'] as string || '';
  let s128 = item['FileSize'] as number || 0;
  let h320 = item['HQFileHash'] as string || '';
  let s320 = item['HQFileSize'] as number || 0;
  let hFlac = item['SQFileHash'] as string || '';
  let sFlac = item['SQFileSize'] as number || 0;
  let hFlac24 = item['ResFileHash'] as string || '';
  let sFlac24 = item['ResFileSize'] as number || 0;
  if (hFlac24.length > 0 && sFlac24 > 0) {
    let quality: MusicQualityType = { type: 'flac24bit', size: formatSourceFileSize(sFlac24), hash: hFlac24 };
    types.push(quality); typeMap['flac24bit'] = quality;
  }
  if (hFlac.length > 0 && sFlac > 0) {
    let quality: MusicQualityType = { type: 'flac', size: formatSourceFileSize(sFlac), hash: hFlac };
    types.push(quality); typeMap['flac'] = quality;
  }
  if (h320.length > 0 && s320 > 0) {
    let quality: MusicQualityType = { type: '320k', size: formatSourceFileSize(s320), hash: h320 };
    types.push(quality); typeMap['320k'] = quality;
  }
  if (h128.length > 0 && s128 > 0) {
    let quality: MusicQualityType = { type: '128k', size: formatSourceFileSize(s128), hash: h128 };
    types.push(quality); typeMap['128k'] = quality;
  }
  return [types, typeMap];
}

export function parseKwNMinfo(nMinfo: string): [MusicQualityType[], Record<string, MusicQualityType>] {
  let types: MusicQualityType[] = [];
  let typeMap: Record<string, MusicQualityType> = {};
  if (!nMinfo || nMinfo.length === 0) return [types, typeMap];
  let infoArr = nMinfo.split(';');
  for (let index = 0; index < infoArr.length; index++) {
    let segment = infoArr[index];
    let match = segment.match('level:(\\w+),bitrate:(\\d+),format:(\\w+),size:([\\w.]+)');
    if (match && match.length >= 5) {
      let bitrate = match[2];
      let size = match[4];
      if (bitrate === '4000') {
        let quality: MusicQualityType = { type: 'flac24bit', size: size.toUpperCase(), hash: '' };
        types.push(quality); typeMap['flac24bit'] = quality;
      } else if (bitrate === '2000') {
        let quality: MusicQualityType = { type: 'flac', size: size.toUpperCase(), hash: '' };
        types.push(quality); typeMap['flac'] = quality;
      } else if (bitrate === '320') {
        let quality: MusicQualityType = { type: '320k', size: size.toUpperCase(), hash: '' };
        types.push(quality); typeMap['320k'] = quality;
      } else if (bitrate === '128') {
        let quality: MusicQualityType = { type: '128k', size: size.toUpperCase(), hash: '' };
        types.push(quality); typeMap['128k'] = quality;
      }
    }
  }
  types.reverse();
  return [types, typeMap];
}

export function parseMgQualityTypes(newRateFormats: Record<string, Object>[]): [MusicQualityType[], Record<string, MusicQualityType>] {
  let types: MusicQualityType[] = [];
  let typeMap: Record<string, MusicQualityType> = {};
  if (!newRateFormats) return [types, typeMap];
  for (let index = 0; index < newRateFormats.length; index++) {
    let format = newRateFormats[index];
    let formatType = format['formatType'] as string || '';
    let size = format['size'] as string || format['androidSize'] as string || '';
    let sizeNum = parseInt(size);
    let sizeStr = Number.isNaN(sizeNum) ? size : formatSourceFileSize(sizeNum);
    let typeStr = '';
    if (formatType === 'PQ') typeStr = '128k';
    else if (formatType === 'HQ') typeStr = '320k';
    else if (formatType === 'SQ') typeStr = 'flac';
    else if (formatType === 'ZQ') typeStr = 'flac24bit';
    if (typeStr.length > 0) {
      let quality: MusicQualityType = { type: typeStr, size: sizeStr, hash: '' };
      types.push(quality); typeMap[typeStr] = quality;
    }
  }
  return [types, typeMap];
}

export function buildTxQualityTypes(file: Record<string, Object>): [MusicQualityType[], Record<string, MusicQualityType>] {
  let types: MusicQualityType[] = [];
  let typeMap: Record<string, MusicQualityType> = {};
  let s128 = file['size_128mp3'] as number || 0;
  let s320 = file['size_320mp3'] as number || 0;
  let sFlac = file['size_flac'] as number || 0;
  let sHires = file['size_hires'] as number || 0;
  if (sHires > 0) {
    let quality: MusicQualityType = { type: 'flac24bit', size: formatSourceFileSize(sHires), hash: '' };
    types.push(quality); typeMap['flac24bit'] = quality;
  }
  if (sFlac > 0) {
    let quality: MusicQualityType = { type: 'flac', size: formatSourceFileSize(sFlac), hash: '' };
    types.push(quality); typeMap['flac'] = quality;
  }
  if (s320 > 0) {
    let quality: MusicQualityType = { type: '320k', size: formatSourceFileSize(s320), hash: '' };
    types.push(quality); typeMap['320k'] = quality;
  }
  if (s128 > 0) {
    let quality: MusicQualityType = { type: '128k', size: formatSourceFileSize(s128), hash: '' };
    types.push(quality); typeMap['128k'] = quality;
  }
  return [types, typeMap];
}

export function buildWyQualityTypes(item: Record<string, Object>, privilege: Record<string, Object> | null): [MusicQualityType[], Record<string, MusicQualityType>] {
  let types: MusicQualityType[] = [];
  let typeMap: Record<string, MusicQualityType> = {};
  let maxbr = privilege ? privilege['maxbr'] as number || 0 : 999000;
  let hr = item['hr'] as Record<string, Object> | null;
  let sq = item['sq'] as Record<string, Object> | null;
  let h = item['h'] as Record<string, Object> | null;
  let l = item['l'] as Record<string, Object> | null;
  if (hr && maxbr >= 999000) {
    let size = hr['size'] as number || 0;
    let quality: MusicQualityType = { type: 'flac24bit', size: formatSourceFileSize(size), hash: '' };
    types.push(quality); typeMap['flac24bit'] = quality;
  }
  if (sq && maxbr >= 999000) {
    let size = sq['size'] as number || 0;
    let quality: MusicQualityType = { type: 'flac', size: formatSourceFileSize(size), hash: '' };
    types.push(quality); typeMap['flac'] = quality;
  }
  if (h && maxbr >= 320000) {
    let size = h['size'] as number || 0;
    let quality: MusicQualityType = { type: '320k', size: formatSourceFileSize(size), hash: '' };
    types.push(quality); typeMap['320k'] = quality;
  }
  if (l && maxbr >= 128000) {
    let size = l['size'] as number || 0;
    let quality: MusicQualityType = { type: '128k', size: formatSourceFileSize(size), hash: '' };
    types.push(quality); typeMap['128k'] = quality;
  }
  if (types.length === 0) {
    let q128: MusicQualityType = { type: '128k', size: '', hash: '' };
    let q320: MusicQualityType = { type: '320k', size: '', hash: '' };
    types.push(q128, q320);
    typeMap['128k'] = q128;
    typeMap['320k'] = q320;
  }
  return [types, typeMap];
}
