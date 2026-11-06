import { Paper, ReadStatus, ReadStatusHelper } from '../model/PaperModel'

@Component
export struct PaperCard {
  @Prop paper: Paper = new Paper()
  onCardClick: (paperId: number) => void = (_paperId: number) => {}
  onToggleFavorite: (paperId: number) => void = (_paperId: number) => {}
  onTogglePin: (paperId: number) => void = (_paperId: number) => {}

  private starText(rating: number): string {
    let stars = ''
    for (let i = 0; i < rating; i++) {
      stars += '★'
    }
    return stars
  }

  build() {
    Column() {
      Row() {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            if (this.paper.isPinned > 0) {
              Text('📌')
                .fontSize(13)
            }
            Text(this.paper.title)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')

          Text(this.paper.getAuthorList().join(', '))
            .fontSize(13)
            .fontColor('#666666')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Row({ space: 8 }) {
            Row({ space: 4 }) {
              Circle({ width: 6, height: 6 })
                .fill(ReadStatusHelper.getColor(this.paper.readStatus as ReadStatus))
              Text(ReadStatusHelper.getLabel(this.paper.readStatus as ReadStatus))
                .fontSize(12)
                .fontColor(ReadStatusHelper.getColor(this.paper.readStatus as ReadStatus))
            }

            if (this.paper.year > 0) {
              Text(`${this.paper.year}`)
                .fontSize(12)
                .fontColor('#888888')
            }
            if (this.paper.journal.length > 0) {
              Text(this.paper.journal)
                .fontSize(12)
                .fontColor('#888888')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
          }
          .width('100%')

          Row({ space: 8 }) {
            if (this.paper.rating > 0) {
              Text(this.starText(this.paper.rating))
                .fontSize(12)
                .fontColor('#E8913D')
            }
            if (this.paper.citationCount >= 0) {
              Text(`被引 ${this.paper.citationCount}`)
                .fontSize(12)
                .fontColor('#888888')
            }
            if (this.paper.lastReadPage > 0) {
              Text(`读到第 ${this.paper.lastReadPage} 页`)
                .fontSize(12)
                .fontColor('#888888')
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text(this.paper.isFavorite > 0 ? '★' : '☆')
            .fontSize(20)
            .fontColor(this.paper.isFavorite > 0 ? '#E8913D' : '#BBBBBB')
            .onClick(() => {
              this.onToggleFavorite(this.paper.id)
            })
          if (this.paper.pdfPath.length > 0) {
            Text('PDF')
              .fontSize(11)
              .fontColor('#4A90D9')
              .backgroundColor('#E8F0FE')
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .shadow({ radius: 2, color: '#1A000000', offsetX: 0, offsetY: 1 })
    .onClick(() => {
      this.onCardClick(this.paper.id)
    })
  }
}
