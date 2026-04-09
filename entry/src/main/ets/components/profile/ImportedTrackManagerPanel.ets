import { image } from '@kit.ImageKit';

import { MusicTrack } from '../../models/AppModels';

@Component
export struct ImportedTrackManagerPanel {
  @Prop tracks: MusicTrack[] = [];
  @Prop coveredTrackIds: string[] = [];
  @State activeFilter: string = 'all';
  @State isSelectionMode: boolean = false;
  @State selectedTrackIds: string[] = [];
  onClose: () => void = () => {};
  onMoveTrackBefore: (trackId: string, referenceTrackId: string) => void = (_: string, __: string) => {};
  onMoveTrackAfter: (trackId: string, referenceTrackId: string) => void = (_: string, __: string) => {};
  onToggleTrackInPlayQueue: (trackId: string) => void = (_: string) => {};
  onRemoveTrack: (trackId: string) => void = (_: string) => {};
  onRemoveTracks: (trackIds: string[]) => void = (_: string[]) => {};
  coverForTrack: (trackId: string) => image.PixelMap | null = (_: string) => null;

  private hasTrackCover(trackId: string): boolean {
    return this.coveredTrackIds.indexOf(trackId) >= 0 && this.coverForTrack(trackId) !== null;
  }

  private trackCover(trackId: string): image.PixelMap {
    return this.coverForTrack(trackId) as image.PixelMap;
  }

  private playQueueCount(): number {
    return this.tracks.filter((track: MusicTrack) => track.inPlayQueue !== false).length;
  }

  private filteredTracks(): MusicTrack[] {
    if (this.activeFilter === 'queued') {
      return this.tracks.filter((track: MusicTrack) => track.inPlayQueue !== false);
    }
    if (this.activeFilter === 'excluded') {
      return this.tracks.filter((track: MusicTrack) => track.inPlayQueue === false);
    }
    return this.tracks;
  }

  private filterCount(filter: string): number {
    if (filter === 'queued') {
      return this.playQueueCount();
    }
    if (filter === 'excluded') {
      return this.tracks.length - this.playQueueCount();
    }
    return this.tracks.length;
  }

  private filterLabel(filter: string): string {
    if (filter === 'queued') {
      return '已在播放列表';
    }
    if (filter === 'excluded') {
      return '未加入播放列表';
    }
    return '全部';
  }

  private isFilterActive(filter: string): boolean {
    return this.activeFilter === filter;
  }

  private isTrackSelected(trackId: string): boolean {
    return this.selectedTrackIds.indexOf(trackId) >= 0;
  }

  private toggleTrackSelection(trackId: string): void {
    let nextSelected = this.selectedTrackIds.filter((selectedId: string) => selectedId !== trackId);
    if (nextSelected.length === this.selectedTrackIds.length) {
      nextSelected.push(trackId);
    }
    this.selectedTrackIds = nextSelected;
  }

  private clearSelection(): void {
    this.selectedTrackIds = [];
  }

  private toggleSelectionMode(): void {
    this.isSelectionMode = !this.isSelectionMode;
    if (!this.isSelectionMode) {
      this.clearSelection();
    }
  }

  private toggleSelectAllVisible(): void {
    let visibleIds = this.filteredTracks().map((track: MusicTrack) => track.id);
    if (visibleIds.length === 0) {
      return;
    }
    let allSelected = visibleIds.every((trackId: string) => this.isTrackSelected(trackId));
    if (allSelected) {
      this.selectedTrackIds = this.selectedTrackIds.filter((trackId: string) => visibleIds.indexOf(trackId) < 0);
      return;
    }
    let nextSelected = this.selectedTrackIds.slice();
    visibleIds.forEach((trackId: string) => {
      if (nextSelected.indexOf(trackId) < 0) {
        nextSelected.push(trackId);
      }
    });
    this.selectedTrackIds = nextSelected;
  }

  private selectedVisibleCount(): number {
    return this.filteredTracks().filter((track: MusicTrack) => this.isTrackSelected(track.id)).length;
  }

  private handleBatchRemove(): void {
    if (this.selectedTrackIds.length === 0) {
      return;
    }
    this.onRemoveTracks(this.selectedTrackIds.slice());
    this.clearSelection();
    this.isSelectionMode = false;
  }

