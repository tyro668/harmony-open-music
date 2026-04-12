import localUnitTest from './LocalUnit.test';
import backgroundPlaybackTest from './BackgroundPlayback.test';
import baiduPanServiceTest from './BaiduPanService.test';
import libraryQueueStateTest from './LibraryQueueState.test';
import lyricsParserTest from './LyricsParser.test';
import playbackCollectionStateTest from './PlaybackCollectionState.test';
import quickJsSourceServiceTest from './QuickJsSourceService.test';

export default function testsuite() {
  localUnitTest();
  baiduPanServiceTest();
  libraryQueueStateTest();
  lyricsParserTest();
  playbackCollectionStateTest();
  quickJsSourceServiceTest();
  backgroundPlaybackTest();
}
