import { picker, fileIo as fs } from '@kit.CoreFileKit'
import { Paper } from '../model/PaperModel'
import { PaperService } from '../service/PaperService'
import { CitationService } from '../service/CitationService'
import { CitationFormat, CitationFormatHelper } from '../model/CitationStyle'
import { CitationExportParams } from '../model/RouteParams'
import { pasteboard } from '@kit.BasicServicesKit'
import { BusinessError } from '@kit.BasicServicesKit'

@Entry
@Component
struct CitationExportPage {
  @State paper: Paper = new Paper()
  @State currentFormat: CitationFormat = CitationFormat.BIBTEX
  @State citationText: string = ''
  @State allPapers: Array<Paper> = []
  @State exportAll: boolean = false
  private paperService: PaperService = new PaperService()
  private paperId: number = 0

  async aboutToAppear(): Promise<void> {
    const params = this.getUIContext().getRouter().getParams() as CitationExportParams
    this.paperId = params?.paperId ?? 0
    if (this.paperId > 0) {
      const paper = await this.paperService.getPaperById(this.paperId)
      if (paper !== undefined) {
        this.paper = paper
      }
    }
    this.allPapers = await this.paperService.getAllPapers()
    this.updateCitation()
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text('导出引用')
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

      Scroll() {
        Column({ space: 16 }) {
          Row() {
            Text('引用格式:')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Row({ space: 4 }) {
              ForEach([CitationFormat.BIBTEX, CitationFormat.APA, CitationFormat.MLA, CitationFormat.RIS], (fmt: CitationFormat) => {
                Text(CitationFormatHelper.getLabel(fmt))
                  .fontSize(14)
                  .fontColor(this.currentFormat === fmt ? Color.White : '#4A90D9')
                  .backgroundColor(this.currentFormat === fmt ? '#4A90D9' : '#E8F0FE')
                  .borderRadius(8)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .onClick(() => {
                    this.currentFormat = fmt
                    this.updateCitation()
                  })
              }, (fmt: CitationFormat) => `${fmt}`)
            }
            .margin({ left: 8 })
          }
          .width('100%')

          Row() {
            Text('导出范围:')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Row({ space: 8 }) {
              Text('当前论文')
                .fontSize(14)
                .fontColor(!this.exportAll ? Color.White : '#4A90D9')
                .backgroundColor(!this.exportAll ? '#4A90D9' : '#E8F0FE')
                .borderRadius(8)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.exportAll = false
                  this.updateCitation()
                })
              Text('全部论文')
                .fontSize(14)
                .fontColor(this.exportAll ? Color.White : '#4A90D9')
                .backgroundColor(this.exportAll ? '#4A90D9' : '#E8F0FE')
                .borderRadius(8)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.exportAll = true
                  this.updateCitation()
                })
            }
            .margin({ left: 8 })
          }
          .width('100%')

          Text('预览')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')

          Text(this.citationText)
            .fontSize(13)
            .fontColor('#444444')
            .fontFamily('monospace')
            .width('100%')
            .padding(16)
            .backgroundColor('#F8F8F8')
            .borderRadius(12)
            .copyOption(CopyOptions.LocalDevice)

          Button('复制到剪贴板')
            .fontSize(16)
            .backgroundColor('#4A90D9')
            .fontColor(Color.White)
            .borderRadius(8)
            .width('100%')
            .onClick(() => {
              this.copyToClipboard()
            })

          Button('导出为文件')
            .fontSize(16)
            .backgroundColor(Color.White)
            .fontColor('#4A90D9')
            .border({ width: 1, color: '#4A90D9', style: BorderStyle.Solid })
            .borderRadius(8)
            .width('100%')
            .onClick(() => {
              this.exportToFile()
            })
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  private updateCitation(): void {
    if (this.exportAll) {
      this.citationText = CitationService.generateMultipleCitations(this.allPapers, this.currentFormat)
    } else {
      this.citationText = CitationService.generateCitation(this.paper, this.currentFormat)
    }
  }

  private copyToClipboard(): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.citationText)
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        this.getUIContext().getPromptAction().showToast({ message: '已复制到剪贴板' })
      })
      .catch((err: BusinessError) => {
        this.getUIContext().getPromptAction().showToast({ message: `复制失败: ${err.message}` })
      })
  }

  private async exportToFile(): Promise<void> {
    try {
      const ext = CitationFormatHelper.getFileExtension(this.currentFormat)
      const options = new picker.DocumentSaveOptions()
      options.newFileNames = [`scholarvault_export${ext}`]
      const docPicker = new picker.DocumentViewPicker()
      const uris: Array<string> = await docPicker.save(options)
      if (uris.length > 0) {
        const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        fs.writeSync(file.fd, this.citationText)
        fs.closeSync(file)
        this.getUIContext().getPromptAction().showToast({ message: '导出成功' })
      }
    } catch (e) {
      this.getUIContext().getPromptAction().showToast({ message: '导出失败' })
    }
  }
}
