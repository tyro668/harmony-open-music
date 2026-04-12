import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

import { MusicSourceTrack } from '../models/AppModels';
import { SourceLyricResult } from './QuickJsSourceService';
import { rawInflate } from '../utils/QuickJsEngine';

interface KwLyricItem {
  lineLyric: string;
  time: number;
}

interface KwLyricGroups {
  lyricItems: KwLyricItem[];
  translatedItems: KwLyricItem[];
}

const BYTE_LOOKUP: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const TIME_TAG_PATTERN: RegExp = /\[\d{1,2}:\d{2}(?:\.\d{1,3})?]/;

function emptyLyricResult(): SourceLyricResult {
  return {
    lyric: '',
    tlyric: '',
    rlyric: '',
    lxlyric: ''
  };
}

function hasUsableLyric(result: SourceLyricResult): boolean {
  return result.lyric.trim().length > 0 || result.lxlyric.trim().length > 0;
}

function trimBom(text: string): string {
  return text.length > 0 && text.charCodeAt(0) === 0xFEFF ? text.substring(1) : text;
}

function normalizeFractionLabel(fractionValue: string): string {
  if (fractionValue.length === 0) {
    return '00';
  }
  if (fractionValue.length > 3) {
    return fractionValue.substring(0, 3);
  }
  return fractionValue;
}

function normalizeTimeLabelLyric(text: string): string {
  if (text.trim().length === 0) {
    return '';
  }
  return text.replace(/\[(\d{1,2}:\d{2}):(\d{1,3})]/g, (_: string, minuteLabel: string, fractionLabel: string) => {
    return `[${minuteLabel}.${normalizeFractionLabel(fractionLabel)}]`;
  });
}

function formatSecondsTime(seconds: number): string {
  let minuteValue = Math.floor(seconds / 60);
  let secondValue = seconds - minuteValue * 60;
  let minuteText = minuteValue < 10 ? `0${minuteValue}` : `${minuteValue}`;
  let secondText = secondValue.toFixed(2);
  if (secondValue < 10) {
    secondText = `0${secondText}`;
  }
  return `${minuteText}:${secondText}`;
}

function sortKwLyrics(items: KwLyricItem[]): KwLyricGroups {
  let seenTimes = new Set<number>();
  let lyricItems: KwLyricItem[] = [];
  let translatedItems: KwLyricItem[] = [];
  for (let index = 0; index < items.length; index++) {
    let item = items[index];
    if (seenTimes.has(item.time)) {
      if (lyricItems.length === 0) {
        continue;
      }
      let previous = lyricItems.pop();
      if (previous !== undefined && lyricItems.length > 0) {
        previous.time = lyricItems[lyricItems.length - 1].time;
        translatedItems.push(previous);
      }
      lyricItems.push(item);
      continue;
    }
    lyricItems.push(item);
    seenTimes.add(item.time);
  }
  let result: KwLyricGroups = {
    lyricItems: lyricItems,
    translatedItems: translatedItems
  };
  return result;
}

function buildKwLyricText(items: KwLyricItem[]): string {
  if (items.length === 0) {
    return '';
  }
  let lines: string[] = [];
  for (let index = 0; index < items.length; index++) {
    let item = items[index];
    lines.push(`[${formatSecondsTime(item.time)}]${item.lineLyric}`);
  }
  return lines.join('\n');
}

function normalizeLyricResult(result: SourceLyricResult): SourceLyricResult | null {
  result.lyric = normalizeTimeLabelLyric(trimBom(result.lyric));
  result.tlyric = normalizeTimeLabelLyric(trimBom(result.tlyric));
  result.rlyric = normalizeTimeLabelLyric(trimBom(result.rlyric));
  result.lxlyric = trimBom(result.lxlyric);
  if (result.lyric.trim().length === 0 || !TIME_TAG_PATTERN.test(result.lyric)) {
    result.lyric = '';
  }
  if (result.tlyric.trim().length > 0 && !TIME_TAG_PATTERN.test(result.tlyric)) {
    result.tlyric = '';
  }
  if (result.rlyric.trim().length > 0 && !TIME_TAG_PATTERN.test(result.rlyric)) {
    result.rlyric = '';
  }
  if (!hasUsableLyric(result)) {
    return null;
  }
  return result;
}