  private queueActionIcon(track: MusicTrack): Resource {
    return track.inPlayQueue !== false ? $r('app.media.ic_minus') : $r('app.media.ic_plus');
  }

  private queueActionBackground(track: MusicTrack): string {
    return track.inPlayQueue !== false ? '#2B2414' : '#16333B';
  }

  private queueActionBorder(track: MusicTrack): string {
    return track.inPlayQueue !== false ? '#564418' : '#21505B';
  }

  private trackLocation(track: MusicTrack): string {
    if (track.folder.length > 0) {
      return track.folder;
    }
    if (track.album.length > 0) {
      return track.album;
    }
    return '本地音乐';
  }

  private filteredTrackIndex(trackId: string): number {
    return this.filteredTracks().findIndex((track: MusicTrack) => track.id === trackId);
  }

  private canMoveUp(trackId: string): boolean {
    return this.filteredTrackIndex(trackId) > 0;
  }

  private canMoveDown(trackId: string): boolean {
    let index = this.filteredTrackIndex(trackId);
    return index >= 0 && index < this.filteredTracks().length - 1;
  }

  private moveTrackUp(trackId: string): void {
    let filteredTracks = this.filteredTracks();
    let index = filteredTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (index <= 0) {
      return;
    }
    this.onMoveTrackBefore(trackId, filteredTracks[index - 1].id);
  }

  private moveTrackDown(trackId: string): void {
    let filteredTracks = this.filteredTracks();
    let index = filteredTracks.findIndex((track: MusicTrack) => track.id === trackId);
    if (index < 0 || index >= filteredTracks.length - 1) {
      return;
    }
    this.onMoveTrackAfter(trackId, filteredTracks[index + 1].id);
  }

  @Builder
  private trackArtwork(track: MusicTrack) {
    if (this.hasTrackCover(track.id)) {
      Stack() {
        Row()
          .width(38)
          .height(38)
          .backgroundColor(track.accentColor)
          .borderRadius(10)

        Image(this.trackCover(track.id))
          .width(38)
          .height(38)
          .objectFit(ImageFit.Cover)
          .borderRadius(10)
      }
      .width(38)
      .height(38)
    } else if (track.pic.length > 0) {
      Stack() {
        Row()
          .width(38)
          .height(38)
          .backgroundColor(track.accentColor)
          .borderRadius(10)

        Image(track.pic)
          .width(38)
          .height(38)
          .objectFit(ImageFit.Cover)
          .borderRadius(10)
      }
      .width(38)
      .height(38)
    } else {
      Row() {
        Image($r('app.media.ic_note'))
          .width(16)
          .height(16)
          .opacity(0.82)
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(track.accentColor)
      .borderRadius(10)
    }
  }

  @Builder
  private iconActionButton(
    icon: Resource,
    backgroundColor: string,
    borderColor: string,
    enabled: boolean,
    rotation: number,
    action: () => void
  ) {
    Row() {
      Image(icon)
        .width(16)
        .height(16)
        .opacity(enabled ? 1 : 0.32)
        .rotate({
          angle: rotation,
          x: 0,
          y: 0,
          z: 1,
          centerX: '50%',
          centerY: '50%'
        })
    }
    .width(32)
    .height(32)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(enabled ? backgroundColor : '#161616')
    .borderRadius(16)
    .border({
      width: 1,
      color: enabled ? borderColor : '#242424'
    })
    .opacity(enabled ? 1 : 0.75)
    .onClick(() => {
      if (enabled) {
        action();
      }
    })
  }

  @Builder
  private filterChip(filter: string) {
    Text(`${this.filterLabel(filter)} ${this.filterCount(filter)}`)
      .fontSize(13)
      .fontWeight(this.isFilterActive(filter) ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.isFilterActive(filter) ? '#050505' : '#A9A9A9')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.isFilterActive(filter) ? '#5DB8C9' : '#1A1A1A')
      .borderRadius(15)
      .onClick(() => {
        this.activeFilter = filter;
      })
  }

