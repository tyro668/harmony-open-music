import { describe, it, expect } from '@ohos/hypium';

import { MusicTrack } from '../main/ets/models/AppModels';
import {
  appendImportedTrackIfMissing,
  hasTrackWithSourceImportKey
} from '../main/ets/utils/ImportStateUtils';

function buildTrack(id: string, sourceImportKey: string, filePath?: string): MusicTrack {
  return {
    id: id,
    title: `歌曲-${id}`,
    artist: `歌手-${id}`,
    album: '测试专辑',
    durationMs: 0,
    folder: 'downloads',
    sourceUri: '',
    filePath: filePath ?? `/tmp/${id}.mp3`,
    rawFileName: '',
    accentColor: '#123456',
    pic: '',
    isFavorite: false,
    isImported: true,
    inPlayQueue: true,
    playCount: 0,
    lastPlayedAt: 0,
    sourceImportKey: sourceImportKey
  };
}

export default function importStateUtilsTest() {
  describe('ImportStateUtils', () => {
    it('append_imported_track_keeps_existing_items_when_merging_latest_snapshot', 0, () => {
      let firstImported = buildTrack('a', 'source:a');
      let secondImported = buildTrack('b', 'source:b');

      let merged = appendImportedTrackIfMissing([firstImported], secondImported);

      expect(merged.length).assertEqual(2);
      expect(merged[0].sourceImportKey).assertEqual('source:a');
      expect(merged[1].sourceImportKey).assertEqual('source:b');
    });

    it('append_imported_track_skips_duplicate_source_import_key', 0, () => {
      let existing = buildTrack('a', 'source:a');
      let duplicate = buildTrack('b', 'source:a', '/tmp/other.mp3');

      let merged = appendImportedTrackIfMissing([existing], duplicate);

      expect(merged.length).assertEqual(1);
      expect(merged[0].id).assertEqual('a');
    });

    it('has_track_with_source_import_key_ignores_empty_key', 0, () => {
      let tracks = [buildTrack('a', 'source:a')];

      expect(hasTrackWithSourceImportKey(tracks, 'source:a')).assertTrue();
      expect(hasTrackWithSourceImportKey(tracks, '')).assertFalse();
    });
  });
}
