import { picker, fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { Paper } from '../model/PaperModel'
import { Category } from '../model/CategoryModel'
import { PaperService } from '../service/PaperService'
import { CategoryService } from '../service/CategoryService'
import { MetadataFetcher } from '../service/MetadataFetcher'
import { ImportExportService } from '../service/ImportExportService'
import { DuplicateService } from '../service/DuplicateService'
import { TagChip } from '../components/TagChip'

@Entry
@Component
struct AddPaperPage {
  @State inputMode: number = 0
  @State doiInput: string = ''
  @State arxivInput: string = ''
  @State fetching: boolean = false
  @State titleInput: string = ''
  @State authorsInput: string = ''
  @State yearInput: string = ''
  @State journalInput: string = ''
  @State abstractInput: string = ''
  @State keywordsInput: string = ''
  @State doiResult: string = ''
  @State arxivResult: string = ''
  @State pdfPath: string = ''
  @State tags: Array<Category> = []
  @State selectedTagIds: Array<number> = []
  @State errorMsg: string = ''
  @State pendingImports: Array<Paper> = []
  @State importFormat: string = ''
  @State importFileName: string = ''
  @State importing: boolean = false
  @State importResultText: string = ''
  private paperService: PaperService = new PaperService()
  private categoryService: CategoryService = new CategoryService()

  async aboutToAppear(): Promise<void> {
    this.tags = await this.categoryService.getTags()
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text('添加论文')
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

      Tabs({ index: this.inputMode }) {
        TabContent() {
          this.DOITab()
        }.tabBar('DOI/arXiv')

        TabContent() {
          this.ManualTab()
        }.tabBar('手动输入')

        TabContent() {
          this.ImportTab()
        }.tabBar('导入文件')
      }
      .onChange((index: number) => {
        this.inputMode = index
      })
      .layoutWeight(1)
      .width('100%')

      if (this.inputMode < 2) {
        Button('保存论文')
          .width('90%')
          .height(48)
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor('#4A90D9')
          .borderRadius(24)
          .margin({ top: 12, bottom: 24 })
          .onClick(() => {
            this.savePaper()
          })
      } else {
        Column()
          .height(24)
      }

      if (this.errorMsg.length > 0) {
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor(Color.Red)
          .padding({ bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  DOITab() {
    Scroll() {
      Column({ space: 12 }) {
        Text('通过标识符自动获取元数据')
          .fontSize(14)
          .fontColor('#666666')
          .padding({ top: 8 })

        TextInput({ placeholder: '输入 DOI，如 10.1000/xyz123', text: this.doiInput })
          .width('100%')
          .height(44)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .onChange((value: string) => {
            this.doiInput = value
          })

        Row() {
          Button('获取元数据')
            .fontSize(14)
            .backgroundColor('#4A90D9')
            .borderRadius(8)
            .enabled(!this.fetching && this.doiInput.length > 0)
            .onClick(() => {
              this.fetchDOI()
            })
          if (this.fetching) {
            LoadingProgress()
              .width(24)
              .height(24)
              .margin({ left: 8 })
          }
        }
        .width('100%')

        TextInput({ placeholder: '输入 arXiv ID，如 2301.00001', text: this.arxivInput })
          .width('100%')
          .height(44)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .onChange((value: string) => {
            this.arxivInput = value
          })

        Row() {
          Button('获取元数据')
            .fontSize(14)
            .backgroundColor('#4A90D9')
            .borderRadius(8)
            .enabled(!this.fetching && this.arxivInput.length > 0)
            .onClick(() => {
              this.fetchArxiv()
            })
          if (this.fetching) {
            LoadingProgress()
              .width(24)
              .height(24)
              .margin({ left: 8 })
          }
        }
        .width('100%')

        this.PdfImportSection()
        this.TagSelectionSection()
      }
      .padding(16)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  ManualTab() {
    Scroll() {
      Column({ space: 12 }) {
        Text('手动输入论文信息')
          .fontSize(14)
          .fontColor('#666666')
          .padding({ top: 8 })

        this.FormField('标题', this.titleInput, '输入论文标题', (v: string) => { this.titleInput = v })
        this.FormField('作者', this.authorsInput, '多作者用逗号分隔', (v: string) => { this.authorsInput = v })
        this.FormField('年份', this.yearInput, '如 2024', (v: string) => { this.yearInput = v })
        this.FormField('期刊/会议', this.journalInput, '输入期刊名', (v: string) => { this.journalInput = v })
        this.FormField('DOI', this.doiResult, '如 10.1000/xyz123', (v: string) => { this.doiResult = v })
        this.FormField('关键词', this.keywordsInput, '多关键词用逗号分隔', (v: string) => { this.keywordsInput = v })

        Column({ space: 4 }) {
          Text('摘要')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
          TextArea({ placeholder: '输入论文摘要', text: this.abstractInput })
            .width('100%')
            .height(100)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .onChange((value: string) => {
              this.abstractInput = value
            })
        }
        .width('100%')

        this.PdfImportSection()
        this.TagSelectionSection()
      }
      .padding(16)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  ImportTab() {
    Scroll() {
      Column({ space: 12 }) {
        Text('导入 BibTeX (.bib) 或 RIS (.ris) 文献库文件')
          .fontSize(14)
          .fontColor('#666666')
          .padding({ top: 8 })

        if (this.importFileName.length > 0) {
          Row({ space: 8 }) {
            Text('📄')
              .fontSize(18)
            Text(this.importFileName)
              .fontSize(13)
              .fontColor('#333333')
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.importFormat.toUpperCase())
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor('#4A90D9')
              .borderRadius(8)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(Color.White)
          .borderRadius(8)
        }

        Button('选择文件')
          .fontSize(14)
          .backgroundColor('#E8F0FE')
          .fontColor('#4A90D9')
          .borderRadius(8)
          .onClick(() => {
            this.pickImportFile()
          })

        if (this.pendingImports.length > 0) {
          Column({ space: 8 }) {
            Row() {
              Text(`共解析 ${this.pendingImports.length} 条文献`)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
            }
            .width('100%')

            ForEach(this.pendingImports, (paper: Paper, index: number) => {
              Row({ space: 8 }) {
                Text(`${index + 1}.`)
                  .fontSize(12)
                  .fontColor('#999999')
                Column({ space: 2 }) {
                  Text(paper.title)
                    .fontSize(13)
                    .fontColor('#333333')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (paper.year > 0) {
                    Text(`${paper.year}${paper.journal.length > 0 ? ' · ' + paper.journal : ''}`)
                      .fontSize(11)
                      .fontColor('#999999')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(10)
              .backgroundColor(Color.White)
              .borderRadius(8)
            }, (paper: Paper, index: number) => `${index}_${paper.title}`)

            Button(this.importing ? '导入中...' : '导入到论文库')
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor('#4A90D9')
              .borderRadius(8)
              .width('100%')
              .enabled(!this.importing)
              .onClick(() => {
                this.confirmImport()
              })
          }
          .width('100%')
        }

        if (this.importResultText.length > 0) {
          Text(this.importResultText)
            .fontSize(13)
            .fontColor('#4A90D9')
            .width('100%')
        }

        if (this.errorMsg.length > 0 && this.inputMode === 2) {
          Text(this.errorMsg)
            .fontSize(13)
            .fontColor(Color.Red)
            .width('100%')
        }
      }
      .padding(16)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  FormField(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
      TextInput({ placeholder: placeholder, text: value })
        .width('100%')
        .height(44)
        .backgroundColor(Color.White)
        .borderRadius(8)
        .onChange(onChange)
    }
    .width('100%')
  }

  @Builder
  PdfImportSection() {
    Column({ space: 8 }) {
      Text('PDF 文件')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)

      if (this.pdfPath.length > 0) {
        Text(this.pdfPath)
          .fontSize(12)
          .fontColor('#666666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Button('选择 PDF 文件')
        .fontSize(14)
        .backgroundColor('#E8F0FE')
        .fontColor('#4A90D9')
        .borderRadius(8)
        .onClick(() => {
          this.pickPdf()
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TagSelectionSection() {
    Column({ space: 8 }) {
      Text('标签')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)

      if (this.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tags, (tag: Category) => {
            TagChip({
              category: tag,
              selected: this.selectedTagIds.indexOf(tag.id) >= 0,
              onTagClick: (categoryId: number) => {
                this.toggleTag(categoryId)
              }
            })
          }, (tag: Category) => `${tag.id}`)
        }
      } else {
        Text('暂无标签，可在分类管理中创建')
          .fontSize(12)
          .fontColor('#999999')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private async fetchDOI(): Promise<void> {
    this.fetching = true
    this.errorMsg = ''
    const paper = await MetadataFetcher.fetchByDOI(this.doiInput)
    this.fetching = false
    if (paper !== undefined) {
      this.titleInput = paper.title
      this.authorsInput = paper.getAuthorList().join(', ')
      this.yearInput = paper.year > 0 ? `${paper.year}` : ''
      this.journalInput = paper.journal
      this.doiResult = paper.doi
      this.abstractInput = paper.abstract
      const kw = paper.getKeywordList()
      this.keywordsInput = kw.join(', ')
    } else {
      this.errorMsg = '无法获取 DOI 元数据，请检查 DOI 是否正确'
    }
  }

  private async fetchArxiv(): Promise<void> {
    this.fetching = true
    this.errorMsg = ''
    const paper = await MetadataFetcher.fetchByArxivId(this.arxivInput)
    this.fetching = false
    if (paper !== undefined) {
      this.titleInput = paper.title
      this.authorsInput = paper.getAuthorList().join(', ')
      this.yearInput = paper.year > 0 ? `${paper.year}` : ''
      this.journalInput = paper.journal
      this.arxivResult = paper.arxivId
      this.doiResult = paper.doi
      this.abstractInput = paper.abstract
      const kw = paper.getKeywordList()
      this.keywordsInput = kw.join(', ')
    } else {
      this.errorMsg = '无法获取 arXiv 元数据，请检查 ID 是否正确'
    }
  }

  private async pickPdf(): Promise<void> {
    try {
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = ['.pdf']
      options.maxSelectNumber = 1
      const docPicker = new picker.DocumentViewPicker()
      const uris: Array<string> = await docPicker.select(options)
      if (uris.length > 0) {
        const context = this.getUIContext().getHostContext()
        if (context === undefined) {
          this.errorMsg = '获取应用上下文失败'
          return
        }
        const papersDir = `${context.filesDir}/papers`
        if (!fs.accessSync(papersDir)) {
          fs.mkdirSync(papersDir, true)
        }
        const fileName = `paper_${Date.now()}.pdf`
        const destPath = `${papersDir}/${fileName}`
        fs.copyFileSync(uris[0], destPath)
        this.pdfPath = destPath
      }
    } catch (e) {
      this.errorMsg = '选择 PDF 文件失败'
    }
  }

  private toggleTag(tagId: number): void {
    const index = this.selectedTagIds.indexOf(tagId)
    if (index >= 0) {
      this.selectedTagIds.splice(index, 1)
    } else {
      this.selectedTagIds.push(tagId)
    }
  }

  private async savePaper(): Promise<void> {
    this.errorMsg = ''
    if (this.titleInput.length === 0) {
      this.errorMsg = '请输入论文标题'
      return
    }
    const doiToUse = this.doiResult.length > 0 ? this.doiResult : this.doiInput
    const existing = await this.paperService.getAllPapers()
    const dup = DuplicateService.findDuplicateOf(this.titleInput, doiToUse, existing)
    if (dup !== undefined) {
      this.getUIContext().showAlertDialog({
        title: '疑似重复论文',
        message: `论文库中可能已存在该文献：「${dup.title}」。是否仍要保存？`,
        autoCancel: true,
        alignment: DialogAlignment.Center,
        primaryButton: {
          value: '取消',
          action: () => {}
        },
        secondaryButton: {
          value: '仍要保存',
          fontColor: '#4A90D9',
          action: () => {
            this.doSavePaper()
          }
        }
      })
      return
    }
    await this.doSavePaper()
  }

  private async doSavePaper(): Promise<void> {
    this.errorMsg = ''
    if (this.titleInput.length === 0) {
      this.errorMsg = '请输入论文标题'
      return
    }
    const authors = this.authorsInput.split(',').map((a: string) => a.trim()).filter((a: string) => a.length > 0)
    const keywords = this.keywordsInput.split(',').map((k: string) => k.trim()).filter((k: string) => k.length > 0)
    const yearVal = parseInt(this.yearInput, 10)
    const paper = Paper.create(
      this.titleInput,
      Paper.authorsToString(authors),
      isNaN(yearVal) ? 0 : yearVal,
      this.journalInput,
      this.doiResult.length > 0 ? this.doiResult : this.doiInput,
      this.arxivInput.length > 0 ? this.arxivInput : this.arxivResult,
      this.abstractInput,
      Paper.keywordsToString(keywords),
      this.pdfPath
    )
    const paperId = await this.paperService.addPaper(paper)
    if (paperId > 0) {
      for (let i = 0; i < this.selectedTagIds.length; i++) {
        await this.paperService.addPaperToCategory(paperId, this.selectedTagIds[i])
      }
      this.getUIContext().getRouter().back()
    } else {
      this.errorMsg = '保存失败，请重试'
    }
  }

  private async pickImportFile(): Promise<void> {
    this.errorMsg = ''
    this.importResultText = ''
    try {
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = ['.bib', '.ris', '.txt']
      options.maxSelectNumber = 1
      const docPicker = new picker.DocumentViewPicker()
      const uris: Array<string> = await docPicker.select(options)
      if (uris.length === 0) {
        return
      }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY)
      const stat = fs.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.closeSync(file)
      const content = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf))
      const format = ImportExportService.detectFormat(content)
      if (format === 'unknown') {
        this.errorMsg = '无法识别文件格式，请选择 .bib 或 .ris 文件'
        this.pendingImports = []
        this.importFileName = ''
        this.importFormat = ''
        return
      }
      const parsed = format === 'bibtex'
        ? ImportExportService.parseBibTeX(content)
        : ImportExportService.parseRIS(content)
      if (parsed.length === 0) {
        this.errorMsg = '文件中未解析到有效文献条目'
        this.pendingImports = []
        this.importFileName = ''
        this.importFormat = ''
        return
      }
      const slashIndex = uris[0].lastIndexOf('/')
      this.importFileName = slashIndex >= 0 ? decodeURIComponent(uris[0].substring(slashIndex + 1)) : uris[0]
      this.importFormat = format
      this.pendingImports = parsed
    } catch (e) {
      this.errorMsg = '读取文件失败，请重试'
    }
  }

  private async confirmImport(): Promise<void> {
    if (this.pendingImports.length === 0 || this.importing) {
      return
    }
    this.importing = true
    this.importResultText = ''
    const existing = await this.paperService.getAllPapers()
    let imported = 0
    let duplicates = 0
    let failed = 0
    for (let i = 0; i < this.pendingImports.length; i++) {
      const candidate = this.pendingImports[i]
      const dup = DuplicateService.findDuplicateOf(candidate.title, candidate.doi, existing)
      if (dup !== undefined) {
        duplicates++
        continue
      }
      const paperId = await this.paperService.addPaper(candidate)
      if (paperId > 0) {
        imported++
        candidate.id = paperId
        existing.push(candidate)
      } else {
        failed++
      }
    }
    this.importing = false
    this.pendingImports = []
    this.importFileName = ''
    this.importFormat = ''
    this.importResultText = `导入完成：成功 ${imported} 篇，跳过重复 ${duplicates} 篇${failed > 0 ? `，失败 ${failed} 篇` : ''}`
  }
}
