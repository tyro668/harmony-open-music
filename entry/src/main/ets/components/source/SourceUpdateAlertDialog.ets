@Component
export struct SourceUpdateAlertDialog {
  name: string = ''
  log: string = ''
  updateUrl: string = ''
  onClose: () => void = () => {}

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#AA000000')
        .onClick(() => {
          this.onClose();
        })

      Column({ space: 14 }) {
        Text(this.name.length > 0 ? `${this.name} 有新提醒` : '音源更新提醒')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F5F5F5')
          .width('100%')

        Text(this.log)
          .fontSize(13)
          .fontColor('#CACACA')
          .lineHeight(20)
          .width('100%')

        if (this.updateUrl.length > 0) {
          Column({ space: 6 }) {
            Text('更新链接')
              .fontSize(12)
              .fontColor('#777777')
              .width('100%')
            Text(this.updateUrl)
              .fontSize(12)
              .fontColor('#5DB8C9')
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
        }

        Row() {
          Text('关闭')
            .fontSize(13)
            .fontColor('#111111')
            .fontWeight(FontWeight.Medium)
            .padding({ left: 18, right: 18, top: 8, bottom: 8 })
            .backgroundColor('#5DB8C9')
            .borderRadius(14)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('82%')
      .padding({ left: 20, right: 20, top: 18, bottom: 18 })
      .backgroundColor('#171717')
      .borderRadius(20)
    }
    .width('100%')
    .height('100%')
  }
}
