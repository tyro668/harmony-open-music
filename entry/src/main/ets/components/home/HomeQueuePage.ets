import { MusicTrack, PlayMode } from '../../models/AppModels';

@Component
export struct HomeQueuePage {
  @Prop tracks: MusicTrack[] = [];
  @Prop currentTrackId: string = '';
  @Prop playMode: PlayMode = PlayMode.Sequential;
  @Prop showRenameDialog: boolean = false;
  @Prop renameText: string = '';
  onSelectPlayMode: (mode: PlayMode) => void = (_: PlayMode) => {};
  onTrackTap: (track: MusicTrack) => void = (_: MusicTrack) => {};
  onToggleFavorite: (trackId: string) => void = (_: string) => {};
  onOpenRename: (track: MusicTrack) => void = (_: MusicTrack) => {};
  onRenameTextChange: (value: string) => void = (_: string) => {};
  onCancelRename: () => void = () => {};
  onConfirmRename: () => void = () => {};
  trackDurationText: (track: MusicTrack) => string = (_: MusicTrack) => '--:--';

  @Builder
  private playModeButton(label: string, icon: Resource, mode: PlayMode) {
    Row({ space: 5 }) {
      Image(icon)
        .width(14)
        .height(14)
        .fillColor(this.playMode === mode ? '#FFFFFF' : '#8A8A8A')

      Text(label)
        .fontSize(13)
        .fontColor(this.playMode === mode ? '#FFFFFF' : '#8A8A8A')
        .fontWeight(this.playMode === mode ? FontWeight.Medium : FontWeight.Normal)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(this.playMode === mode ? '#1DB4B4' : Color.Transparent)
    .borderRadius(19)
    .onClick(() => {
      this.onSelectPlayMode(mode);
    })
  }

  @Builder
  private playlistHeader() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 6 }) {
          Text('播放队列')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F9F9F9')

          Row({ space: 6 }) {
            Image($r('app.media.ic_list'))
              .width(16)
              .height(16)
              .fillColor('#5DB8C9')

            Text(`共 ${this.tracks.length} 首歌曲`)
              .fontSize(13)
              .fontColor('#8A8A8A')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 0 }) {
          this.playModeButton('随机', $r('app.media.ic_shuffle'), PlayMode.Shuffle)
          this.playModeButton('顺序', $r('app.media.ic_sequential'), PlayMode.Sequential)
          this.playModeButton('循环', $r('app.media.ic_loop'), PlayMode.Loop)
        }
        .backgroundColor('#1A1A2E')
        .borderRadius(22)
        .padding(3)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ bottom: 10 })
  }

  @Builder
  private coverArt(track: MusicTrack, size: number) {
    Row() {
      Image($r('app.media.ic_note'))
        .width(size * 0.34)
        .height(size * 0.34)
        .opacity(0.45)
    }
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(track.accentColor)
    .borderRadius(14)
  }

  @Builder
  private trackRow(track: MusicTrack) {
    Row({ space: 10 }) {
      if (this.currentTrackId === track.id) {
        Stack({ alignContent: Alignment.Center }) {
          this.coverArt(track, 58)
          Row() {
            Image($r('app.media.ic_play'))
              .width(18)
              .height(18)
              .fillColor('#FFFFFF')
          }
          .width(58)
          .height(58)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#00000066')
          .borderRadius(14)
        }
        .width(58)
        .height(58)
      } else {
        this.coverArt(track, 58)
      }

      Column({ space: 5 }) {
        Text(track.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.currentTrackId === track.id ? '#FFFFFF' : '#F3F3F3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(track.artist)
          .fontSize(13)
          .fontColor('#888888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image(track.isFavorite ? $r('app.media.ic_heart_filled') : $r('app.media.ic_heart'))
        .width(20)
        .height(20)
        .fillColor(track.isFavorite ? '#E85D75' : '#666666')
        .onClick(() => {
          this.onToggleFavorite(track.id);
        })

      Row({ space: 4 }) {
        Image($r('app.media.ic_clock'))
          .width(14)
          .height(14)
          .fillColor('#666666')

        Text(this.trackDurationText(track))
          .fontSize(13)
          .fontColor('#666666')
      }

      Image($r('app.media.ic_more'))
        .width(20)
        .height(20)
        .fillColor('#666666')
        .onClick(() => {
          this.onOpenRename(track);
        })
    }
    .width('100%')
    .padding({ left: 12, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.currentTrackId === track.id ? '#1A1A30' : '#0D0D1A')
    .borderRadius(16)
    .border({
      width: this.currentTrackId === track.id ? 1 : 0,
      color: '#2A2A44'
    })
    .onClick(() => {
      this.onTrackTap(track);
    })
  }

  @Builder
  private emptyState() {
    Column({ space: 10 }) {
      Text('当前没有歌曲')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F0F0F0')
      Text('前往“我的”页导入本地音乐或在线下载音频')
        .fontSize(14)
        .fontColor('#777777')
        .textAlign(TextAlign.Center)
        .lineHeight(22)
    }
    .width('100%')
    .padding({ top: 56, bottom: 56, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private renameDialog() {
    Column() {
      Column({ space: 20 }) {
        Text('修改歌曲名称')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7F7F7')

        TextInput({ text: this.renameText, placeholder: '输入新名称' })
          .placeholderColor('#5E5E5E')
          .fontSize(16)
          .fontColor('#F5F5F5')
          .backgroundColor('#1A1A1A')
          .caretColor('#1DB4B4')
          .borderRadius(14)
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .onChange((value: string) => {
            this.onRenameTextChange(value);
          })

        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#2A2A2A')
            .fontColor('#D0D0D0')
            .borderRadius(21)
            .onClick(() => {
              this.onCancelRename();
            })

          Button('确认')
            .layoutWeight(1)
            .height(42)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#1DB4B4')
            .fontColor('#FFFFFF')
            .borderRadius(21)
            .onClick(() => {
              this.onConfirmRename();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(24)
      .backgroundColor('#121212')
      .borderRadius(24)
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 40 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: 4 }) {
          this.playlistHeader()

          if (this.tracks.length === 0) {
            this.emptyState()
          } else {
            ForEach(this.tracks, (track: MusicTrack) => {
              this.trackRow(track)
            }, (track: MusicTrack) => track.id)
          }
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .padding({ left: 12, right: 12, top: 14, bottom: 20 })
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.None)
      .width('100%')
      .height('100%')

      if (this.showRenameDialog) {
        this.renameDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
