import { t } from '../utils/I18nUtil';
import { http } from '@kit.NetworkKit';

import { AUDIO_EXTENSIONS, ONLINE_DOWNLOAD_MAX_BYTES } from '../constants/AppConstants';
import { BaiduPanEntry } from '../models/AppModels';

const BAIDU_PAN_API_ROOT: string = 'https://pan.baidu.com/rest/2.0';
const BAIDU_PAN_OAUTH_AUTHORIZE_URL: string = 'https://openapi.baidu.com/oauth/2.0/authorize';
const BAIDU_PAN_USER_AGENT: string = 'Mozilla/5.0 (HarmonyOS Music Player)';
const MAX_REDIRECT_COUNT: number = 3;

export interface BaiduPanOAuthResult {
  accessToken: string;
  expiresInMs: number;
  errorMessage: string;
}

function authHeaders(accessToken: string): Record<string, string> {
  return {
    'Authorization': `Bearer ${accessToken}`,
    'User-Agent': BAIDU_PAN_USER_AGENT
  };
}

function apiErrorMessage(body: Record<string, Object>): string {
  let errorCode = Number(body['errno'] as number || body['error_code'] as number || 0);
  let message = body['errmsg'] as string || body['error_msg'] as string || '';
  if (errorCode === -6 || errorCode === 111 || errorCode === 31045) {
    return t('baidu.token_invalid');
  }
  if (message.length > 0) {
    return message;
  }
  return errorCode !== 0 ? t('baidu.api_error', `${errorCode}`) : t('baidu.api_exception');
}

function headerValue(header: Object, name: string): string {
  let targetName = name.toLowerCase();
  let headerRecord = header as Record<string, Object>;
  let headerKeys = Object.keys(headerRecord);
  for (let index = 0; index < headerKeys.length; index++) {
    let key = headerKeys[index];
    if (key.toLowerCase() !== targetName) {
      continue;
    }
    let value = headerRecord[key];
    if (typeof value === 'string') {
      return value;
    }
    if (Array.isArray(value) && value.length > 0 && typeof value[0] === 'string') {
      return value[0] as string;
    }
  }
  return '';
}

function safeDecodeURIComponent(value: string): string {
  try {
    return decodeURIComponent(value.replace(/\+/g, '%20'));
  } catch (_) {
    return value;
  }
}

function unwrapJavaScriptStringValue(rawValue: string): string {
  let trimmed = rawValue.trim();
  if (trimmed.length < 2) {
    return trimmed;
  }
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith('\'') && trimmed.endsWith('\''))) {
    try {
      return JSON.parse(trimmed) as string;
    } catch (_) {
      return trimmed.substring(1, trimmed.length - 1);
    }
  }
  return trimmed;
}

function parseUrlEncodedPart(payload: string, separator: string, result: Record<string, string>): void {
  let separatorIndex = payload.indexOf(separator);
  if (separatorIndex < 0 || separatorIndex >= payload.length - 1) {
    return;
  }
  let segment = payload.substring(separatorIndex + 1);
  let endIndex = segment.indexOf('\n');
  if (endIndex >= 0) {
    segment = segment.substring(0, endIndex);
  }
  segment.split('&').forEach((item: string) => {
    if (item.length === 0) {
      return;
    }
    let equalIndex = item.indexOf('=');
    if (equalIndex < 0) {
      result[safeDecodeURIComponent(item)] = '';
      return;
    }
    let key = safeDecodeURIComponent(item.substring(0, equalIndex));
    let value = safeDecodeURIComponent(item.substring(equalIndex + 1));
    result[key] = value;
  });
}

function collectOAuthValues(rawPayload: string): Record<string, string> {
  let payload = unwrapJavaScriptStringValue(rawPayload);
  let values: Record<string, string> = {};
  parseUrlEncodedPart(payload, '?', values);
  parseUrlEncodedPart(payload, '#', values);
  if (Object.keys(values).length > 0) {
    return values;
  }

  let tokenMatch = payload.match(/access_token=([^&\s]+)/);
  if (tokenMatch && tokenMatch[1]) {
    values['access_token'] = safeDecodeURIComponent(tokenMatch[1]);
  }
  let expiresMatch = payload.match(/expires_in=([^&\s]+)/);
  if (expiresMatch && expiresMatch[1]) {
    values['expires_in'] = safeDecodeURIComponent(expiresMatch[1]);
  }
  let errorMatch = payload.match(/error(?:_description)?=([^&\s]+)/);
  if (errorMatch && errorMatch[1]) {
    values['error'] = safeDecodeURIComponent(errorMatch[1]);
  }
  return values;
}

export function normalizeBaiduPanPath(path: string): string {
  let trimmed = path.trim();
  if (trimmed.length === 0) {
    return '/';
  }
  let normalized = trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
  while (normalized.indexOf('//') >= 0) {
    normalized = normalized.replace('//', '/');
  }
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized.length > 0 ? normalized : '/';
}

export function parentBaiduPanPath(path: string): string {
  let normalized = normalizeBaiduPanPath(path);
  if (normalized === '/') {
    return '/';
  }
  let lastSlashIndex = normalized.lastIndexOf('/');
  if (lastSlashIndex <= 0) {
    return '/';
  }
  return normalized.substring(0, lastSlashIndex);
}

export function baiduPanParentLabel(path: string): string {
  let parentPath = parentBaiduPanPath(path);
  if (parentPath === '/') {
    return t('baidu.name');
  }
  let lastSlashIndex = parentPath.lastIndexOf('/');
  if (lastSlashIndex < 0 || lastSlashIndex >= parentPath.length - 1) {
    return parentPath;
  }
  return parentPath.substring(lastSlashIndex + 1);
}

