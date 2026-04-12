export interface LyricLine {
  timeMs: number;
  text: string;
  extendedLyrics: string[];
  words: LyricWord[];
}

export interface LyricWord {
  text: string;
  startTimeMs: number;
  durationMs: number;
}

// Matches one or more time tags like [00:12.34] at the beginning of a line
const TIME_FIELD_PATTERN: RegExp = /^(?:\[[\d:.]+\])+/g;
// Matches individual time values like 1:23.456 within time fields
const TIME_VALUE_PATTERN: RegExp = /\d{1,3}(:\d{1,3}){0,2}(?:\.\d{1,3})/g;
// Strips leading zeros: 01 → 1
const LEADING_ZERO_PATTERN: RegExp = /^0+(\d+)/;
// Strips leading zeros after colon: :01 → :1
const COLON_LEADING_ZERO_PATTERN: RegExp = /:0+(\d+)/g;
// Strips leading zeros after dot: .00 → .0
const DOT_LEADING_ZERO_PATTERN: RegExp = /\.0+(\d+)/;
const WORD_TIME_TAG_PATTERN: RegExp = /<-?\d+,-?\d+(?:,-?\d+)?>/g;
const WORD_TIME_DETAIL_PATTERN: RegExp = /<(-?\d+),(-?\d+)(?:,-?\d+)?>/g;

export function lineLyricFromLxLyric(lxLyric: string): string {
  if (lxLyric.length === 0) {
    return '';
  }
  return lxLyric.replace(WORD_TIME_TAG_PATTERN, '').trim();
}

function parseLyricWords(text: string): LyricWord[] {
  let words: LyricWord[] = [];
  WORD_TIME_DETAIL_PATTERN.lastIndex = 0;
  let matches: RegExpExecArray[] = [];
  let match: RegExpExecArray | null = WORD_TIME_DETAIL_PATTERN.exec(text);
  while (match !== null) {
    matches.push(match);
    match = WORD_TIME_DETAIL_PATTERN.exec(text);
  }
  if (matches.length === 0) {
    return words;
  }
  for (let i = 0; i < matches.length; i++) {
    let currentMatch = matches[i];
    let startIndex = currentMatch.index + currentMatch[0].length;
    let endIndex = i + 1 < matches.length ? matches[i + 1].index : text.length;
    let wordText = text.substring(startIndex, endIndex);
    if (wordText.length === 0) {
      continue;
    }
    let startTimeMs = parseInt(currentMatch[1], 10);
    let durationMs = parseInt(currentMatch[2], 10);
    if (isNaN(startTimeMs) || isNaN(durationMs)) {
      continue;
    }
    words.push({
      text: wordText,
      startTimeMs: startTimeMs,
      durationMs: Math.max(durationMs, 0)
    });
  }
  return words;
}

function formatTimeLabel(label: string): string {
  return label.replace(LEADING_ZERO_PATTERN, '$1')
    .replace(COLON_LEADING_ZERO_PATTERN, ':$1')
    .replace(DOT_LEADING_ZERO_PATTERN, '.$1');
}

function parseTimeLabelToMs(timeStr: string): number {
  let parts = timeStr.split(':');
  if (parts.length > 3) {
    return -1;
  }
  // Pad to [hours, minutes, seconds.ms]
  while (parts.length < 3) {
    parts.unshift('0');
  }
  let hours = parseInt(parts[0], 10);
  let minutes = parseInt(parts[1], 10);
  let secParts = parts[2].split('.');
  let seconds = parseInt(secParts[0], 10);
  let ms = secParts.length > 1 ? parseInt(secParts[1], 10) : 0;
  if (isNaN(hours) || isNaN(minutes) || isNaN(seconds) || isNaN(ms)) {
    return -1;
  }
  return hours * 3600000 + minutes * 60000 + seconds * 1000 + ms;
}

function parseMainLyric(lyric: string): Map<string, LyricLine> {
  let linesMap = new Map<string, LyricLine>();
  let rawLines = lyric.split(/\r\n|\r|\n/);
  for (let i = 0; i < rawLines.length; i++) {
    let line = rawLines[i].trim();
    if (line.length === 0) {
      continue;
    }
    TIME_FIELD_PATTERN.lastIndex = 0;
    let result = TIME_FIELD_PATTERN.exec(line);
    if (result !== null) {
      let timeField = result[0];
      TIME_FIELD_PATTERN.lastIndex = 0;
      let textWithWordTags = line.replace(TIME_FIELD_PATTERN, '').trim();
      let text = textWithWordTags.replace(WORD_TIME_TAG_PATTERN, '').trim();
      if (text.length > 0) {
        let words = parseLyricWords(textWithWordTags);
        TIME_VALUE_PATTERN.lastIndex = 0;
        let times = timeField.match(TIME_VALUE_PATTERN);
        if (times === null) {
          continue;
        }
        for (let t = 0; t < times.length; t++) {
          let timeStr = formatTimeLabel(times[t]);
          let existing = linesMap.get(timeStr);
          if (existing !== undefined) {
            // Duplicate time tag → push as extended lyric (same as desktop)
            existing.extendedLyrics.push(text);
            continue;
          }
          let timeMs = parseTimeLabelToMs(timeStr);
          if (timeMs < 0) {
            continue;
          }
          linesMap.set(timeStr, {
            timeMs: timeMs,
            text: text,
            extendedLyrics: [],
            words: words
          });
        }
      }
    }
  }
  return linesMap;
}

function parseExtendedLyric(linesMap: Map<string, LyricLine>, extendedLyric: string): void {
  let rawLines = extendedLyric.split(/\r\n|\r|\n/);
  for (let i = 0; i < rawLines.length; i++) {
    let line = rawLines[i].trim();
    if (line.length === 0) {
      continue;
    }
    TIME_FIELD_PATTERN.lastIndex = 0;
    let result = TIME_FIELD_PATTERN.exec(line);
    if (result !== null) {
      let timeField = result[0];
      TIME_FIELD_PATTERN.lastIndex = 0;
      let text = line.replace(TIME_FIELD_PATTERN, '').trim();
      if (text.length > 0 && text !== '//') {
        TIME_VALUE_PATTERN.lastIndex = 0;
        let times = timeField.match(TIME_VALUE_PATTERN);
        if (times === null) {
          continue;
        }
        for (let t = 0; t < times.length; t++) {
          let timeStr = formatTimeLabel(times[t]);
          let targetLine = linesMap.get(timeStr);
          if (targetLine !== undefined) {
            targetLine.extendedLyrics.push(text);
          }
        }
      }
    }
  }
}

export function parseLrcLyrics(mainLrc: string, extendedLyrics?: string[]): LyricLine[] {
  let linesMap = parseMainLyric(mainLrc);
  if (extendedLyrics !== undefined) {
    for (let i = 0; i < extendedLyrics.length; i++) {
      if (extendedLyrics[i].length > 0) {
        parseExtendedLyric(linesMap, extendedLyrics[i]);
      }
    }
  }
  let lines: LyricLine[] = [];
  linesMap.forEach((value: LyricLine) => {
    lines.push(value);
  });
  lines.sort((a: LyricLine, b: LyricLine) => a.timeMs - b.timeMs);
  return lines;
}

export function findCurrentLyricIndex(lyrics: LyricLine[], currentMs: number): number {
  if (lyrics.length === 0) {
    return -1;
  }
  if (currentMs <= 0) {
    return 0;
  }
  let index = -1;
  for (let i = 0; i < lyrics.length; i++) {
    if (currentMs >= lyrics[i].timeMs) {
      index = i;
    } else {
      break;
    }
  }
  return index < 0 ? 0 : index;
}
