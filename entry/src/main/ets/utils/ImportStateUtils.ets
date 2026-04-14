import { MusicTrack } from '../models/AppModels';

export function hasTrackWithSourceImportKey(localTracks: MusicTrack[], sourceImportKey: string): boolean {
  if (sourceImportKey.trim().length === 0) {
    return false;
  }
  return localTracks.some((track: MusicTrack) => (track.sourceImportKey ?? '') === sourceImportKey);
}

export function appendImportedTrackIfMissing(localTracks: MusicTrack[], importedTrack: MusicTrack): MusicTrack[] {
  if (hasTrackWithSourceImportKey(localTracks, importedTrack.sourceImportKey ?? '')) {
    return localTracks;
  }
  if (localTracks.some((track: MusicTrack) => track.filePath === importedTrack.filePath || track.id === importedTrack.id)) {
    return localTracks;
  }
  return localTracks.concat([importedTrack]);
}
