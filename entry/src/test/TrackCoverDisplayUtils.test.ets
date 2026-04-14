import { image } from '@kit.ImageKit';
import { describe, it, expect } from '@ohos/hypium';

import { MusicTrack } from '../main/ets/models/AppModels';
import { resolveTrackDisplayCover } from '../main/ets/utils/TrackCoverDisplayUtils';

function buildTrack(pic: string = ''): MusicTrack {
  return {
    id: 'track-1',
    title: '歌曲-1',
    artist: '歌手-1',
    album: '测试专辑',
    durationMs: 0,
    folder: 'downloads',
    sourceUri: '',
    filePath: '/tmp/track-1.mp3',
    rawFileName: '',
    accentColor: '#123456',
    pic: pic,
    isFavorite: false,
    isImported: true,
    inPlayQueue: true,
    playCount: 0,
    lastPlayedAt: 0
  };
}

export default function trackCoverDisplayUtilsTest() {
  describe('TrackCoverDisplayUtils', () => {
    it('prefers_extracted_artwork_over_track_pic', 0, () => {
      let artwork = {} as image.PixelMap;
      let resolved = resolveTrackDisplayCover(buildTrack('https://example.com/cover.jpg'), artwork);

      expect(resolved).assertEqual(artwork);
    });

    it('falls_back_to_track_pic_when_artwork_missing', 0, () => {
      let resolved = resolveTrackDisplayCover(buildTrack('https://example.com/cover.jpg'), null);

      expect(resolved).assertEqual('https://example.com/cover.jpg');
    });

    it('returns_null_when_no_cover_source_exists', 0, () => {
      let resolved = resolveTrackDisplayCover(buildTrack(''), null);

      expect(resolved === null).assertTrue();
    });
  });
}
