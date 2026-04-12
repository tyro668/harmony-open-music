import { describe, it, expect } from '@ohos/hypium';

import { CustomPlaylist, MusicTrack, PlaybackCollectionKind } from '../main/ets/models/AppModels';
import {
  albumPlaybackCollectionSummaries,
  artistPlaybackCollectionSummaries,
  buildCustomPlaybackCollectionId,
  FAVORITES_PLAYBACK_COLLECTION_ID,
  playbackCollectionKindLabel,
  playbackCollectionSelectorSummaries,
  playbackCollectionTracks,
  trackBelongsToPlaybackCollection
} from '../main/ets/utils/PlaybackCollectionUtils';
import {
  createCustomPlaylist,
  removeCustomPlaylist,
  toggleTrackInCustomPlaylist
} from '../main/ets/services/CustomPlaylistService';

interface TrackOverrides {
  album?: string;
  artist?: string;
  isFavorite?: boolean;
  inPlayQueue?: boolean;
}

function buildTrack(id: string, overrides: TrackOverrides = {}): MusicTrack {
  let track: MusicTrack = {
    id: id,
    title: `歌曲-${id}`,
    artist: overrides.artist ?? `歌手-${id}`,
    album: overrides.album ?? '测试专辑',
    durationMs: 0,
    folder: '测试目录',
    sourceUri: '',
    filePath: `/tmp/${id}.mp3`,
    rawFileName: '',
    accentColor: '#123456',
    pic: '',
    isFavorite: overrides.isFavorite ?? false,
    isImported: true,
    inPlayQueue: overrides.inPlayQueue ?? true,
    playCount: 0,
    lastPlayedAt: 0
  };
  return track;
}

export default function playbackCollectionStateTest() {
  describe('PlaybackCollectionState', () => {
    it('album_collections_group_by_album_for_playable_tracks_only', 0, () => {
      let collections = albumPlaybackCollectionSummaries([
        buildTrack('a', { album: '专辑 A', inPlayQueue: true }),
        buildTrack('b', { album: '专辑 B', inPlayQueue: false }),
        buildTrack('c', { album: '专辑 A', inPlayQueue: true })
      ]);

      expect(collections.length).assertEqual(1);
      expect(collections[0].title).assertEqual('专辑 A');
      expect(collections[0].trackCount).assertEqual(2);
    });

    it('artist_collections_preserve_first_seen_order', 0, () => {
      let collections = artistPlaybackCollectionSummaries([
        buildTrack('a', { artist: '歌手乙' }),
        buildTrack('b', { artist: '歌手甲' }),
        buildTrack('c', { artist: '歌手乙' })
      ]);

      expect(collections.length).assertEqual(2);
      expect(collections[0].title).assertEqual('歌手乙');
      expect(collections[1].title).assertEqual('歌手甲');
    });

    it('custom_playlist_tracks_follow_local_track_order', 0, () => {
      let customPlaylists: CustomPlaylist[] = [{
        id: 'fav',
        name: '我的最爱',
        trackIds: ['c', 'a']
      }];
      let tracks = playbackCollectionTracks(
        [buildTrack('a'), buildTrack('b'), buildTrack('c')],
        customPlaylists,
        buildCustomPlaybackCollectionId('fav')
      );

      expect(tracks.length).assertEqual(2);
      expect(tracks[0].id).assertEqual('a');
      expect(tracks[1].id).assertEqual('c');
    });

    it('favorite_collection_only_contains_favorite_tracks', 0, () => {
      let tracks = playbackCollectionTracks(
        [
          buildTrack('a', { isFavorite: true }),
          buildTrack('b', { isFavorite: false }),
          buildTrack('c', { isFavorite: true })
        ],
        [],
        FAVORITES_PLAYBACK_COLLECTION_ID
      );

      expect(tracks.length).assertEqual(2);
      expect(tracks[0].id).assertEqual('a');
      expect(tracks[1].id).assertEqual('c');
    });

    it('toggle_track_in_custom_playlist_adds_and_removes_membership', 0, () => {
      let created = createCustomPlaylist([], '通勤');
      expect(created.createdPlaylistId.length > 0).assertTrue();

      let added = toggleTrackInCustomPlaylist(created.playlists, created.createdPlaylistId, 'track-1');
      expect(added.included).assertTrue();
      expect(added.playlists[0].trackIds.length).assertEqual(1);

      let removed = toggleTrackInCustomPlaylist(added.playlists, created.createdPlaylistId, 'track-1');
      expect(removed.included).assertFalse();
      expect(removed.playlists[0].trackIds.length).assertEqual(0);
    });

    it('custom_playlist_remove_clears_playlist_entry', 0, () => {
      let playlists: CustomPlaylist[] = [{
        id: 'fav',
        name: '收藏',
        trackIds: ['a']
      }];
      let removed = removeCustomPlaylist(playlists, 'fav');
      expect(removed.removed).assertTrue();
      expect(removed.playlists.length).assertEqual(0);
    });

    it('track_membership_checks_active_custom_playlist', 0, () => {
      let customPlaylists: CustomPlaylist[] = [{
        id: 'fav',
        name: '收藏',
        trackIds: ['a']
      }];

      expect(trackBelongsToPlaybackCollection(
        'a',
        [buildTrack('a'), buildTrack('b')],
        customPlaylists,
        buildCustomPlaybackCollectionId('fav')
      )).assertTrue();
      expect(trackBelongsToPlaybackCollection(
        'b',
        [buildTrack('a'), buildTrack('b')],
        customPlaylists,
        buildCustomPlaybackCollectionId('fav')
      )).assertFalse();
    });

    it('selector_summaries_filter_empty_collections_and_keep_expected_order', 0, () => {
      let customPlaylists: CustomPlaylist[] = [
        { id: 'empty', name: '空列表', trackIds: [] },
        { id: 'road', name: '开车听', trackIds: ['c'] }
      ];
      let summaries = playbackCollectionSelectorSummaries(
        [
          buildTrack('a', { album: '专辑 A', artist: '歌手甲' }),
          buildTrack('b', { album: '专辑 B', artist: '歌手乙', isFavorite: true }),
          buildTrack('c', { album: '专辑 A', artist: '歌手甲' })
        ],
        customPlaylists
      );

      expect(summaries[0].title).assertEqual('全部音乐');
      expect(summaries[1].title).assertEqual('收藏');
      expect(summaries[summaries.length - 1].title).assertEqual('开车听');
      expect(summaries.some((item) => item.title === '空列表')).assertFalse();
    });

    it('collection_kind_label_matches_ui_copy', 0, () => {
      expect(playbackCollectionKindLabel(PlaybackCollectionKind.All)).assertEqual('全部');
      expect(playbackCollectionKindLabel(PlaybackCollectionKind.Favorites)).assertEqual('收藏');
      expect(playbackCollectionKindLabel(PlaybackCollectionKind.Album)).assertEqual('专辑');
      expect(playbackCollectionKindLabel(PlaybackCollectionKind.Artist)).assertEqual('歌手');
      expect(playbackCollectionKindLabel(PlaybackCollectionKind.Custom)).assertEqual('自定义');
    });
  });
}
