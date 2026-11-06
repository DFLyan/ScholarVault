import { Paper } from '../model/PaperModel'
import { PaperService } from '../service/PaperService'
import { DuplicateGroup, DuplicateService } from '../service/DuplicateService'
import { EmptyState } from '../components/EmptyState'

@Entry
@Component
struct DuplicatesPage {
  @State duplicateGroups: Array<DuplicateGroup> = []
  @State loading: boolean = true
  private paperService: PaperService = new PaperService()

  async aboutToAppear(): Promise<void> {
    await this.loadData()
  }

  private async loadData(): Promise<void> {
    this.loading = true
    const papers = await this.paperService.getAllPapers()
    this.duplicateGroups = DuplicateService.findDuplicates(papers)
    this.loading = false
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text('重复检测')
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

      Text('按 DOI 与标题识别论文库中的重复条目')
        .fontSize(12)
        .fontColor('#999999')
        .padding({ left: 16, right: 16, bottom: 8 })

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.duplicateGroups.length === 0) {
        Column() {
          EmptyState({ icon: '✅', message: '未发现重复论文', subMessage: '论文库很整洁' })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.duplicateGroups, (group: DuplicateGroup, groupIndex: number) => {
              Column({ space: 8 }) {
                Row() {
                  Text(`重复组 ${groupIndex + 1}`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .layoutWeight(1)
                  Text(group.reason)
                    .fontSize(11)
                    .fontColor(Color.White)
                    .backgroundColor('#E67E22')
                    .borderRadius(8)
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                }
                .width('100%')

                ForEach(group.papers, (paper: Paper) => {
                  Row({ space: 8 }) {
                    Column({ space: 3 }) {
                      Text(paper.title)
                        .fontSize(14)
                        .fontColor('#333333')
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Row({ space: 8 }) {
                        if (paper.year > 0) {
                          Text(`${paper.year}`)
                            .fontSize(11)
                            .fontColor('#999999')
                        }
                        if (paper.doi.length > 0) {
                          Text(paper.doi)
                            .fontSize(11)
                            .fontColor('#999999')
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                        if (paper.pdfPath.length > 0) {
                          Text('有PDF')
                            .fontSize(11)
                            .fontColor('#4A90D9')
                        }
                      }
                      .constraintSize({ maxWidth: '90%' })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    Text('删除')
                      .fontSize(12)
                      .fontColor(Color.Red)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .borderRadius(8)
                      .border({ width: 1, color: Color.Red, style: BorderStyle.Solid })
                      .onClick(() => {
                        this.confirmDelete(paper)
                      })
                  }
                  .width('100%')
                  .padding(10)
                  .backgroundColor('#FAFAFA')
                  .borderRadius(8)
                }, (paper: Paper) => `${paper.id}`)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Color.White)
              .borderRadius(12)
            }, (group: DuplicateGroup, groupIndex: number) => `${groupIndex}_${group.reason}_${group.papers.length}`)
          }
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  private confirmDelete(paper: Paper): void {
    this.getUIContext().showAlertDialog({
      title: '删除论文',
      message: `确定删除「${paper.title}」吗？该操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: () => {
          this.deletePaper(paper)
        }
      }
    })
  }

  private async deletePaper(paper: Paper): Promise<void> {
    const ok = await this.paperService.deletePaper(paper.id)
    if (ok) {
      this.getUIContext().getPromptAction().showToast({ message: '已删除' })
      await this.loadData()
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '删除失败' })
    }
  }
}
