import { describe, it, expect } from '@ohos/hypium';

import { MusicSourceTrack } from '../main/ets/models/AppModels';
import { buildQuickJsLyricRequest, parseQuickJsLyricResponse } from '../main/ets/services/QuickJsSourceService';

function buildTrack(overrides: Partial<MusicSourceTrack> = {}): MusicSourceTrack {
  return {
    id: 'track-1',
    name: 'Test Song',
    singer: 'Test Singer',
    album: 'Test Album',
    albumId: 'album-mid-1',
    duration: 180,
    interval: '03:00',
    pic: '',
    source: 'tx',
    songmid: 'song-mid-1',
    hash: 'media-mid-1',
    types: [],
    _types: {},
    copyrightId: '',
    ...overrides
  };
}

export default function quickJsSourceServiceTest() {
  describe('QuickJsSourceService', () => {
    it('lyric_response_falls_back_to_lxlyric_when_plain_lrc_is_missing', 0, () => {
      let response = parseQuickJsLyricResponse(JSON.stringify({
        status: true,
        result: {
          data: {
            lyric: '',
            tlyric: '',
            rlyric: '',
            lxlyric: '[00:01.00]<0,320>Hello<320,280> world'
          }
        }
      }));

      expect(response !== null).assertTrue();
      expect((response as NonNullable<typeof response>).lyric).assertEqual('[00:01.00]Hello world');
    });

    it('lyric_request_keeps_legacy_tx_music_info_fields', 0, () => {
      let payload = JSON.parse(buildQuickJsLyricRequest('req-1', buildTrack({
        songId: 'song-id-1',
        albumMid: 'album-mid-1',
        strMediaMid: 'media-mid-1'
      }))) as Record<string, Object>;
      let data = payload['data'] as Record<string, Object>;
      let info = data['info'] as Record<string, Object>;
      let musicInfo = info['musicInfo'] as Record<string, Object>;

      expect(musicInfo['songId'] as string).assertEqual('song-id-1');
      expect(musicInfo['albumMid'] as string).assertEqual('album-mid-1');
      expect(musicInfo['strMediaMid'] as string).assertEqual('media-mid-1');
    });
  });
}
