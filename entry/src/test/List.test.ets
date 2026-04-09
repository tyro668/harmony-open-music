import localUnitTest from './LocalUnit.test';
import backgroundPlaybackTest from './BackgroundPlayback.test';
import libraryQueueStateTest from './LibraryQueueState.test';

export default function testsuite() {
  localUnitTest();
  libraryQueueStateTest();
  backgroundPlaybackTest();
}