function base64ToBytes(input: string): Uint8Array {
  let cleaned = input.replace(/\s+/g, '');
  if (cleaned.length === 0) {
    return new Uint8Array(0);
  }
  let outputLength = Math.floor(cleaned.length / 4) * 3;
  if (cleaned.endsWith('==')) {
    outputLength -= 2;
  } else if (cleaned.endsWith('=')) {
    outputLength -= 1;
  }
  let output = new Uint8Array(outputLength);
  let outIndex = 0;
  for (let index = 0; index < cleaned.length; index += 4) {
    let enc1 = BYTE_LOOKUP.indexOf(cleaned[index]);
    let enc2 = BYTE_LOOKUP.indexOf(cleaned[index + 1]);
    let enc3 = cleaned[index + 2] === '=' ? -1 : BYTE_LOOKUP.indexOf(cleaned[index + 2]);
    let enc4 = cleaned[index + 3] === '=' ? -1 : BYTE_LOOKUP.indexOf(cleaned[index + 3]);
    if (enc1 < 0 || enc2 < 0 || (enc3 < 0 && cleaned[index + 2] !== '=') || (enc4 < 0 && cleaned[index + 3] !== '=')) {
      throw new Error('invalid base64 lyric');
    }
    let chunk = (enc1 << 18) | (enc2 << 12) | ((enc3 < 0 ? 0 : enc3) << 6) | (enc4 < 0 ? 0 : enc4);
    if (outIndex < outputLength) {
      output[outIndex++] = (chunk >> 16) & 0xff;
    }
    if (enc3 >= 0 && outIndex < outputLength) {
      output[outIndex++] = (chunk >> 8) & 0xff;
    }
    if (enc4 >= 0 && outIndex < outputLength) {
      output[outIndex++] = chunk & 0xff;
    }
  }
  return output;
}

function decodeBase64Text(input: string): string {
  if (input.trim().length === 0) {
    return '';
  }
  let decoder = util.TextDecoder.create('utf-8');
  return decoder.decodeToString(base64ToBytes(input));
}

async function requestString(url: string, options?: http.HttpRequestOptions): Promise<string> {
  let request = http.createHttp();
  try {
    let requestOptions: http.HttpRequestOptions = {
      method: options && options.method ? options.method : http.RequestMethod.GET,
      expectDataType: http.HttpDataType.STRING,
      readTimeout: options && options.readTimeout ? options.readTimeout : 15000,
      connectTimeout: options && options.connectTimeout ? options.connectTimeout : 10000
    };
    if (options && options.header) {
      requestOptions.header = options.header;
    }
    if (options && options.extraData) {
      requestOptions.extraData = options.extraData;
    }
    let response = await request.request(url, requestOptions);
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error(`http ${response.responseCode}`);
    }
    return trimBom(response.result as string);
  } finally {
    request.destroy();
  }
}

async function requestJson(url: string, options?: http.HttpRequestOptions): Promise<Record<string, Object>> {
  let text = await requestString(url, options);
  return JSON.parse(text) as Record<string, Object>;
}

async function requestBinary(url: string, options?: http.HttpRequestOptions): Promise<ArrayBuffer> {
  let request = http.createHttp();
  try {
    let requestOptions: http.HttpRequestOptions = {
      method: options && options.method ? options.method : http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      readTimeout: options && options.readTimeout ? options.readTimeout : 15000,
      connectTimeout: options && options.connectTimeout ? options.connectTimeout : 10000
    };
    if (options && options.header) {
      requestOptions.header = options.header;
    }
    let response = await request.request(url, requestOptions);
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error(`http ${response.responseCode}`);
    }
    return response.result as ArrayBuffer;
  } finally {
    request.destroy();
  }
}

const KW_XOR_KEY: number[] = [121, 101, 101, 108, 105, 111, 110]; // 'yeelion' bytes
const KW_XOR_KEY_LEN: number = 7;

