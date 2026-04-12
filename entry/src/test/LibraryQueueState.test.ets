import { describe, it, expect } from '@ohos/hypium';

import { CollectionMode, MusicTrack } from '../main/ets/models/AppModels';
import {
  currentTrack,
  moveTrackByReference,
  playQueueTracks,
  visibleTracks
} from '../main/ets/utils/LibraryStateUtils';

interface TrackOverrides {
  isFavorite?: boolean;
  inPlayQueue?: boolean;
}

function buildTrack(id: string, overrides: TrackOverrides = {}): MusicTrack {
  let track: MusicTrack = {
    id: id,
    title: `歌曲-${id}`,
    artist: `歌手-${id}`,
    album: '测试专辑',
    durationMs: 0,
    folder: '测试目录',
    sourceUri: '',
    filePath: `/tmp/${id}.mp3`,
    rawFileName: '',
    accentColor: '#123456',
    pic: '',
    isFavorite: false,
    isImported: true,
    inPlayQueue: true,
    playCount: 0,
    lastPlayedAt: 0
  };
  if (overrides.isFavorite !== undefined) {
    track.isFavorite = overrides.isFavorite;
  }
  if (overrides.inPlayQueue !== undefined) {
    track.inPlayQueue = overrides.inPlayQueue;
  }
  return track;
}

export default function libraryQueueStateTest() {
  describe('LibraryQueueState', () => {
    it('play_queue_filters_tracks_removed_from_playlist', 0, () => {
      let queue = playQueueTracks([
        buildTrack('a'),
        buildTrack('b', { inPlayQueue: false })
      ]);

      expect(queue.length).assertEqual(1);
      expect(queue[0].id).assertEqual('a');
    });

    it('favorites_can_still_show_tracks_outside_playlist', 0, () => {
      let tracks = visibleTracks(
        [
          buildTrack('a', { isFavorite: true, inPlayQueue: false }),
          buildTrack('b', { isFavorite: false, inPlayQueue: true })
        ],
        [],
        CollectionMode.Favorites,
        ''
      );

      expect(tracks.length).assertEqual(1);
      expect(tracks[0].id).assertEqual('a');
    });

    it('library_view_only_shows_tracks_in_play_queue', 0, () => {
      let tracks = visibleTracks(
        [
          buildTrack('a', { inPlayQueue: true }),
          buildTrack('b', { inPlayQueue: false })
        ],
        [],
        CollectionMode.Library,
        ''
      );

      expect(tracks.length).assertEqual(1);
      expect(tracks[0].id).assertEqual('a');
    });

    it('move_track_before_reorders_without_losing_other_items', 0, () => {
      let tracks = moveTrackByReference(
        [
          buildTrack('a'),
          buildTrack('b'),
          buildTrack('c')
        ],
        'c',
        'a',
        false
      );

      expect(tracks[0].id).assertEqual('c');
      expect(tracks[1].id).assertEqual('a');
      expect(tracks[2].id).assertEqual('b');
    });

    it('move_track_after_reorders_relative_to_reference_track', 0, () => {
      let tracks = moveTrackByReference(
        [
          buildTrack('a'),
          buildTrack('b'),
          buildTrack('c')
        ],
        'a',
        'c',
        true
      );

      expect(tracks[0].id).assertEqual('b');
      expect(tracks[1].id).assertEqual('c');
      expect(tracks[2].id).assertEqual('a');
    });

    it('current_track_keeps_hidden_track_when_it_is_selected', 0, () => {
      let selected = currentTrack(
        [
          buildTrack('a', { inPlayQueue: false }),
          buildTrack('b')
        ],
        'a'
      );

      expect(selected.id).assertEqual('a');
      expect(selected.inPlayQueue).assertFalse();
    });
  });
}
