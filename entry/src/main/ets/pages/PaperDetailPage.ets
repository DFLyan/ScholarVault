import { Paper, ReadStatus, ReadStatusHelper } from '../model/PaperModel'
import { Category } from '../model/CategoryModel'
import { PaperNote } from '../model/NoteModel'
import { PaperService } from '../service/PaperService'
import { CategoryService } from '../service/CategoryService'
import { LatexLibraryService } from '../service/LatexLibraryService'
import { PaperDetailParams, PdfReaderParams, CitationExportParams, WebViewerParams } from '../model/RouteParams'
import { CitationFormat, CitationFormatHelper } from '../model/CitationStyle'
import { CitationService } from '../service/CitationService'
import { ScholarService, RelatedPaper } from '../service/ScholarService'
import { pasteboard } from '@kit.BasicServicesKit'
import { BusinessError } from '@kit.BasicServicesKit'

@Entry
@Component
struct PaperDetailPage {
  @State paper: Paper = new Paper()
  @State categories: Array<Category> = []
  @State citationText: string = ''
  @State currentFormat: CitationFormat = CitationFormat.BIBTEX
  @State editing: boolean = false
  @State editTitle: string = ''
  @State editAuthors: string = ''
  @State editYear: string = ''
  @State editJournal: string = ''
  @State editAbstract: string = ''
  @State editNotes: string = ''
  @State notes: Array<PaperNote> = []
  @State newNoteText: string = ''
  @State editingNoteId: number = -1
  @State editingNoteText: string = ''
  @State fetchingCitations: boolean = false
  @State fetchingRelated: boolean = false
  @State relatedPapers: Array<RelatedPaper> = []
  @State candidates: Array<RelatedPaper> = []
  @State showCandidates: boolean = false
  @State fetchingCandidates: boolean = false
  @State showCategorySheet: boolean = false
  @State allCategories: Array<Category> = []
  @State selectedCategoryIds: Array<number> = []
  private paperService: PaperService = new PaperService()
  private categoryService: CategoryService = new CategoryService()
  private paperId: number = 0