function buildKwEncryptedParams(songmid: string, isLrcx: boolean): string {
  let params = `user=12345,web,web,web&requester=localhost&req=1&rid=MUSIC_${songmid}`;
  if (isLrcx) {
    params += '&lrcx=1';
  }
  let encoder = new util.TextEncoder();
  let paramBytes = encoder.encodeInto(params);
  // XOR with key — each byte XOR'd cyclically with 'yeelion'
  let output = new Uint8Array(paramBytes.length);
  let i = 0;
  while (i < paramBytes.length) {
    let j = 0;
    while (j < KW_XOR_KEY_LEN && i < paramBytes.length) {
      output[i] = KW_XOR_KEY[j] ^ paramBytes[i];
      i++;
      j++;
    }
  }
  let helper = new util.Base64Helper();
  return helper.encodeToStringSync(output);
}

function findCrlfCrlf(data: Uint8Array): number {
  for (let i = 0; i <= data.length - 4; i++) {
    if (data[i] === 0x0D && data[i + 1] === 0x0A && data[i + 2] === 0x0D && data[i + 3] === 0x0A) {
      return i;
    }
  }
  return -1;
}

function decodeKwLyricResponse(responseBuffer: ArrayBuffer, isLrcx: boolean): string {
  let data = new Uint8Array(responseBuffer);
  // Check response starts with "tp=content"
  if (data.length < 14) {
    throw new Error('kw lyric response too short');
  }
  let headerCheck = String.fromCharCode(data[0], data[1], data[2], data[3], data[4],
    data[5], data[6], data[7], data[8], data[9]);
  if (headerCheck !== 'tp=content') {
    throw new Error('kw lyric response header mismatch');
  }

  // Find \r\n\r\n separator
  let sepIndex = findCrlfCrlf(data);
  if (sepIndex < 0) {
    throw new Error('kw lyric response separator not found');
  }

  // Extract compressed payload
  let compressedPayload = responseBuffer.slice(sepIndex + 4);

  // Inflate (decompress)
  let inflatedBuffer = rawInflate(compressedPayload);
  let inflatedBytes = new Uint8Array(inflatedBuffer);

  if (!isLrcx) {
    // Non-lrcx: decode inflated data as GB18030
    let gb18030Decoder = util.TextDecoder.create('gb18030');
    return gb18030Decoder.decodeToString(inflatedBytes);
  }

  // Lrcx mode: inflated data is base64 text
  let inflatedText = String.fromCharCode(...Array.from(inflatedBytes));
  // Base64 decode
  let helper = new util.Base64Helper();
  let xorInput = helper.decodeSync(inflatedText);

  // XOR decrypt with "yeelion" key
  let decryptedBytes = new Uint8Array(xorInput.length);
  let i = 0;
  while (i < xorInput.length) {
    let j = 0;
    while (j < KW_XOR_KEY_LEN && i < xorInput.length) {
      decryptedBytes[i] = xorInput[i] ^ KW_XOR_KEY[j];
      i++;
      j++;
    }
  }

  // Decode as GB18030
  let gb18030Decoder = util.TextDecoder.create('gb18030');
  return gb18030Decoder.decodeToString(decryptedBytes);
}

interface KwParsedLyric {
  time: string;
  text: string;
}

const KW_WORD_TIME_TAG: RegExp = /<-?\d+,-?\d+>/g;

