@Component
export struct EmptyState {
  icon: string = '📚'
  message: string = '暂无内容'
  subMessage: string = ''

  build() {
    Column({ space: 8 }) {
      Text(this.icon)
        .fontSize(48)
      Text(this.message)
        .fontSize(16)
        .fontColor('#666666')
      if (this.subMessage.length > 0) {
        Text(this.subMessage)
          .fontSize(13)
          .fontColor('#999999')
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
