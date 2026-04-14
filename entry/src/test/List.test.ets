import localUnitTest from './LocalUnit.test';
import backgroundPlaybackTest from './BackgroundPlayback.test';
import baiduPanServiceTest from './BaiduPanService.test';
import importStateUtilsTest from './ImportStateUtils.test';
import libraryQueueStateTest from './LibraryQueueState.test';
import lyricsParserTest from './LyricsParser.test';
import playbackCollectionStateTest from './PlaybackCollectionState.test';
import quickJsSourceServiceTest from './QuickJsSourceService.test';
import trackCoverDisplayUtilsTest from './TrackCoverDisplayUtils.test';

export default function testsuite() {
  localUnitTest();
  baiduPanServiceTest();
  importStateUtilsTest();
  libraryQueueStateTest();
  lyricsParserTest();
  playbackCollectionStateTest();
  quickJsSourceServiceTest();
  trackCoverDisplayUtilsTest();
  backgroundPlaybackTest();
}