function parseKwLrcText(lrcText: string): SourceLyricResult | null {
  let timePattern: RegExp = /^\[([\d:.]*)\]/;
  let lines = lrcText.split(/\r\n|\r|\n/);
  let lrcArr: KwParsedLyric[] = [];

  for (let i = 0; i < lines.length; i++) {
    let line = lines[i].trim();
    let match = timePattern.exec(line);
    if (!match) {
      continue;
    }
    let text = line.replace(/^\[[\d:.]*\]/, '').trim();
    let time = match[1];
    if (/\.\d\d$/.test(time)) {
      time += '0';
    }
    lrcArr.push({ time: time, text: text });
  }

  if (lrcArr.length === 0) {
    return null;
  }

  // Sort/separate main lyrics from translation (duplicate timestamps)
  let seenTimes = new Set<string>();
  let mainLyrics: KwParsedLyric[] = [];
  let transLyrics: KwParsedLyric[] = [];

  for (let index = 0; index < lrcArr.length; index++) {
    let item = lrcArr[index];
    if (seenTimes.has(item.time)) {
      if (mainLyrics.length < 2) {
        continue;
      }
      let prevItem = mainLyrics.pop();
      if (prevItem !== undefined && mainLyrics.length > 0) {
        prevItem.time = mainLyrics[mainLyrics.length - 1].time;
        transLyrics.push(prevItem);
      }
      mainLyrics.push(item);
    } else {
      mainLyrics.push(item);
      seenTimes.add(item.time);
    }
  }

  let formatLine = (item: KwParsedLyric): string => `[${item.time}]${item.text}`;
  let mainText = mainLyrics.map(formatLine).join('\n');
  let transText = transLyrics.length > 0 ? transLyrics.map(formatLine).join('\n') : '';

  // Strip word-level timing tags from translation
  if (transText.length > 0) {
    transText = transText.replace(KW_WORD_TIME_TAG, '');
  }

  // Build lxlyric (word-timed) from main before stripping
  let lxlyric = '';
  if (KW_WORD_TIME_TAG.test(mainText)) {
    lxlyric = mainText;
  }

  // Strip word-level timing tags from main lyric
  let cleanMainText = mainText.replace(KW_WORD_TIME_TAG, '');

  return normalizeLyricResult({
    lyric: cleanMainText,
    tlyric: transText,
    rlyric: '',
    lxlyric: lxlyric
  });
}

async function fetchKwLyricsNewApi(track: MusicSourceTrack): Promise<SourceLyricResult | null> {
  let encodedParams = buildKwEncryptedParams(track.songmid, true);
  let responseBuffer = await requestBinary(
    `http://newlyric.kuwo.cn/newlyric.lrc?${encodedParams}`,
    {
      header: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      } as Record<string, string>
    }
  );
  let lrcText = decodeKwLyricResponse(responseBuffer, true);
  if (lrcText.trim().length === 0) {
    return null;
  }
  return parseKwLrcText(lrcText);
}

async function fetchKwLyricsLegacyApi(track: MusicSourceTrack): Promise<SourceLyricResult | null> {
  let body = await requestJson(`http://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=${encodeURIComponent(track.songmid)}`, {
    header: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    } as Record<string, string>
  });
  let data = body['data'] as Record<string, Object>;
  let lyricItemsRaw = data ? data['lrclist'] as Record<string, Object>[] : [];
  if (!lyricItemsRaw || lyricItemsRaw.length === 0) {
    return null;
  }
  let lyricItems: KwLyricItem[] = [];
  for (let index = 0; index < lyricItemsRaw.length; index++) {
    let item = lyricItemsRaw[index];
    let text = item['lineLyric'] as string || '';
    let timeValue = Number(item['time'] as string || item['time'] as number || 0);
    if (text.trim().length === 0 || Number.isNaN(timeValue)) {
      continue;
    }
    lyricItems.push({ lineLyric: text, time: timeValue });
  }
  if (lyricItems.length === 0) {
    return null;
  }
  let sorted = sortKwLyrics(lyricItems);
  return normalizeLyricResult({
    lyric: buildKwLyricText(sorted.lyricItems),
    tlyric: buildKwLyricText(sorted.translatedItems),
    rlyric: '',
    lxlyric: ''
  });
}

async function fetchKwLyrics(track: MusicSourceTrack): Promise<SourceLyricResult | null> {
  // Try the primary encrypted API first (same as desktop)
  try {
    let result = await fetchKwLyricsNewApi(track);
    if (result !== null) {
      return result;
    }
  } catch (error) {
    let errMsg = error instanceof Error ? error.message : String(error);
    console.error(`fetchKwLyricsNewApi failed: songmid=${track.songmid}, error=${errMsg}`);
  }
  // Fallback to legacy mobile API
  return await fetchKwLyricsLegacyApi(track);
}

