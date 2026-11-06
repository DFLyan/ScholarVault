import { Paper, ReadStatus, ReadStatusHelper } from '../model/PaperModel'
import { StatItem } from '../model/NoteModel'
import { PaperService } from '../service/PaperService'
import { EmptyState } from '../components/EmptyState'

@Entry
@Component
struct StatisticsPage {
  @State allPapers: Array<Paper> = []
  @State yearStats: Array<StatItem> = []
  @State journalStats: Array<StatItem> = []
  @State tagStats: Array<StatItem> = []
  @State notesCount: number = 0
  @State loading: boolean = true
  private paperService: PaperService = new PaperService()

  async aboutToAppear(): Promise<void> {
    await this.loadData()
  }

  private async loadData(): Promise<void> {
    this.loading = true
    this.allPapers = await this.paperService.getAllPapers()
    this.yearStats = await this.paperService.getYearStats()
    this.journalStats = await this.paperService.getJournalStats(10)
    this.tagStats = await this.paperService.getTagStats(10)
    this.notesCount = await this.paperService.countAllNotes()
    this.loading = false
  }

  private countByReadStatus(status: ReadStatus): number {
    let count = 0
    for (let i = 0; i < this.allPapers.length; i++) {
      if (this.allPapers[i].readStatus === status) {
        count++
      }
    }
    return count
  }

  private countFavorites(): number {
    let count = 0
    for (let i = 0; i < this.allPapers.length; i++) {
      if (this.allPapers[i].isFavorite > 0) {
        count++
      }
    }
    return count
  }

  private countWithPdf(): number {
    let count = 0
    for (let i = 0; i < this.allPapers.length; i++) {
      if (this.allPapers[i].pdfPath.length > 0) {
        count++
      }
    }
    return count
  }

  private countRated(): number {
    let count = 0
    for (let i = 0; i < this.allPapers.length; i++) {
      if (this.allPapers[i].rating > 0) {
        count++
      }
    }
    return count
  }

  private maxYearCount(): number {
    let max = 0
    for (let i = 0; i < this.yearStats.length; i++) {
      if (this.yearStats[i].count > max) {
        max = this.yearStats[i].count
      }
    }
    return max > 0 ? max : 1
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text('统计面板')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('  ')
          .fontSize(22)
      }
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            this.SummaryCards()
            this.ReadStatusSection()
            this.YearSection()
            this.JournalSection()
            this.TagSection()
          }
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  SummaryCards() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
      this.StatCard('📚', '论文总数', `${this.allPapers.length}`)
      this.StatCard('⭐', '收藏论文', `${this.countFavorites()}`)
      this.StatCard('📄', 'PDF 附件', `${this.countWithPdf()}`)
      this.StatCard('📝', '论文笔记', `${this.notesCount}`)
    }
    .width('100%')
  }

  @Builder
  StatCard(icon: string, label: string, value: string) {
    Column({ space: 6 }) {
      Text(icon)
        .fontSize(24)
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
      Text(label)
        .fontSize(12)
        .fontColor('#888888')
    }
    .width('48%')
    .padding({ top: 16, bottom: 16 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 8 })
  }

  @Builder
  ReadStatusSection() {
    Column({ space: 12 }) {
      Text('阅读状态')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Row({ space: 8 }) {
        ForEach([ReadStatus.UNREAD, ReadStatus.READING, ReadStatus.DONE], (status: ReadStatus) => {
          Column({ space: 4 }) {
            Text(`${this.countByReadStatus(status)}`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
            Text(ReadStatusHelper.getLabel(status))
              .fontSize(12)
              .fontColor('#888888')
          }
          .layoutWeight(1)
          .padding({ top: 12, bottom: 12 })
          .backgroundColor(Color.White)
          .borderRadius(10)
          .border({ width: 1, color: ReadStatusHelper.getColor(status), style: BorderStyle.Solid })
        }, (status: ReadStatus) => `${status}`)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  YearSection() {
    Column({ space: 12 }) {
      Text('年份分布')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      if (this.yearStats.length === 0) {
        EmptyState({ icon: '📅', message: '暂无年份数据', subMessage: '添加论文年份后展示' })
          .height(100)
      } else {
        Column({ space: 8 }) {
          ForEach(this.yearStats, (item: StatItem) => {
            Row({ space: 8 }) {
              Text(item.name)
                .fontSize(12)
                .fontColor('#666666')
                .width(44)
              Stack({ alignContent: Alignment.Start }) {
                Column()
                  .height(12)
                  .width(`${Math.round(item.count / this.maxYearCount() * 100)}%`)
                  .backgroundColor('#4A90D9')
                  .borderRadius(6)
              }
              .layoutWeight(1)
              .height(12)
              .backgroundColor('#F0F0F0')
              .borderRadius(6)
              Text(`${item.count}`)
                .fontSize(12)
                .fontColor('#666666')
                .width(28)
            }
            .width('100%')
          }, (item: StatItem) => `${item.name}`)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Color.White)
        .borderRadius(12)
      }
    }
    .width('100%')
  }

  @Builder
  JournalSection() {
    Column({ space: 12 }) {
      Text('Top 期刊/会议')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      if (this.journalStats.length === 0) {
        EmptyState({ icon: '📖', message: '暂无期刊数据', subMessage: '添加论文期刊后展示' })
          .height(100)
      } else {
        Column({ space: 8 }) {
          ForEach(this.journalStats, (item: StatItem, index: number) => {
            Row({ space: 8 }) {
              Text(`${index + 1}`)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor(index < 3 ? '#4A90D9' : '#AAAAAA')
                .borderRadius(9)
                .width(18)
                .height(18)
                .textAlign(TextAlign.Center)
              Text(item.name)
                .fontSize(13)
                .fontColor('#333333')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${item.count} 篇`)
                .fontSize(12)
                .fontColor('#888888')
            }
            .width('100%')
          }, (item: StatItem) => `${item.name}`)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Color.White)
        .borderRadius(12)
      }
    }
    .width('100%')
  }

  @Builder
  TagSection() {
    Column({ space: 12 }) {
      Text('Top 标签')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      if (this.tagStats.length === 0) {
        EmptyState({ icon: '🏷️', message: '暂无标签数据', subMessage: '为论文添加标签后展示' })
          .height(100)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tagStats, (item: StatItem) => {
            Text(`${item.name} (${item.count})`)
              .fontSize(12)
              .fontColor('#4A90D9')
              .backgroundColor('#E8F0FE')
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .margin({ right: 8, bottom: 8 })
          }, (item: StatItem) => `${item.name}`)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Color.White)
        .borderRadius(12)
      }
    }
    .width('100%')
  }
}
