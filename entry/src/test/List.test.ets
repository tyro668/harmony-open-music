import localUnitTest from './LocalUnit.test';
import backgroundPlaybackTest from './BackgroundPlayback.test';
import baiduPanServiceTest from './BaiduPanService.test';
import libraryQueueStateTest from './LibraryQueueState.test';
import playbackCollectionStateTest from './PlaybackCollectionState.test';

export default function testsuite() {
  localUnitTest();
  baiduPanServiceTest();
  libraryQueueStateTest();
  playbackCollectionStateTest();
  backgroundPlaybackTest();
}
