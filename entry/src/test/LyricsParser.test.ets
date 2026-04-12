import { describe, it, expect } from '@ohos/hypium';

import { findCurrentLyricIndex, lineLyricFromLxLyric, parseLrcLyrics } from '../main/ets/utils/LyricsParser';

export default function lyricsParserTest() {
  describe('LyricsParser', () => {
    it('merges_translation_and_romanized_lines_into_extended_lyrics', 0, () => {
      let lines = parseLrcLyrics(
        '[00:01.00]Hello\n[00:02.00]World',
        [
          '[00:01.00]你好\n[00:02.00]世界',
          '[00:01.00]ni hao\n[00:02.00]shi jie'
        ]
      );

      expect(lines.length).assertEqual(2);
      expect(lines[0].text).assertEqual('Hello');
      expect(lines[0].extendedLyrics.length).assertEqual(2);
      expect(lines[0].extendedLyrics[0]).assertEqual('你好');
      expect(lines[0].extendedLyrics[1]).assertEqual('ni hao');
    });

    it('treats_duplicate_main_lyric_timestamps_as_extended_lines', 0, () => {
      let lines = parseLrcLyrics('[00:01.00]Hello\n[00:01.00]HELLO');

      expect(lines.length).assertEqual(1);
      expect(lines[0].text).assertEqual('Hello');
      expect(lines[0].extendedLyrics.length).assertEqual(1);
      expect(lines[0].extendedLyrics[0]).assertEqual('HELLO');
    });

    it('tracks_current_line_like_desktop_line_player', 0, () => {
      let lines = parseLrcLyrics('[00:01.00]A\n[00:03.00]B\n[00:05.00]C');

      expect(findCurrentLyricIndex(lines, 0)).assertEqual(0);
      expect(findCurrentLyricIndex(lines, 2500)).assertEqual(0);
      expect(findCurrentLyricIndex(lines, 3000)).assertEqual(1);
      expect(findCurrentLyricIndex(lines, 7000)).assertEqual(2);
    });

    it('converts_lxlyric_into_line_lyric_text', 0, () => {
      let lyric = lineLyricFromLxLyric('[00:01.00]<0,320>Hello<320,280> world');

      expect(lyric).assertEqual('[00:01.00]Hello world');
    });

    it('keeps_lxlyric_word_timing_for_active_line_rendering', 0, () => {
      let lines = parseLrcLyrics('[00:01.00]<0,280>你<280,320>好');

      expect(lines.length).assertEqual(1);
      expect(lines[0].text).assertEqual('你好');
      expect(lines[0].words.length).assertEqual(2);
      expect(lines[0].words[0].text).assertEqual('你');
      expect(lines[0].words[0].startTimeMs).assertEqual(0);
      expect(lines[0].words[0].durationMs).assertEqual(280);
      expect(lines[0].words[1].text).assertEqual('好');
      expect(lines[0].words[1].startTimeMs).assertEqual(280);
      expect(lines[0].words[1].durationMs).assertEqual(320);
    });
  });
}