  @Builder
  private selectionToggle(track: MusicTrack) {
    Row() {
      if (this.isTrackSelected(track.id)) {
        Text('✓')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#050505')
      }
    }
    .width(24)
    .height(24)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isTrackSelected(track.id) ? '#5DB8C9' : '#1A1A1A')
    .borderRadius(12)
    .border({
      width: 1,
      color: this.isTrackSelected(track.id) ? '#5DB8C9' : '#333333'
    })
  }

  build() {
    Column() {
      Column() {
        Row() {
          Text('导入音乐管理')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F5F5F5')
            .layoutWeight(1)

          Row({ space: 16 }) {
            Text(this.isSelectionMode ? '取消选择' : '批量管理')
              .fontSize(13)
              .fontColor('#D6B65D')
              .onClick(() => {
                this.toggleSelectionMode();
              })

            Text('关闭')
              .fontSize(14)
              .fontColor('#5DB8C9')
              .onClick(() => {
                this.onClose();
              })
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14, bottom: 10 })

        Row({ space: 10 }) {
          this.filterChip('all')
          this.filterChip('queued')
          this.filterChip('excluded')
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 10 })

        if (this.isSelectionMode) {
          Row() {
            Text(`已选 ${this.selectedTrackIds.length} 首`)
              .fontSize(12)
              .fontColor('#B4B4B4')
            Blank()
            Text(this.selectedVisibleCount() === this.filteredTracks().length && this.filteredTracks().length > 0 ? '取消全选' : '全选当前筛选')
              .fontSize(12)
              .fontColor('#5DB8C9')
              .onClick(() => {
                this.toggleSelectAllVisible();
              })
            this.iconActionButton(
              $r('app.media.ic_trash'),
              this.selectedTrackIds.length > 0 ? '#2A1515' : '#1E1515',
              this.selectedTrackIds.length > 0 ? '#5C2020' : '#302020',
              this.selectedTrackIds.length > 0,
              0,
              () => {
                this.handleBatchRemove();
              }
            )
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 8 })
        }

        Scroll() {
          Column({ space: 0 }) {
            if (this.filteredTracks().length === 0) {
              Column({ space: 8 }) {
                Text(this.tracks.length === 0 ? '暂无导入音乐' : '当前筛选下没有歌曲')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#888888')
              }
              .width('100%')
              .padding({ top: 28, bottom: 28 })
              .alignItems(HorizontalAlign.Center)
            } else {
              ForEach(this.filteredTracks(), (track: MusicTrack, index: number) => {
                Column({ space: 0 }) {
                  Row({ space: 12 }) {
                    if (this.isSelectionMode) {
                      this.selectionToggle(track)
                    }

                    this.trackArtwork(track)

                    Column({ space: 4 }) {
                      Text(track.title)
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#F0F0F0')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`${track.artist} · ${this.trackLocation(track)}`)
                        .fontSize(11)
                        .fontColor('#777777')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    if (!this.isSelectionMode) {
                      Row({ space: 8 }) {
                        this.iconActionButton(
                          $r('app.media.ic_chevron_right'),
                          '#1A1A1A',
                          '#2B2B2B',
                          this.canMoveUp(track.id),
                          -90,
                          () => {
                            this.moveTrackUp(track.id);
                          }
                        )
                        this.iconActionButton(
                          $r('app.media.ic_chevron_right'),
                          '#1A1A1A',
                          '#2B2B2B',
                          this.canMoveDown(track.id),
                          90,
                          () => {
                            this.moveTrackDown(track.id);
                          }
                        )
                        this.iconActionButton(
                          this.queueActionIcon(track),
                          this.queueActionBackground(track),
                          this.queueActionBorder(track),
                          true,
                          0,
                          () => {
                            this.onToggleTrackInPlayQueue(track.id);
                          }
                        )
                        this.iconActionButton(
                          $r('app.media.ic_trash'),
                          '#2A1515',
                          '#5C2020',
                          true,
                          0,
                          () => {
                            this.onRemoveTrack(track.id);
                          }
                        )
                      }
                    }
                  }
                  .width('100%')
                  .onClick(() => {
                    if (this.isSelectionMode) {
                      this.toggleTrackSelection(track.id);
                    }
                  })
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 12, bottom: 12 })
                .backgroundColor(this.isSelectionMode && this.isTrackSelected(track.id) ? '#171F23' : Color.Transparent)
                .borderRadius(14)

                if (index < this.filteredTracks().length - 1) {
                  Row()
                    .width('100%')
                    .height(1)
                    .backgroundColor('#222222')
                    .margin({ left: 20, right: 20 })
                }
              }, (track: MusicTrack) => track.id)
            }
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.None)
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#111111')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
