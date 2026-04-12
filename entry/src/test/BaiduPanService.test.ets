import { describe, it, expect } from '@ohos/hypium';

import {
  baiduPanParentLabel,
  buildBaiduPanOAuthAuthorizeUrl,
  isBaiduPanAudioFileName,
  normalizeBaiduPanPath,
  parseBaiduPanOAuthPayload,
  parentBaiduPanPath,
  parseBaiduPanListPayload
} from '../main/ets/services/BaiduPanService';

export default function baiduPanServiceTest() {
  describe('BaiduPanService', () => {
    it('normalize_path_should_keep_root_and_trim_tail', 0, () => {
      expect(normalizeBaiduPanPath('')).assertEqual('/');
      expect(normalizeBaiduPanPath('/music/demo/')).assertEqual('/music/demo');
      expect(normalizeBaiduPanPath('music/demo')).assertEqual('/music/demo');
    });

    it('parent_path_should_resolve_upper_directory', 0, () => {
      expect(parentBaiduPanPath('/')).assertEqual('/');
      expect(parentBaiduPanPath('/music/demo')).assertEqual('/music');
      expect(baiduPanParentLabel('/music/demo/song.mp3')).assertEqual('demo');
    });

    it('should_filter_audio_files_and_keep_directories', 0, () => {
      let payload = JSON.stringify({
        errno: 0,
        list: [
          { fs_id: 1, isdir: 1, server_filename: 'Album', path: '/Album', size: 0, server_mtime: 1 },
          { fs_id: 2, isdir: 0, server_filename: 'Song.mp3', path: '/Album/Song.mp3', size: 1024, server_mtime: 2 },
          { fs_id: 3, isdir: 0, server_filename: 'Cover.jpg', path: '/Album/Cover.jpg', size: 512, server_mtime: 3 }
        ]
      });
      let entries = parseBaiduPanListPayload(payload, '/Album');
      expect(entries.length).assertEqual(2);
      expect(entries[0].isDirectory).assertTrue();
      expect(entries[1].name).assertEqual('Song.mp3');
    });

    it('audio_file_name_detection_should_support_common_extensions', 0, () => {
      expect(isBaiduPanAudioFileName('demo.flac')).assertTrue();
      expect(isBaiduPanAudioFileName('demo.txt')).assertFalse();
    });

    it('oauth_authorize_url_should_include_app_key_and_scope', 0, () => {
      let url = buildBaiduPanOAuthAuthorizeUrl('demo-app-key', 'state-1');
      expect(url.indexOf('response_type=token') >= 0).assertTrue();
      expect(url.indexOf('client_id=demo-app-key') >= 0).assertTrue();
      expect(url.indexOf('scope=basic%2Cnetdisk') >= 0).assertTrue();
      expect(url.indexOf('state=state-1') >= 0).assertTrue();
    });

    it('oauth_payload_should_extract_access_token_from_hash', 0, () => {
      let result = parseBaiduPanOAuthPayload(
        '"https://openapi.baidu.com/oauth/2.0/login_success#access_token=test-token&expires_in=2592000"'
      );
      expect(result.accessToken).assertEqual('test-token');
      expect(result.expiresInMs).assertEqual(2592000 * 1000);
      expect(result.errorMessage).assertEqual('');
    });
  });
}
