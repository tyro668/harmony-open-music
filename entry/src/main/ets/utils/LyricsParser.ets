export interface LyricLine {
  timeMs: number;
  text: string;
}

export function parseLrcLyrics(lrc: string): LyricLine[] {
  let lines: LyricLine[] = [];
  let rawLines = lrc.split('\n');
  for (let i = 0; i < rawLines.length; i++) {
    let line = rawLines[i].trim();
    if (line.length === 0) {
      continue;
    }
    let tagMatches = extractTimeTagsAndText(line);
    for (let j = 0; j < tagMatches.length; j++) {
      lines.push(tagMatches[j]);
    }
  }
  lines.sort((a: LyricLine, b: LyricLine) => a.timeMs - b.timeMs);
  return lines;
}

function extractTimeTagsAndText(line: string): LyricLine[] {
  let results: LyricLine[] = [];
  let times: number[] = [];
  let pos = 0;
  while (pos < line.length && line[pos] === '[') {
    let closeBracket = line.indexOf(']', pos);
    if (closeBracket < 0) {
      break;
    }
    let tagContent = line.substring(pos + 1, closeBracket);
    let timeMs = parseTimeTag(tagContent);
    if (timeMs >= 0) {
      times.push(timeMs);
      pos = closeBracket + 1;
    } else {
      break;
    }
  }
  if (times.length === 0) {
    return results;
  }
  let text = line.substring(pos).trim();
  for (let i = 0; i < times.length; i++) {
    results.push({ timeMs: times[i], text: text });
  }
  return results;
}

function parseTimeTag(tag: string): number {
  let colonIndex = tag.indexOf(':');
  if (colonIndex < 0) {
    return -1;
  }
  let minuteStr = tag.substring(0, colonIndex);
  let secondStr = tag.substring(colonIndex + 1);
  let minutes = parseInt(minuteStr, 10);
  if (isNaN(minutes) || minutes < 0) {
    return -1;
  }
  let seconds = parseFloat(secondStr);
  if (isNaN(seconds) || seconds < 0) {
    return -1;
  }
  return Math.round(minutes * 60 * 1000 + seconds * 1000);
}

export function findCurrentLyricIndex(lyrics: LyricLine[], currentMs: number): number {
  if (lyrics.length === 0) {
    return -1;
  }
  let index = -1;
  for (let i = 0; i < lyrics.length; i++) {
    if (lyrics[i].timeMs <= currentMs) {
      index = i;
    } else {
      break;
    }
  }
  return index;
}