export function isBaiduPanAudioFileName(fileName: string): boolean {
  let lowerCaseName = fileName.toLowerCase();
  return AUDIO_EXTENSIONS.some((extension: string) => lowerCaseName.endsWith(extension));
}

export function buildBaiduPanOAuthAuthorizeUrl(appKey: string, state: string = ''): string {
  let trimmedAppKey = appKey.trim();
  let stateValue = state.trim().length > 0 ? state.trim() : `${Date.now()}`;
  return (
    `${BAIDU_PAN_OAUTH_AUTHORIZE_URL}?response_type=token` +
    `&client_id=${encodeURIComponent(trimmedAppKey)}` +
    `&redirect_uri=${encodeURIComponent('oob')}` +
    `&scope=${encodeURIComponent('basic,netdisk')}` +
    `&display=${encodeURIComponent('popup')}` +
    `&state=${encodeURIComponent(stateValue)}`
  );
}

export function parseBaiduPanOAuthPayload(rawPayload: string): BaiduPanOAuthResult {
  let values = collectOAuthValues(rawPayload);
  let accessToken = values['access_token'] ?? '';
  let expiresInMs = Math.max(0, Number(values['expires_in'] ?? '0')) * 1000;
  if (accessToken.length > 0) {
    return {
      accessToken,
      expiresInMs,
      errorMessage: ''
    };
  }
  let error = values['error'] ?? '';
  if (error.length > 0) {
    let detail = values['error_description'] ?? '';
    return {
      accessToken: '',
      expiresInMs: 0,
      errorMessage: detail.length > 0 ? `${error}: ${detail}` : error
    };
  }
  return {
    accessToken: '',
    expiresInMs: 0,
    errorMessage: ''
  };
}

export function parseBaiduPanListPayload(payload: string, currentDir: string): BaiduPanEntry[] {
  let body = JSON.parse(payload) as Record<string, Object>;
  let errorCode = Number(body['errno'] as number || 0);
  if (errorCode !== 0) {
    throw new Error(apiErrorMessage(body));
  }
  let items = body['list'] as Record<string, Object>[];
  if (!items || !Array.isArray(items)) {
    return [];
  }
  let entries: BaiduPanEntry[] = [];
  items.forEach((item: Record<string, Object>) => {
    let fileName = item['server_filename'] as string || '';
    let path = normalizeBaiduPanPath(item['path'] as string || currentDir);
    let isDirectory = Number(item['isdir'] as number || 0) === 1;
    if (!isDirectory && !isBaiduPanAudioFileName(fileName)) {
      return;
    }
    entries.push({
      fsId: `${item['fs_id'] as number || item['fsid'] as number || 0}`,
      name: fileName.length > 0 ? fileName : path,
      path: path,
      isDirectory: isDirectory,
      size: Number(item['size'] as number || 0),
      modifiedAt: Number(item['server_mtime'] as number || item['local_mtime'] as number || 0)
    });
  });
  entries.sort((left: BaiduPanEntry, right: BaiduPanEntry) => {
    if (left.isDirectory !== right.isDirectory) {
      return left.isDirectory ? -1 : 1;
    }
    return left.name.localeCompare(right.name, 'zh-Hans-CN');
  });
  return entries;
}

async function requestBinaryWithRedirect(
  url: string,
  headers: Record<string, string>,
  redirectCount: number = 0
): Promise<ArrayBuffer> {
  let request = http.createHttp();
  try {
    let response = await request.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      readTimeout: 60000,
      connectTimeout: 15000,
      usingCache: false,
      maxLimit: ONLINE_DOWNLOAD_MAX_BYTES,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      header: headers
    });
    if (response.responseCode >= 300 && response.responseCode < 400 && redirectCount < MAX_REDIRECT_COUNT) {
      let location = headerValue(response.header, 'location');
      if (location.length > 0) {
        return await requestBinaryWithRedirect(location, headers, redirectCount + 1);
      }
    }
    if (response.responseCode < 200 || response.responseCode >= 300) {
      let errorText = response.resultType === http.HttpDataType.STRING ? response.result as string : '';
      throw new Error(errorText.length > 0 ? errorText : `http ${response.responseCode}`);
    }
    let buffer = response.result as ArrayBuffer;
    if (!(buffer instanceof ArrayBuffer) || buffer.byteLength === 0) {
      throw new Error('empty file buffer');
    }
    return buffer;
  } finally {
    request.destroy();
  }
}

export async function fetchBaiduPanDirectory(accessToken: string, dir: string): Promise<BaiduPanEntry[]> {
  let normalizedDir = normalizeBaiduPanPath(dir);
  let request = http.createHttp();
  try {
    let url =
      `${BAIDU_PAN_API_ROOT}/xpan/file?method=list&dir=${encodeURIComponent(normalizedDir)}` +
      `&folder=0&order=name&desc=0&limit=200&start=0&web=1&access_token=${encodeURIComponent(accessToken)}`;
    let response = await request.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      readTimeout: 20000,
      connectTimeout: 10000,
      usingCache: false,
      usingProtocol: http.HttpProtocol.HTTP1_1,
      header: authHeaders(accessToken)
    });
    if (response.responseCode !== 200) {
      throw new Error(`http ${response.responseCode}`);
    }
    return parseBaiduPanListPayload(response.result as string, normalizedDir);
  } finally {
    request.destroy();
  }
}

export async function downloadBaiduPanAudio(accessToken: string, path: string): Promise<ArrayBuffer> {
  let normalizedPath = normalizeBaiduPanPath(path);
  let url =
    `${BAIDU_PAN_API_ROOT}/xpan/file?method=download&path=${encodeURIComponent(normalizedPath)}` +
    `&access_token=${encodeURIComponent(accessToken)}`;
  return await requestBinaryWithRedirect(url, authHeaders(accessToken));
}
