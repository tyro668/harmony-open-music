import { image } from '@kit.ImageKit';

import { MusicTrack } from '../models/AppModels';

export function resolveTrackDisplayCover(track: MusicTrack, artwork: image.PixelMap | null): string | image.PixelMap | null {
  if (artwork !== null) {
    return artwork;
  }
  let pic = track.pic.trim();
  if (pic.length > 0) {
    return pic;
  }
  return null;
}
