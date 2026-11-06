import { PdfReaderParams } from '../model/RouteParams'
import { pdfService, PdfView, pdfViewManager } from '@kit.PDFKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PaperService } from '../service/PaperService'
import { ReaderNote } from '../model/NoteModel'
import { ReadStatus } from '../model/PaperModel'

const DOMAIN = 0x0000
const TAG = 'PdfReaderPage'

const ANNOT_COLORS: Array<number> = [0xFFFFFF00, 0xFF64B5F6, 0xFFFF5252, 0xFF69F0AE]
const ANNOT_COLOR_LABELS: Array<string> = ['黄', '蓝', '红', '绿']

@Entry
@Component
struct PdfReaderPage {
  @State paperTitle: string = ''
  @State currentPage: number = 1
  @State totalPages: number = 0
  @State currentZoom: number = 100
  @State pdfLoaded: boolean = false
  @State errorMessage: string = ''
  @State annotMode: number = -1
  @State annotColorIndex: number = 0
  @State hasUnsavedAnnotations: boolean = false
  @State notesSheetVisible: boolean = false
  @State readerNotes: Array<ReaderNote> = []
  @State newNoteText: string = ''
  @State showSearch: boolean = false
  @State searchText: string = ''
  @State searchTotal: number = 0
  @State searchIndex: number = 0
  private pdfPath: string = ''
  private paperId: number = 0
  private initialPage: number = 0
  private lastReportedPage: number = 1
  private paperService: PaperService = new PaperService()
  private pdfController: pdfViewManager.PdfController = new pdfViewManager.PdfController()

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as PdfReaderParams
    this.pdfPath = params?.pdfPath ?? ''
    this.paperTitle = params?.paperTitle ?? ''
    this.paperId = params?.paperId ?? 0
    this.initialPage = params?.initialPage ?? 0
    if (this.pdfPath.length > 0) {
      this.loadPdf()
    }
  }

  aboutToDisappear(): void {
    this.saveProgress(this.lastReportedPage)
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            this.saveProgress(this.lastReportedPage)
            this.getUIContext().getRouter().back()
          })
        Text(this.paperTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 12, right: 12 })
        Text(`${this.currentPage}/${this.totalPages}`)
          .fontSize(14)
          .fontColor('#666666')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Color.White)

      this.ToolbarRow()

      if (this.showSearch) {
        this.SearchRow()
      }

      if (this.pdfLoaded) {
        PdfView({
          controller: this.pdfController,
          pageFit: pdfService.PageFit.FIT_WIDTH,
          showScroll: true
        })
        .layoutWeight(1)
        .width('100%')
        .bindSheet($$this.notesSheetVisible, this.NotesSheetBuilder(), {
          height: SheetSize.MEDIUM,
          dragBar: true
        })
      } else if (this.errorMessage.length > 0) {
        Column() {
          Text('PDF 加载失败')
            .fontSize(18)
            .fontColor(Color.Red)
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      Row({ space: 16 }) {
        Button('上一页')
          .fontSize(14)
          .height(40)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .borderRadius(8)
          .onClick(() => {
            this.prevPage()
          })

        Row({ space: 8 }) {
          Button('-')
            .fontSize(18)
            .width(40)
            .height(40)
            .borderRadius(8)
            .backgroundColor('#F0F0F0')
            .fontColor('#333333')
            .onClick(() => {
              this.zoomOut()
            })
          Text(`${this.currentZoom}%`)
            .fontSize(14)
            .width(50)
            .textAlign(TextAlign.Center)
          Button('+')
            .fontSize(18)
            .width(40)
            .height(40)
            .borderRadius(8)
            .backgroundColor('#F0F0F0')
            .fontColor('#333333')
            .onClick(() => {
              this.zoomIn()
            })
        }

        Button('下一页')
          .fontSize(14)
          .height(40)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .borderRadius(8)
          .onClick(() => {
            this.nextPage()
          })
      }
      .enabled(this.pdfLoaded)
      .opacity(this.pdfLoaded ? 1 : 0.4)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  ToolbarRow() {
    Row({ space: 10 }) {
      Text(this.showSearch ? '✕搜索' : '🔍搜索')
        .fontSize(13)
        .fontColor(this.showSearch ? '#D94444' : '#4A90D9')
        .onClick(() => {
          if (this.showSearch) {
            this.clearPdfSearch()
          }
          this.showSearch = !this.showSearch
        })

      Row({ space: 6 }) {
        this.AnnotToolChip('高亮', 0)
        this.AnnotToolChip('下划线', 1)
        this.AnnotToolChip('删除线', 2)
      }

      Row({ space: 4 }) {
        ForEach(ANNOT_COLORS, (color: number, index: number) => {
          Row()
            .width(18)
            .height(18)
            .borderRadius(9)
            .backgroundColor(color)
            .border({
              width: this.annotColorIndex === index ? 2 : 0,
              color: '#333333',
              style: BorderStyle.Solid
            })
            .onClick(() => {
              this.annotColorIndex = index
              if (this.annotMode >= 0) {
                this.enableCurrentAnnotation()
              }
            })
        }, (color: number) => `${color}`)
      }

      if (this.annotMode >= 0) {
        Text('取消标注')
          .fontSize(13)
          .fontColor('#D94444')
          .onClick(() => {
            this.disableAnnotation()
          })
      }

      if (this.hasUnsavedAnnotations) {
        Text('保存')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#44B949')
          .borderRadius(8)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .onClick(() => {
            this.saveAnnotations()
          })
      }

      Text('批注')
        .fontSize(13)
        .fontColor('#4A90D9')
        .onClick(() => {
          this.openNotesSheet()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .backgroundColor(Color.White)
  }

  @Builder
  AnnotToolChip(label: string, mode: number) {
    Text(label)
      .fontSize(13)
      .fontColor(this.annotMode === mode ? Color.White : '#4A90D9')
      .backgroundColor(this.annotMode === mode ? '#4A90D9' : '#E8F0FE')
      .borderRadius(8)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .onClick(() => {
        if (this.annotMode === mode) {
          this.disableAnnotation()
        } else {
          this.annotMode = mode
          this.enableCurrentAnnotation()
        }
      })
  }

  @Builder
  SearchRow() {
    Row({ space: 8 }) {
      TextInput({ placeholder: '在本文档中搜索', text: this.searchText })
        .layoutWeight(1)
        .height(36)
        .fontSize(13)
        .backgroundColor('#F0F0F0')
        .onChange((value: string) => {
          this.searchText = value
        })
        .onSubmit(() => {
          this.doPdfSearch()
        })

      if (this.searchTotal > 0) {
        Text(`${this.searchIndex + 1}/${this.searchTotal}`)
          .fontSize(12)
          .fontColor('#666666')
        Text('↑')
          .fontSize(16)
          .fontColor('#4A90D9')
          .onClick(() => {
            this.jumpSearchHit(this.searchIndex - 1)
          })
        Text('↓')
          .fontSize(16)
          .fontColor('#4A90D9')
          .onClick(() => {
            this.jumpSearchHit(this.searchIndex + 1)
          })
      }

      Button('搜索')
        .fontSize(13)
        .height(36)
        .backgroundColor('#4A90D9')
        .borderRadius(8)
        .onClick(() => {
          this.doPdfSearch()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .backgroundColor(Color.White)
  }

  @Builder
  NotesSheetBuilder() {
    Column({ space: 8 }) {
      Text('批注笔记')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .padding({ top: 8 })

      if (this.readerNotes.length === 0) {
        Text('暂无批注笔记')
          .fontSize(13)
          .fontColor('#999999')
          .padding(8)
      } else {
        List({ space: 6 }) {
          ForEach(this.readerNotes, (note: ReaderNote) => {
            ListItem() {
              Row({ space: 8 }) {
                Text(`第${note.page}页`)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .backgroundColor('#4A90D9')
                  .borderRadius(8)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                Text(note.content)
                  .fontSize(13)
                  .fontColor('#444444')
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => {
                    this.notesSheetVisible = false
                    this.pdfController.goToPage(note.page - 1)
                  })
                Text('删除')
                  .fontSize(12)
                  .fontColor('#D94444')
                  .onClick(() => {
                    this.deleteReaderNote(note)
                  })
              }
              .width('100%')
              .padding(8)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
            }
          }, (note: ReaderNote) => `${note.id}`)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      Row({ space: 8 }) {
        Text(`第${this.currentPage}页`)
          .fontSize(13)
          .fontColor('#666666')
        TextArea({ placeholder: '记录当前页的批注或想法', text: this.newNoteText })
          .layoutWeight(1)
          .height(56)
          .fontSize(13)
          .backgroundColor('#F0F0F0')
          .onChange((value: string) => {
            this.newNoteText = value
          })
        Button('添加')
          .fontSize(13)
          .height(36)
          .backgroundColor('#4A90D9')
          .borderRadius(8)
          .enabled(this.newNoteText.trim().length > 0)
          .onClick(() => {
            this.addReaderNote()
          })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
  }

  private async loadPdf(): Promise<void> {
    try {
      const initPage = this.initialPage > 1 ? this.initialPage - 1 : undefined
      const result = await this.pdfController.loadDocument(this.pdfPath, undefined, initPage)
      if (result !== pdfService.ParseResult.PARSE_SUCCESS) {
        this.errorMessage = `文档解析失败 (code ${result})`
        hilog.error(DOMAIN, TAG, `Load PDF failed: ${result}`)
        return
      }
      this.totalPages = this.pdfController.getPageCount()
      this.currentPage = this.pdfController.getPageIndex() + 1
      this.lastReportedPage = this.currentPage
      this.pdfLoaded = true
      this.pdfController.registerPageChangedListener((pageIndex: number) => {
        this.currentPage = pageIndex + 1
        this.lastReportedPage = this.currentPage
        this.saveProgress(this.currentPage)
      })
      this.pdfController.registerAnnotationChangedListener((_param: pdfViewManager.AnnotationChangedParam) => {
        if (_param.controlType === pdfViewManager.AnnotationEditType.ADD ||
          _param.controlType === pdfViewManager.AnnotationEditType.MODIFY) {
          this.hasUnsavedAnnotations = true
        }
      })
      this.pdfController.registerAnnotationSelectedListener((selected: pdfViewManager.SelectedAnnotation) => {
        this.getUIContext().showAlertDialog({
          title: '删除标注',
          message: '是否删除选中的标注？',
          primaryButton: {
            value: '删除',
            fontColor: '#D94444',
            action: () => {
              this.pdfController.deleteSelectedAnnotation(selected.annotationIndex, selected.pageIndex)
            }
          },
          secondaryButton: {
            value: '取消',
            action: () => {}
          }
        })
      })
      this.saveProgress(this.currentPage)
    } catch (e) {
      this.errorMessage = (e as Error).message
      hilog.error(DOMAIN, TAG, `Load PDF failed: ${this.errorMessage}`)
    }
  }

  private enableCurrentAnnotation(): void {
    const color = ANNOT_COLORS[this.annotColorIndex]
    if (this.annotMode === 0) {
      this.pdfController.enableAnnotation(pdfViewManager.SupportedAnnotationType.HIGHLIGHT, color)
    } else if (this.annotMode === 1) {
      this.pdfController.enableAnnotation(pdfViewManager.SupportedAnnotationType.UNDERLINE, color)
    } else if (this.annotMode === 2) {
      this.pdfController.enableAnnotation(pdfViewManager.SupportedAnnotationType.STRIKETHROUGH, color)
    }
  }

  private disableAnnotation(): void {
    this.annotMode = -1
    try {
      this.pdfController.disableAnnotation()
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Disable annotation failed: ${(e as Error).message}`)
    }
  }

  private async saveAnnotations(): Promise<void> {
    const tmpPath = `${this.pdfPath}.tmp.pdf`
    try {
      await this.pdfController.saveDocument(tmpPath)
      fs.copyFileSync(tmpPath, this.pdfPath)
      fs.unlinkSync(tmpPath)
      this.hasUnsavedAnnotations = false
      this.getUIContext().getPromptAction().showToast({ message: '标注已保存' })
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Save annotations failed: ${(e as Error).message}`)
      this.getUIContext().getPromptAction().showToast({ message: '标注保存失败' })
    }
  }

  private async openNotesSheet(): Promise<void> {
    if (this.paperId > 0) {
      this.readerNotes = await this.paperService.getReaderNotes(this.paperId)
    }
    this.notesSheetVisible = true
  }

  private async addReaderNote(): Promise<void> {
    const content = this.newNoteText.trim()
    if (content.length === 0 || this.paperId <= 0) {
      return
    }
    const note = ReaderNote.create(this.paperId, this.currentPage, content)
    await this.paperService.addReaderNote(note)
    this.newNoteText = ''
    this.readerNotes = await this.paperService.getReaderNotes(this.paperId)
  }

  private async deleteReaderNote(note: ReaderNote): Promise<void> {
    await this.paperService.deleteReaderNote(note.id)
    this.readerNotes = await this.paperService.getReaderNotes(this.paperId)
  }

  private doPdfSearch(): void {
    const query = this.searchText.trim()
    if (query.length === 0) {
      return
    }
    try {
      this.pdfController.searchKey(query, (total: number) => {
        this.searchTotal = total
        if (total > 0) {
          this.searchIndex = 0
          this.pdfController.setSearchIndex(0)
        }
      })
    } catch (e) {
      hilog.error(DOMAIN, TAG, `PDF search failed: ${(e as Error).message}`)
    }
  }

  private clearPdfSearch(): void {
    try {
      this.pdfController.clearSearch()
    } catch (e) {
      // 忽略
    }
    this.searchTotal = 0
    this.searchIndex = 0
    this.searchText = ''
  }

  private jumpSearchHit(index: number): void {
    if (this.searchTotal <= 0) {
      return
    }
    let target = index
    if (target < 0) {
      target = this.searchTotal - 1
    }
    if (target >= this.searchTotal) {
      target = 0
    }
    this.searchIndex = target
    try {
      this.pdfController.setSearchIndex(target)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Set search index failed: ${(e as Error).message}`)
    }
  }

  private saveProgress(page: number): void {
    if (this.paperId <= 0 || this.totalPages <= 0) {
      return
    }
    const status = page >= this.totalPages ? ReadStatus.DONE : ReadStatus.READING
    this.paperService.updateReadingProgress(this.paperId, page, Date.now(), status)
  }

  private prevPage(): void {
    if (this.currentPage > 1) {
      this.pdfController.goToPage(this.currentPage - 2)
    }
  }

  private nextPage(): void {
    if (this.currentPage < this.totalPages) {
      this.pdfController.goToPage(this.currentPage)
    }
  }

  private zoomIn(): void {
    this.currentZoom = Math.min(this.currentZoom + 10, 300)
    this.pdfController.setPageZoom(this.currentZoom / 100)
  }

  private zoomOut(): void {
    this.currentZoom = Math.max(this.currentZoom - 10, 50)
    this.pdfController.setPageZoom(this.currentZoom / 100)
  }
}