async function fetchKgLyrics(track: MusicSourceTrack): Promise<SourceLyricResult | null> {
  let durationSeconds = track.duration > 0 ? track.duration : 0;
  let lyric = await requestString(
    `http://m.kugou.com/app/i/krc.php?cmd=100&keyword=${encodeURIComponent(track.name)}&hash=${encodeURIComponent(track.hash)}&timelength=${durationSeconds}&d=0.38664927426725626`,
    {
      header: {
        'KG-RC': '1',
        'KG-THash': 'expand_search_manager.cpp:852736169:451',
        'User-Agent': 'KuGou2012-9020-ExpandSearchManager'
      } as Record<string, string>
    }
  );
  return normalizeLyricResult({
    lyric: lyric,
    tlyric: '',
    rlyric: '',
    lxlyric: ''
  });
}

async function fetchTxLyrics(track: MusicSourceTrack): Promise<SourceLyricResult | null> {
  let body = await requestJson(
    `https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=${encodeURIComponent(track.songmid)}&g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq`,
    {
      header: {
        'Referer': 'https://y.qq.com/portal/player.html',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      } as Record<string, string>
    }
  );
  let code = body['code'] as number;
  if (code !== 0) {
    return null;
  }
  return normalizeLyricResult({
    lyric: decodeBase64Text(body['lyric'] as string || ''),
    tlyric: decodeBase64Text(body['trans'] as string || ''),
    rlyric: '',
    lxlyric: ''
  });
}

async function fetchWyLyrics(track: MusicSourceTrack): Promise<SourceLyricResult | null> {
  let body = await requestJson(
    `https://music.163.com/api/song/lyric?os=pc&id=${encodeURIComponent(track.songmid)}&lv=1&kv=1&tv=-1`,
    {
      header: {
        'Referer': 'https://music.163.com',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      } as Record<string, string>
    }
  );
  let code = body['code'] as number;
  if (code !== 200) {
    return null;
  }
  let lrc = body['lrc'] as Record<string, Object> | undefined;
  let tlrc = body['tlyric'] as Record<string, Object> | undefined;
  let rlrc = body['romalrc'] as Record<string, Object> | undefined;
  return normalizeLyricResult({
    lyric: lrc ? lrc['lyric'] as string || '' : '',
    tlyric: tlrc ? tlrc['lyric'] as string || '' : '',
    rlyric: rlrc ? rlrc['lyric'] as string || '' : '',
    lxlyric: ''
  });
}

async function fetchMgLyrics(track: MusicSourceTrack): Promise<SourceLyricResult | null> {
  let lrcUrl = track.lrcUrl ?? '';
  if (lrcUrl.length === 0) {
    return null;
  }
  let headers = {
    'Referer': 'https://app.c.nf.migu.cn/',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    'channel': '0146921'
  } as Record<string, string>;
  let lyric = await requestString(lrcUrl, { header: headers });
  let tlyric = '';
  if ((track.trcUrl ?? '').length > 0) {
    try {
      tlyric = await requestString(track.trcUrl as string, { header: headers });
    } catch (_) {
      tlyric = '';
    }
  }
  return normalizeLyricResult({
    lyric: lyric,
    tlyric: tlyric,
    rlyric: '',
    lxlyric: ''
  });
}

export async function fetchBuiltInSourceLyrics(track: MusicSourceTrack): Promise<SourceLyricResult | null> {
  try {
    switch (track.source) {
      case 'kw':
        return await fetchKwLyrics(track);
      case 'kg':
        return await fetchKgLyrics(track);
      case 'tx':
        return await fetchTxLyrics(track);
      case 'wy':
        return await fetchWyLyrics(track);
      case 'mg':
        return await fetchMgLyrics(track);
      default:
        return null;
    }
  } catch (error) {
    let errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
    console.error(`fetch built-in source lyrics failed: source=${track.source}, songmid=${track.songmid}, error=${errorMessage}`);
    return null;
  }
}