  async aboutToAppear(): Promise<void> {
    const params = this.getUIContext().getRouter().getParams() as PaperDetailParams
    this.paperId = params?.paperId ?? 0
    if (this.paperId > 0) {
      const paper = await this.paperService.getPaperById(this.paperId)
      if (paper !== undefined) {
        this.paper = paper
        this.editTitle = paper.title
        this.editAuthors = paper.getAuthorList().join(', ')
        this.editYear = paper.year > 0 ? `${paper.year}` : ''
        this.editJournal = paper.journal
        this.editAbstract = paper.abstract
        this.editNotes = paper.notes
      }
      this.categories = await this.paperService.getCategoriesForPaper(this.paperId)
      this.notes = await this.paperService.getNotesForPaper(this.paperId)
    }
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
        Text('论文详情')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        if (!this.editing) {
          Text('编辑')
            .fontSize(16)
            .fontColor('#4A90D9')
            .onClick(() => {
              this.editing = true
            })
        } else {
          Text('保存')
            .fontSize(16)
            .fontColor('#4A90D9')
            .onClick(() => {
              this.saveEdit()
            })
        }
      }
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.SpaceBetween)

      Scroll() {
        Column({ space: 16 }) {
          this.MetadataSection()
          this.StatusSection()
          this.NotesSection()
          this.CategoriesSection()
          this.CitationSection()
          this.RelatedSection()
          this.ActionsSection()
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .bindSheet($$this.showCandidates, this.CandidatesSheetBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      backgroundColor: Color.White,
      onDisappear: () => {
        this.showCandidates = false
      }
    })
  }

  @Builder
  CandidatesSheetBuilder() {
    Column({ space: 12 }) {
      Text('选择匹配的论文')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
      Text('点击搜索结果更新引用数并补全缺失信息（数据源：Semantic Scholar，Google Scholar 无公开 API）')
        .fontSize(12)
        .fontColor('#999999')
        .lineHeight(17)

      if (this.fetchingCandidates) {
        Column({ space: 8 }) {
          LoadingProgress()
            .width(32)
            .height(32)
          Text('正在搜索...')
            .fontSize(13)
            .fontColor('#999999')
        }
        .width('100%')
        .margin({ top: 24 })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.candidates, (candidate: RelatedPaper) => {
              Column({ space: 4 }) {
                Text(candidate.title)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                Row({ space: 8 }) {
                  if (candidate.year > 0) {
                    Text(`${candidate.year}`)
                      .fontSize(12)
                      .fontColor('#888888')
                  }
                  if (candidate.venue.length > 0) {
                    Text(candidate.venue)
                      .fontSize(12)
                      .fontColor('#888888')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  if (candidate.citationCount >= 0) {
                    Text(`被引 ${candidate.citationCount}`)
                      .fontSize(12)
                      .fontColor('#4A90D9')
                  }
                }
                .width('100%')
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#F8F8F8')
              .borderRadius(8)
              .onClick(() => {
                this.confirmApplyCandidate(candidate)
              })
            }, (candidate: RelatedPaper) => `${candidate.title}_${candidate.citationCount}`)

            Button('取消')
              .fontSize(14)
              .backgroundColor(Color.White)
              .fontColor('#666666')
              .borderRadius(8)
              .width('100%')
              .margin({ top: 4 })
              .onClick(() => {
                this.showCandidates = false
              })
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MetadataSection() {
    Column({ space: 12 }) {
      if (this.editing) {
        TextInput({ text: this.editTitle })
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(Color.White)
          .onChange((v: string) => { this.editTitle = v })

        TextInput({ text: this.editAuthors, placeholder: '作者' })
          .backgroundColor(Color.White)
          .onChange((v: string) => { this.editAuthors = v })

        TextInput({ text: this.editYear, placeholder: '年份' })
          .backgroundColor(Color.White)
          .type(InputType.Number)
          .onChange((v: string) => { this.editYear = v })

        TextInput({ text: this.editJournal, placeholder: '期刊' })
          .backgroundColor(Color.White)
          .onChange((v: string) => { this.editJournal = v })

        TextArea({ text: this.editAbstract, placeholder: '摘要' })
          .height(100)
          .backgroundColor(Color.White)
          .onChange((v: string) => { this.editAbstract = v })

        TextArea({ text: this.editNotes, placeholder: '笔记' })
          .height(80)
          .backgroundColor(Color.White)
          .onChange((v: string) => { this.editNotes = v })
      } else {
        Text(this.paper.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        Text(this.paper.getAuthorList().join(', '))
          .fontSize(15)
          .fontColor('#444444')
          .width('100%')

        Row({ space: 12 }) {
          if (this.paper.year > 0) {
            Text(`${this.paper.year}`)
              .fontSize(14)
              .fontColor('#666666')
          }
          if (this.paper.journal.length > 0) {
            Text(this.paper.journal)
              .fontSize(14)
              .fontColor('#666666')
          }
          if (this.paper.doi.length > 0) {
            Text(`DOI: ${this.paper.doi}`)
              .fontSize(13)
              .fontColor('#4A90D9')
              .decoration({ type: TextDecorationType.Underline })
              .onClick(() => {
                this.openWebViewer(`https://doi.org/${this.paper.doi}`, this.paper.title)
              })
          }
          if (this.paper.arxivId.length > 0) {
            Text(`arXiv: ${this.paper.arxivId}`)
              .fontSize(13)
              .fontColor('#4A90D9')
              .decoration({ type: TextDecorationType.Underline })
              .onClick(() => {
                this.openWebViewer(`https://arxiv.org/abs/${this.paper.arxivId}`, this.paper.title)
              })
          }
        }
        .width('100%')

        if (this.paper.abstract.length > 0) {
          Column({ space: 4 }) {
            Text('摘要')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text(this.paper.abstract)
              .fontSize(14)
              .fontColor('#555555')
              .lineHeight(22)
          }
          .width('100%')
        }

        if (this.paper.notes.length > 0) {
          Column({ space: 4 }) {
            Text('总笔记')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text(this.paper.notes)
              .fontSize(14)
              .fontColor('#555555')
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  StatusSection() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        ForEach([ReadStatus.UNREAD, ReadStatus.READING, ReadStatus.DONE], (status: ReadStatus) => {
          Text(ReadStatusHelper.getLabel(status))
            .fontSize(13)
            .fontColor(this.paper.readStatus === status ? Color.White : ReadStatusHelper.getColor(status))
            .backgroundColor(this.paper.readStatus === status ? ReadStatusHelper.getColor(status) : '#F0F0F0')
            .borderRadius(10)
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .onClick(() => {
              this.setReadStatus(status)
            })
        }, (status: ReadStatus) => `${status}`)

        Row({ space: 2 }) {
          ForEach([1, 2, 3, 4, 5], (star: number) => {
            Text(this.paper.rating >= star ? '★' : '☆')
              .fontSize(20)
              .fontColor(this.paper.rating >= star ? '#E8913D' : '#BBBBBB')
              .onClick(() => {
                this.setRating(this.paper.rating === star ? 0 : star)
              })
          }, (star: number) => `${star}`)
        }
        .margin({ left: 8 })
      }
      .width('100%')

      Row({ space: 16 }) {
        Text(this.paper.isFavorite > 0 ? '★ 已收藏' : '☆ 收藏')
          .fontSize(14)
          .fontColor(this.paper.isFavorite > 0 ? '#E8913D' : '#666666')
          .onClick(() => {
            this.toggleFavorite()
          })

        Text(this.paper.isPinned > 0 ? '📌 已置顶' : '📍 置顶')
          .fontSize(14)
          .fontColor(this.paper.isPinned > 0 ? '#4A90D9' : '#666666')
          .onClick(() => {
            this.togglePinned()
          })

        if (this.paper.lastReadPage > 0) {
          Text(`已读到第 ${this.paper.lastReadPage} 页`)
            .fontSize(14)
            .fontColor('#666666')
        }

        Row({ space: 4 }) {
          Text(this.paper.citationCount >= 0 ? `被引 ${this.paper.citationCount} 次` : '获取引用数')
            .fontSize(14)
            .fontColor(this.paper.citationCount >= 0 ? '#666666' : '#4A90D9')
          if (!this.fetchingCandidates) {
            Text('⟳')
              .fontSize(16)
              .fontColor('#4A90D9')
              .onClick(() => {
                this.openCandidateSheet()
              })
          } else {
            LoadingProgress()
              .width(16)
              .height(16)
          }
        }

        // Google Scholar 无公开 API，提供标题搜索入口手动核对引用信息
        Text('GS 搜索')
          .fontSize(13)
          .fontColor('#4A90D9')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor('#E8F0FE')
          .borderRadius(8)
          .onClick(() => {
            this.searchOnGoogleScholar()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  NotesSection() {
    Column({ space: 10 }) {
      Text('笔记')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)

      if (this.notes.length > 0) {
        ForEach(this.notes, (note: PaperNote) => {
          Column({ space: 6 }) {
            if (this.editingNoteId === note.id) {
              TextArea({ text: this.editingNoteText })
                .height(70)
                .fontSize(13)
                .backgroundColor('#F8F8F8')
                .onChange((v: string) => { this.editingNoteText = v })
              Row({ space: 12 }) {
                Text('保存修改')
                  .fontSize(13)
                  .fontColor('#44B949')
                  .onClick(() => {
                    this.saveNoteEdit(note)
                  })
                Text('取消')
                  .fontSize(13)
                  .fontColor('#999999')
                  .onClick(() => {
                    this.editingNoteId = -1
                    this.editingNoteText = ''
                  })
              }
            } else {
              Text(note.content)
                .fontSize(14)
                .fontColor('#444444')
                .width('100%')
              Row({ space: 12 }) {
                Text(this.formatTime(note.modifiedAt))
                  .fontSize(12)
                  .fontColor('#999999')
                  .layoutWeight(1)
                Text('编辑')
                  .fontSize(12)
                  .fontColor('#4A90D9')
                  .onClick(() => {
                    this.editingNoteId = note.id
                    this.editingNoteText = note.content
                  })
                Text('删除')
                  .fontSize(12)
                  .fontColor('#D94444')
                  .onClick(() => {
                    this.deleteNote(note)
                  })
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#F8F8F8')
          .borderRadius(8)
        }, (note: PaperNote) => `${note.id}`)
      } else {
        Text('暂无笔记，添加一条吧')
          .fontSize(13)
          .fontColor('#999999')
      }

      Row({ space: 8 }) {
        TextArea({ placeholder: '写笔记：摘录、想法、评论...', text: this.newNoteText })
          .layoutWeight(1)
          .height(60)
          .fontSize(13)
          .backgroundColor('#F0F0F0')
          .onChange((v: string) => { this.newNoteText = v })
        Button('添加')
          .fontSize(13)
          .height(36)
          .backgroundColor('#4A90D9')
          .borderRadius(8)
          .enabled(this.newNoteText.trim().length > 0)
          .onClick(() => {
            this.addNote()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CategoriesSection() {
    Column({ space: 8 }) {
      Row() {
        Text('分类标签')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Text('编辑')
          .fontSize(14)
          .fontColor('#4A90D9')
          .onClick(() => {
            this.openCategorySheet()
          })
      }
      .width('100%')

      if (this.categories.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.categories, (cat: Category) => {
            Text(cat.name)
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor(cat.color)
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          }, (cat: Category) => `${cat.id}`)
        }
      } else {
        Text('未分类')
          .fontSize(14)
          .fontColor('#999999')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
    .bindSheet($$this.showCategorySheet, this.CategorySheetBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      backgroundColor: Color.White,
      onDisappear: () => {
        this.showCategorySheet = false
      }
    })
  }

  @Builder
  CategorySheetBuilder() {
    Column({ space: 12 }) {
      Text('编辑分类')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
      Text('勾选要加入的标签或文件夹，取消勾选即移除')
        .fontSize(12)
        .fontColor('#999999')

      if (this.allCategories.length === 0) {
        Text('暂无可用分类，请先在分类管理中创建')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 16 })
      } else {
        Scroll() {
          Column({ space: 6 }) {
            ForEach(this.allCategories, (cat: Category) => {
              Row() {
                Checkbox()
                  .select(this.selectedCategoryIds.indexOf(cat.id) >= 0)
                  .selectedColor('#4A90D9')
                  .onChange((checked: boolean) => {
                    this.toggleCategorySelection(cat.id, checked)
                  })
                Text(cat.type === 'folder' ? '📁' : '🏷️')
                  .fontSize(16)
                  .margin({ left: 8, right: 8 })
                Text(cat.name)
                  .fontSize(14)
                  .layoutWeight(1)
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#F8F8F8')
              .borderRadius(8)
            }, (cat: Category) => `${cat.id}`)
          }
          .width('100%')
        }
        .layoutWeight(1)
      }

      Button('保存')
        .fontSize(14)
        .backgroundColor('#4A90D9')
        .fontColor(Color.White)
        .borderRadius(8)
        .width('100%')
        .onClick(() => {
          this.saveCategorySelection()
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CitationSection() {
    Column({ space: 8 }) {
      Row() {
        Text('引用格式')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)

        Row({ space: 4 }) {
          ForEach([CitationFormat.BIBTEX, CitationFormat.APA, CitationFormat.MLA, CitationFormat.RIS],
            (fmt: CitationFormat) => {
              Text(CitationFormatHelper.getLabel(fmt))
                .fontSize(12)
                .fontColor(this.currentFormat === fmt ? Color.White : '#4A90D9')
                .backgroundColor(this.currentFormat === fmt ? '#4A90D9' : '#E8F0FE')
                .borderRadius(8)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .onClick(() => {
                  this.currentFormat = fmt
                  this.updateCitation()
                })
            }, (fmt: CitationFormat) => `${fmt}`)
        }
      }
      .width('100%')

      Text(this.citationText)
        .fontSize(13)
        .fontColor('#444444')
        .fontFamily('monospace')
        .width('100%')
        .padding(12)
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .copyOption(CopyOptions.LocalDevice)

      Button('复制引用')
        .fontSize(14)
        .backgroundColor('#E8F0FE')
        .fontColor('#4A90D9')
        .borderRadius(8)
        .width('100%')
        .onClick(() => {
          this.copyCitation()
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RelatedSection() {
    Column({ space: 8 }) {
      Row() {
        Text('相关文献推荐')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)

        if (!this.fetchingRelated) {
          Text(this.relatedPapers.length > 0 ? '刷新' : '获取推荐')
            .fontSize(14)
            .fontColor('#4A90D9')
            .onClick(() => {
              this.fetchRelatedPapers()
            })
        } else {
          LoadingProgress()
            .width(18)
            .height(18)
        }
      }
      .width('100%')

      if (this.paper.doi.length === 0 && this.relatedPapers.length === 0) {
        Text('该论文缺少 DOI，无法获取推荐')
          .fontSize(13)
          .fontColor('#999999')
      } else if (this.relatedPapers.length === 0 && !this.fetchingRelated) {
        Text('点击右上角"获取推荐"，基于 Semantic Scholar 数据推荐相关文献')
          .fontSize(13)
          .fontColor('#999999')
      } else if (this.relatedPapers.length > 0) {
        ForEach(this.relatedPapers, (related: RelatedPaper) => {
          Column({ space: 3 }) {
            Text(related.title)
              .fontSize(14)
              .fontColor('#333333')
              .width('100%')
            Row({ space: 8 }) {
              if (related.year > 0) {
                Text(`${related.year}`)
                  .fontSize(12)
                  .fontColor('#888888')
              }
              if (related.venue.length > 0) {
                Text(related.venue)
                  .fontSize(12)
                  .fontColor('#888888')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              if (related.citationCount >= 0) {
                Text(`被引 ${related.citationCount}`)
                  .fontSize(12)
                  .fontColor('#888888')
              }
            }
            .width('100%')
          }
          .width('100%')
          .padding(8)
          .backgroundColor('#F8F8F8')
          .borderRadius(8)
        }, (related: RelatedPaper) => `${related.title}`)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionsSection() {
    Column({ space: 8 }) {
      if (this.paper.pdfPath.length > 0) {
        Button('打开 PDF')
          .fontSize(16)
          .backgroundColor('#4A90D9')
          .fontColor(Color.White)
          .borderRadius(8)
          .width('100%')
          .onClick(() => {
            this.openPdf(0)
          })

        if (this.paper.lastReadPage > 1) {
          Button(`继续阅读（第 ${this.paper.lastReadPage} 页）`)
            .fontSize(16)
            .backgroundColor('#44B949')
            .fontColor(Color.White)
            .borderRadius(8)
            .width('100%')
            .onClick(() => {
              this.openPdf(this.paper.lastReadPage)
            })
        }
      }

      Button('导出引用文件')
        .fontSize(16)
        .backgroundColor(Color.White)
        .fontColor('#4A90D9')
        .border({ width: 1, color: '#4A90D9', style: BorderStyle.Solid })
        .borderRadius(8)
        .width('100%')
        .onClick(() => {
          this.goToCitationExport()
        })

      Button('加入 LaTeX 文献库')
        .fontSize(16)
        .backgroundColor(Color.White)
        .fontColor('#44B949')
        .border({ width: 1, color: '#44B949', style: BorderStyle.Solid })
        .borderRadius(8)
        .width('100%')
        .onClick(() => {
          this.addToLatexLibrary()
        })

      Button('删除论文')
        .fontSize(16)
        .backgroundColor(Color.White)
        .fontColor('#D94444')
        .border({ width: 1, color: '#D94444', style: BorderStyle.Solid })
        .borderRadius(8)
        .width('100%')
        .onClick(() => {
          this.confirmDelete()
        })
    }
    .width('100%')
  }

  private formatTime(timestamp: number): string {
    if (timestamp <= 0) {
      return ''
    }
    const date = new Date(timestamp)
    const month = date.getMonth() + 1
    const day = date.getDate()
    return `${date.getFullYear()}-${month < 10 ? '0' : ''}${month}-${day < 10 ? '0' : ''}${day}`
  }

  private async setReadStatus(status: ReadStatus): Promise<void> {
    if (this.paper.readStatus === status) {
      return
    }
    this.paper.readStatus = status
    await this.paperService.updateReadStatus(this.paperId, status)
  }

  private async setRating(rating: number): Promise<void> {
    this.paper.rating = rating
    await this.paperService.updateRating(this.paperId, rating)
  }

  private async toggleFavorite(): Promise<void> {
    const newValue = this.paper.isFavorite > 0 ? 0 : 1
    this.paper.isFavorite = newValue
    await this.paperService.updateFavorite(this.paperId, newValue)
  }

  private async togglePinned(): Promise<void> {
    const newValue = this.paper.isPinned > 0 ? 0 : 1
    this.paper.isPinned = newValue
    await this.paperService.updatePinned(this.paperId, newValue)
  }

  private async fetchCitationCount(): Promise<void> {
    if (this.paper.doi.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '该论文缺少 DOI' })
      return
    }
    this.fetchingCitations = true
    const count = await ScholarService.fetchCitationCount(this.paper.doi)
    this.fetchingCitations = false
    if (count >= 0) {
      this.paper.citationCount = count
      await this.paperService.updateCitationCount(this.paperId, count)
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '获取引用数失败，请检查网络' })
    }
  }

  private async openCandidateSheet(): Promise<void> {
    if (this.fetchingCandidates) {
      return
    }
    this.fetchingCandidates = true
    this.candidates = await ScholarService.fetchPaperCandidates(this.paper.title, 8)
    this.fetchingCandidates = false
    if (this.candidates.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '未搜索到匹配结果，请稍后重试' })
      return
    }
    this.showCandidates = true
  }

  private confirmApplyCandidate(candidate: RelatedPaper): void {
    this.getUIContext().showAlertDialog({
      title: '确认更新',
      message: `使用「${candidate.title}」更新本论文的引用数${this.paper.doi.length === 0 && candidate.doi.length > 0 ? '并补全 DOI' : ''}？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认更新',
        fontColor: '#4A90D9',
        action: () => {
          this.applyCandidate(candidate)
        }
      }
    })
  }

  private async applyCandidate(candidate: RelatedPaper): Promise<void> {
    if (candidate.citationCount >= 0) {
      this.paper.citationCount = candidate.citationCount
      await this.paperService.updateCitationCount(this.paperId, candidate.citationCount)
    }
    if (this.paper.doi.length === 0 && candidate.doi.length > 0) {
      this.paper.doi = candidate.doi
    }
    if (this.paper.year <= 0 && candidate.year > 0) {
      this.paper.year = candidate.year
    }
    if (this.paper.journal.length === 0 && candidate.venue.length > 0) {
      this.paper.journal = candidate.venue
    }
    this.paper.dateModified = Date.now()
    await this.paperService.updatePaper(this.paper)
    this.updateCitation()
    this.showCandidates = false
    this.getUIContext().getPromptAction().showToast({ message: '论文信息已更新' })
  }

  private async fetchRelatedPapers(): Promise<void> {
    if (this.paper.doi.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '该论文缺少 DOI' })
      return
    }
    this.fetchingRelated = true
    this.relatedPapers = await ScholarService.fetchRelatedPapers(this.paper.doi, 8)
    this.fetchingRelated = false
    if (this.relatedPapers.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '未获取到推荐，请稍后重试' })
    }
  }

  private async addNote(): Promise<void> {
    const content = this.newNoteText.trim()
    if (content.length === 0) {
      return
    }
    const note = PaperNote.create(this.paperId, content)
    await this.paperService.addNote(note)
    this.newNoteText = ''
    this.notes = await this.paperService.getNotesForPaper(this.paperId)
  }

  private async saveNoteEdit(note: PaperNote): Promise<void> {
    if (this.editingNoteText.trim().length === 0) {
      return
    }
    note.content = this.editingNoteText.trim()
    await this.paperService.updateNote(note)
    this.editingNoteId = -1
    this.editingNoteText = ''
    this.notes = await this.paperService.getNotesForPaper(this.paperId)
  }

  private async deleteNote(note: PaperNote): Promise<void> {
    await this.paperService.deleteNote(note.id)
    this.notes = await this.paperService.getNotesForPaper(this.paperId)
  }

  private updateCitation(): void {
    this.citationText = CitationService.generateCitation(this.paper, this.currentFormat)
  }

  private copyCitation(): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.citationText)
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        this.getUIContext().getPromptAction().showToast({ message: '引用已复制到剪贴板' })
      })
      .catch((err: BusinessError) => {
        this.getUIContext().getPromptAction().showToast({ message: `复制失败: ${err.message}` })
      })
  }

  private openPdf(initialPage: number): void {
    const params: PdfReaderParams = {
      pdfPath: this.paper.pdfPath,
      paperTitle: this.paper.title,
      paperId: this.paper.id,
      initialPage: initialPage
    }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/PdfReaderPage', params: params })
  }

  private goToCitationExport(): void {
    const params: CitationExportParams = { paperId: this.paper.id }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CitationExportPage', params: params })
  }

  private openWebViewer(url: string, title: string): void {
    const params: WebViewerParams = { url: url, title: title }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/WebViewerPage', params: params })
  }

  // Google Scholar 标题搜索（无公开 API，跳转网页手动核对/下载）
  private searchOnGoogleScholar(): void {
    const query = encodeURIComponent(this.paper.title)
    this.openWebViewer(`https://scholar.google.com/scholar?hl=zh-CN&q=${query}`, 'Google Scholar')
  }

  private async openCategorySheet(): Promise<void> {
    this.allCategories = await this.categoryService.getAllCategories()
    const currentIds: Array<number> = []
    for (let i = 0; i < this.categories.length; i++) {
      currentIds.push(this.categories[i].id)
    }
    this.selectedCategoryIds = currentIds
    this.showCategorySheet = true
  }

  private toggleCategorySelection(categoryId: number, checked: boolean): void {
    const index = this.selectedCategoryIds.indexOf(categoryId)
    if (checked && index < 0) {
      this.selectedCategoryIds.push(categoryId)
    } else if (!checked && index >= 0) {
      this.selectedCategoryIds.splice(index, 1)
    }
  }

  private async saveCategorySelection(): Promise<void> {
    // 对比勾选结果与当前分类，做增量增删
    for (let i = 0; i < this.selectedCategoryIds.length; i++) {
      const cid = this.selectedCategoryIds[i]
      if (!this.categories.some((c: Category): boolean => c.id === cid)) {
        await this.paperService.addPaperToCategory(this.paperId, cid)
      }
    }
    for (let i = 0; i < this.categories.length; i++) {
      const cid = this.categories[i].id
      if (this.selectedCategoryIds.indexOf(cid) < 0) {
        await this.paperService.removePaperFromCategory(this.paperId, cid)
      }
    }
    this.categories = await this.paperService.getCategoriesForPaper(this.paperId)
    this.showCategorySheet = false
    this.getUIContext().getPromptAction().showToast({ message: '分类已更新' })
  }

  // 追加当前论文到应用内 LaTeX 文献库（references.bib，按 citeKey 去重）
  private addToLatexLibrary(): void {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '导出失败' })
      return
    }
    const single: Array<Paper> = [this.paper]
    const result = LatexLibraryService.appendPapers(context, single)
    if (result.added > 0) {
      this.getUIContext().getPromptAction().showToast({ message: '已加入 LaTeX 文献库' })
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '该论文已在 LaTeX 文献库中' })
    }
  }

  private async confirmDelete(): Promise<void> {
    this.getUIContext().showAlertDialog({
      title: '确认删除',
      message: '确定要删除这篇论文吗？此操作不可撤销。',
      primaryButton: {
        value: '删除',
        action: async () => {
          await this.paperService.deletePaper(this.paperId)
          this.getUIContext().getRouter().back()
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  private async saveEdit(): Promise<void> {
    this.editing = false
    this.paper.title = this.editTitle
    const authors = this.editAuthors.split(',').map((a: string) => a.trim()).filter((a: string) => a.length > 0)
    this.paper.authors = Paper.authorsToString(authors)
    const yearVal = parseInt(this.editYear, 10)
    this.paper.year = isNaN(yearVal) ? 0 : yearVal
    this.paper.journal = this.editJournal
    this.paper.abstract = this.editAbstract
    this.paper.notes = this.editNotes
    await this.paperService.updatePaper(this.paper)
    this.updateCitation()
  }
}
