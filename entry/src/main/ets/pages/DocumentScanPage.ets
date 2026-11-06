import { picker } from '@kit.CoreFileKit'
import { PaperService } from '../service/PaperService'
import { DocumentScanService, ScannedDocument } from '../service/DocumentScanService'
import { Paper } from '../model/PaperModel'

class PendingFile {
  uri: string = ''
  fileName: string = ''

  constructor(uri: string, fileName: string) {
    this.uri = uri
    this.fileName = fileName
  }
}

@Entry
@Component
struct DocumentScanPage {
  @State pendingFiles: Array<PendingFile> = []
  @State scanning: boolean = false
  @State scanIndex: number = 0
  @State results: Array<ScannedDocument> = []
  @State errorText: string = ''
  private paperService: PaperService = new PaperService()

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text('文档扫描')
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

      Column() {
        Text('扫描本地文档，自动定位其中包含的论文')
          .fontSize(13)
          .fontColor('#666666')
          .width('100%')
        Text('支持 PDF / Word / Excel / TXT / Markdown，通过论文标题匹配并记录所在页码')
          .fontSize(12)
          .fontColor('#999999')
          .width('100%')
          .margin({ top: 4 })
      }
      .padding({ left: 16, right: 16 })
      .alignItems(HorizontalAlign.Start)

      if (this.results.length > 0) {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.results, (doc: ScannedDocument) => {
              this.DocumentResultCard(doc)
            }, (doc: ScannedDocument) => doc.filePath)
          }
          .padding(16)
        }
        .layoutWeight(1)
      } else {
        Column({ space: 16 }) {
          Text(this.pendingFiles.length === 0 ? '尚未选择文档' : `已选择 ${this.pendingFiles.length} 个文档`)
            .fontSize(14)
            .fontColor('#999999')

          if (this.pendingFiles.length > 0) {
            Column({ space: 8 }) {
              ForEach(this.pendingFiles, (file: PendingFile) => {
                Row({ space: 8 }) {
                  Text(this.FileIcon(file.fileName))
                    .fontSize(18)
                  Text(file.fileName)
                    .fontSize(13)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text('×')
                    .fontSize(16)
                    .fontColor('#999999')
                    .onClick(() => {
                      this.removePendingFile(file)
                    })
                }
                .width('100%')
                .padding(10)
                .backgroundColor(Color.White)
                .borderRadius(8)
              }, (file: PendingFile) => file.uri)
            }
            .width('100%')
          }

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(13)
              .fontColor(Color.Red)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
      }

      Row({ space: 12 }) {
        Button('选择文档')
          .fontSize(14)
          .backgroundColor(Color.White)
          .fontColor('#4A90D9')
          .border({ width: 1, color: '#4A90D9', style: BorderStyle.Solid })
          .borderRadius(8)
          .layoutWeight(1)
          .enabled(!this.scanning)
          .onClick(() => {
            this.pickFiles()
          })

        Button(this.scanning ? `扫描中 ${this.scanIndex + 1}/${this.pendingFiles.length}` : '开始扫描')
          .fontSize(14)
          .backgroundColor('#4A90D9')
          .fontColor(Color.White)
          .borderRadius(8)
          .layoutWeight(1)
          .enabled(!this.scanning && this.pendingFiles.length > 0)
          .onClick(() => {
            this.startScan()
          })

        if (this.scanning) {
          LoadingProgress()
            .width(20)
            .height(20)
        }
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  DocumentResultCard(doc: ScannedDocument) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.FileIcon(doc.fileName))
          .fontSize(18)
        Text(doc.fileName)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(doc.matchedPaperTitles.length > 0 ? `${doc.matchedPaperTitles.length} 篇` : '无匹配')
          .fontSize(12)
          .fontColor(doc.matchedPaperTitles.length > 0 ? '#4A90D9' : '#999999')
      }
      .width('100%')

      if (doc.matchedPaperTitles.length === 0) {
        Text('未在文档中找到论文库中的论文')
          .fontSize(12)
          .fontColor('#999999')
          .width('100%')
      } else {
        ForEach(doc.matchedPaperTitles, (title: string, index: number) => {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(title)
                .fontSize(13)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (doc.matchedPages[index] !== undefined && doc.matchedPages[index].length > 0) {
                Text(`位于第 ${doc.matchedPages[index]} 页`)
                  .fontSize(11)
                  .fontColor('#E8913D')
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }, (title: string) => `${doc.filePath}_${title}`)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  private FileIcon(fileName: string): string {
    const lower = fileName.toLowerCase()
    if (lower.endsWith('.pdf')) {
      return '📄'
    }
    if (lower.endsWith('.docx')) {
      return '📝'
    }
    if (lower.endsWith('.xlsx')) {
      return '📊'
    }
    return '📃'
  }

  private removePendingFile(file: PendingFile): void {
    const index = this.pendingFiles.indexOf(file)
    if (index >= 0) {
      this.pendingFiles.splice(index, 1)
    }
  }

  private async pickFiles(): Promise<void> {
    this.errorText = ''
    try {
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = ['.pdf', '.docx', '.xlsx', '.txt', '.md']
      options.maxSelectNumber = 10
      const docPicker = new picker.DocumentViewPicker()
      const uris: Array<string> = await docPicker.select(options)
      for (let i = 0; i < uris.length; i++) {
        const slashIndex = uris[i].lastIndexOf('/')
        const rawName = slashIndex >= 0 ? decodeURIComponent(uris[i].substring(slashIndex + 1)) : uris[i]
        const fileName = rawName.split('?')[0]
        if (!DocumentScanService.isSupported(fileName)) {
          continue
        }
        let exists = false
        for (let j = 0; j < this.pendingFiles.length; j++) {
          if (this.pendingFiles[j].uri === uris[i]) {
            exists = true
            break
          }
        }
        if (!exists) {
          this.pendingFiles.push(new PendingFile(uris[i], fileName))
        }
      }
    } catch (e) {
      // 用户取消选择时忽略
    }
  }

  private async startScan(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.errorText = '获取应用上下文失败'
      return
    }
    this.scanning = true
    this.results = []
    this.errorText = ''
    try {
      const papers: Array<Paper> = await this.paperService.getAllPapers()
      for (let i = 0; i < this.pendingFiles.length; i++) {
        this.scanIndex = i
        const file = this.pendingFiles[i]
        const fileType = DocumentScanService.getFileType(file.fileName)
        const localPath = await DocumentScanService.copyToScanDir(context, file.uri, file.fileName)
        const doc = await DocumentScanService.scanDocument(file.fileName, localPath, fileType, papers)
        this.results.push(doc)
      }
      DocumentScanService.cleanupScanDir(context)
      this.pendingFiles = []
    } catch (e) {
      this.errorText = '扫描过程出现错误，请重试'
      DocumentScanService.cleanupScanDir(context)
    }
    this.scanIndex = 0
    this.scanning = false
  }
}
