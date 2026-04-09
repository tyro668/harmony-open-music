import localUnitTest from './LocalUnit.test';
import backgroundPlaybackTest from './BackgroundPlayback.test';

export default function testsuite() {
  localUnitTest();
  backgroundPlaybackTest();
}