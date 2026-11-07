import { Paper, ReadStatus, ReadStatusHelper } from '../model/PaperModel'
import { Category } from '../model/CategoryModel'
import { PaperService } from '../service/PaperService'
import { CategoryService } from '../service/CategoryService'
import { FullTextSearchService, PdfSearchHit } from '../service/FullTextSearchService'
import { LatexLibraryService } from '../service/LatexLibraryService'
import { WebDownloadService } from '../service/WebDownloadService'
import { PaperCard } from '../components/PaperCard'
import { TagChip } from '../components/TagChip'
import { SearchBar } from '../components/SearchBar'
import { EmptyState } from '../components/EmptyState'
import { PaperDetailParams, PdfReaderParams } from '../model/RouteParams'
import { webview } from '@kit.ArkWeb'

const SORT_LABELS: Array<string> = ['最新添加', '年份', '标题', '最近阅读', '评分', '自定义']
const FILTER_LABELS: Array<string> = ['全部', '未读', '在读', '已读', '收藏']

@Entry
@Component
struct MainPage {
  @State currentTab: number = 0
  @State papers: Array<Paper> = []
  @State allPapers: Array<Paper> = []
  @State searchText: string = ''
  @State tags: Array<Category> = []
  @State folders: Array<Category> = []
  @State selectedTagId: number = -1
  @State selectedFolderId: number = -1
  @State urlInput: string = 'https://arxiv.org'
  @State sortMode: number = 0
  @State filterMode: number = 0
  @State searchingFulltext: boolean = false
  @State fulltextHits: Array<PdfSearchHit> = []
  @State selectionMode: boolean = false
  @State selectedIds: Array<number> = []
  private paperService: PaperService = new PaperService()
  private categoryService: CategoryService = new CategoryService()
  private webController: webview.WebviewController = new webview.WebviewController()
  private downloadService: WebDownloadService | undefined = undefined

  constructor() {
    super()
  }

  async aboutToAppear(): Promise<void> {
    // 下载委托提取到 WebDownloadService，页面仅负责刷新数据与提示
    const context = this.getUIContext().getHostContext()
    if (context !== undefined) {
      this.downloadService = new WebDownloadService(context, () => {
        this.getUIContext().getPromptAction().showToast({ message: 'PDF 已下载并加入论文库' })
        this.loadData()
      })
    }
  }

  onPageShow(): void {
    // 页面每次显示时刷新数据（含从添加页/详情页返回的场景）
    this.loadData()
  }

  aboutToDisappear(): void {
    if (this.downloadService !== undefined) {
      this.downloadService.destroy()
    }
  }

  async loadData(): Promise<void> {
    this.allPapers = await this.paperService.getAllPapers()
    this.tags = await this.categoryService.getTags()
    this.folders = await this.categoryService.getFolders()
    if (this.searchText.length > 0) {
      this.papers = await this.paperService.searchPapers(this.searchText)
    } else {
      this.applyFilters()
    }
  }

  private applyFilters(): void {
    let list = this.allPapers
    if (this.filterMode === 4) {
      list = list.filter((p: Paper): boolean => p.isFavorite > 0)
    } else if (this.filterMode >= 1 && this.filterMode <= 3) {
      const status = this.filterMode - 1
      list = list.filter((p: Paper): boolean => p.readStatus === status)
    }
    const sorted = list.slice()
    if (this.sortMode === 0) {
      sorted.sort((a: Paper, b: Paper): number => b.dateAdded - a.dateAdded)
    } else if (this.sortMode === 1) {
      sorted.sort((a: Paper, b: Paper): number => b.year - a.year)
    } else if (this.sortMode === 2) {
      sorted.sort((a: Paper, b: Paper): number => a.title.localeCompare(b.title))
    } else if (this.sortMode === 3) {
      sorted.sort((a: Paper, b: Paper): number => b.lastReadTime - a.lastReadTime)
    } else if (this.sortMode === 5) {
      sorted.sort((a: Paper, b: Paper): number => a.sortOrder - b.sortOrder)
    } else {
      sorted.sort((a: Paper, b: Paper): number => b.rating - a.rating)
    }
    if (this.sortMode === 5) {
      // 自定义顺序下不做置顶浮动，保证拖拽位置稳定
      this.papers = sorted
    } else {
      const pinned = sorted.filter((p: Paper): boolean => p.isPinned > 0)
      const normal = sorted.filter((p: Paper): boolean => p.isPinned === 0)
      this.papers = pinned.concat(normal)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() {
          this.LibraryTab()
        }

        TabContent() {
          this.CategoryTab()
        }

        TabContent() {
          this.SearchTab()
        }
      }
      .barHeight(0)
      .onChange((index: number) => {
        this.currentTab = index
      })
      .width('100%')
      .height('100%')

      this.DockBar()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  DockBar() {
    Row({ space: 4 }) {
      this.DockItem('📚', '论文库', 0)
      this.DockItem('🗂️', '分类', 1)
      this.DockItem('🌐', '搜索', 2)
    }
    .padding({ left: 6, right: 6, top: 6, bottom: 6 })
    .backgroundColor('#99FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thick)
    .borderRadius(28)
    .shadow({ radius: 20, color: '#26000000', offsetX: 0, offsetY: 4 })
    .margin({ left: 56, right: 56, bottom: 12 })
  }

  @Builder
  DockItem(icon: string, label: string, index: number) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(20)
      Text(label)
        .fontSize(10)
        .fontColor(this.currentTab === index ? '#4A90D9' : '#888888')
    }
    .padding({ left: 14, right: 14, top: 7, bottom: 7 })
    .borderRadius(20)
    .backgroundColor(this.currentTab === index ? '#1A4A90D9' : Color.Transparent)
    .onClick(() => {
      this.currentTab = index
    })
  }

  @Builder
  LibraryTab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Text('论文库')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          Text(this.selectionMode ? '取消' : '选择')
            .fontSize(14)
            .fontColor(this.selectionMode ? '#D94444' : '#4A90D9')
            .onClick(() => {
              this.toggleSelectionMode()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })

        Row({ space: 8 }) {
          this.EntryChip('🔄 同步', (): void => {
            this.goToSync()
          })
          this.EntryChip('🔍 查重', (): void => {
            this.goToDuplicates()
          })
          this.EntryChip('📊 统计', (): void => {
            this.goToStatistics()
          })
          this.EntryChip('📄 文档扫描', (): void => {
            this.goToDocumentScan()
          })
          this.EntryChip('📑 BibTeX库', (): void => {
            this.goToCitationExport()
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })

        SearchBar({
          onSearch: (query: string) => {
            this.onSearch(query)
          },
          onTextChange: (text: string) => {
            this.searchText = text
          }
        })

        if (this.searchText.length === 0) {
          this.FilterSortRow()
        }

        if (this.papers.length === 0) {
          Column() {
            EmptyState({ icon: '📚', message: '暂无论文', subMessage: '点击右下角 + 添加论文' })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.selectionMode) {
          List({ space: 8 }) {
            ForEach(this.papers, (paper: Paper) => {
              this.SelectablePaperListItem(paper)
            }, (paper: Paper) => `${paper.id}`)
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        } else if (this.isDraggable()) {
          List({ space: 8 }) {
            ForEach(this.papers, (paper: Paper) => {
              this.PaperListItem(paper)
            }, (paper: Paper) => `${paper.id}`)
              .onMove((from: number, to: number) => {
                const moved = this.papers.splice(from, 1)
                this.papers.splice(to, 0, moved[0])
                this.persistSortOrder()
              })
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 8, bottom: 120 })
        } else {
          List({ space: 8 }) {
            ForEach(this.papers, (paper: Paper) => {
              this.PaperListItem(paper)
            }, (paper: Paper) => `${paper.id}`)
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 8, bottom: 120 })
        }

        if (this.searchingFulltext || this.fulltextHits.length > 0) {
          this.FulltextHitsSection()
        }

        // 批量操作栏（选择模式下显示在列表底部，含 BibTeX 导出）
        if (this.selectionMode) {
          Row({ space: 10 }) {
            Text(`已选 ${this.selectedIds.length} 篇`)
              .fontSize(13)
              .fontColor('#333333')
            Text(this.selectedIds.length === this.papers.length && this.papers.length > 0 ? '取消全选' : '全选')
              .fontSize(14)
              .fontColor('#4A90D9')
              .onClick(() => {
                this.toggleAllSelection()
              })
            Text('BibTeX')
              .fontSize(13)
              .fontColor('#44B949')
              .onClick(() => {
                this.exportSelectedToLatex()
              })
            Button('删除')
              .fontSize(14)
              .backgroundColor('#D94444')
              .fontColor(Color.White)
              .borderRadius(8)
              .enabled(this.selectedIds.length > 0)
              .onClick(() => {
                this.confirmDeleteSelected()
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(Color.White)
          .borderRadius(16)
          .shadow({ radius: 12, color: '#1F000000', offsetY: -2 })
          .margin({ left: 16, right: 16, top: 4, bottom: 4 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // 右下角浮动按钮（Stack alignContent 定位，避让底部 dock）
      if (!this.selectionMode) {
        Button('+')
          .width(56)
          .height(56)
          .fontSize(24)
          .fontColor(Color.White)
          .backgroundColor('#4A90D9')
          .borderRadius(28)
          .margin({ right: 24, bottom: 104 })
          .onClick(() => {
            this.goToAddPaper()
          })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  EntryChip(label: string, onTap: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor('#4A90D9')
      .backgroundColor('#E8F0FE')
      .borderRadius(10)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .onClick(() => {
        onTap()
      })
  }

  @Builder
  PaperListItem(paper: Paper) {
    ListItem() {
      PaperCard({
        paper: paper,
        onCardClick: (paperId: number) => {
          this.goToPaperDetail(paperId)
        },
        onToggleFavorite: (paperId: number) => {
          this.toggleFavorite(paperId)
        },
        onTogglePin: (paperId: number) => {
          this.togglePin(paperId)
        }
      })
    }
    .swipeAction({ end: (): void => {
      this.SwipeDeleteBuilder(paper.id)
    } })
  }

  @Builder
  SelectablePaperListItem(paper: Paper) {
    ListItem() {
      PaperCard({
        paper: paper,
        selectable: true,
        selected: this.selectedIds.indexOf(paper.id) >= 0,
        onCardClick: (paperId: number) => {
          this.toggleSelected(paperId)
        },
        onToggleFavorite: (paperId: number) => {
          this.toggleFavorite(paperId)
        },
        onTogglePin: (paperId: number) => {
          this.togglePin(paperId)
        }
      })
    }
  }

  @Builder
  SwipeDeleteBuilder(paperId: number) {
    Button('删除')
      .fontSize(13)
      .backgroundColor('#D94444')
      .fontColor(Color.White)
      .borderRadius(8)
      .height(56)
      .margin({ left: 8 })
      .onClick(() => {
        const paper = this.papers.find((p: Paper): boolean => p.id === paperId)
        if (paper !== undefined) {
          this.confirmSwipeDelete(paper)
        }
      })
  }

  @Builder
  FilterSortRow() {
    Column({ space: 6 }) {
      Scroll() {
        Row({ space: 6 }) {
          ForEach(FILTER_LABELS, (label: string, index: number) => {
            Text(label)
              .fontSize(12)
              .fontColor(this.filterMode === index ? Color.White : '#4A90D9')
              .backgroundColor(this.filterMode === index ? '#4A90D9' : '#E8F0FE')
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .onClick(() => {
                this.filterMode = index
                this.applyFilters()
              })
          }, (label: string) => label)
        }
        .padding({ left: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      Scroll() {
        Row({ space: 6 }) {
          Text('排序:')
            .fontSize(12)
            .fontColor('#888888')
          ForEach(SORT_LABELS, (label: string, index: number) => {
            Text(label)
              .fontSize(12)
              .fontColor(this.sortMode === index ? Color.White : '#666666')
              .backgroundColor(this.sortMode === index ? '#666666' : '#F0F0F0')
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .onClick(() => {
                this.sortMode = index
                this.applyFilters()
              })
          }, (label: string) => label)
        }
        .padding({ left: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .padding({ top: 6, bottom: 4 })
    .width('100%')
  }

  @Builder
  FulltextHitsSection() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('PDF 全文命中')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        if (this.searchingFulltext) {
          LoadingProgress()
            .width(18)
            .height(18)
        }
      }
      .width('100%')

      ForEach(this.fulltextHits, (hit: PdfSearchHit) => {
        Column({ space: 3 }) {
          Row({ space: 8 }) {
            Text(hit.paperTitle)
              .fontSize(14)
              .fontColor('#333333')
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`第${hit.pageIndex}页`)
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor('#4A90D9')
              .borderRadius(8)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
          .width('100%')
          Text(hit.context)
            .fontSize(12)
            .fontColor('#777777')
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding(10)
        .backgroundColor(Color.White)
        .borderRadius(8)
        .onClick(() => {
          this.openReaderAtPage(hit)
        })
      }, (hit: PdfSearchHit) => `${hit.paperId}_${hit.pageIndex}_${hit.context.length}`)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 104 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  CategoryTab() {
    Column() {
      Row() {
        Text('分类')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text('管理')
          .fontSize(14)
          .fontColor('#4A90D9')
          .onClick(() => {
            this.goToCategoryManage()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      Text('文件夹')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 16, top: 16, bottom: 8 })

      if (this.folders.length === 0) {
        EmptyState({ icon: '📁', message: '暂无文件夹', subMessage: '在分类管理中创建' })
          .height(120)
      } else {
        List({ space: 4 }) {
          ForEach(this.folders, (folder: Category) => {
            ListItem() {
              Row() {
                Text('📁')
                  .fontSize(20)
                  .margin({ right: 8 })
                Text(folder.name)
                  .fontSize(15)
                  .layoutWeight(1)
                Text('⤓')
                  .fontSize(16)
                  .fontColor('#44B949')
                  .padding({ left: 8, right: 8 })
                  .onClick(() => {
                    this.exportCategoryToLatex(folder.id, folder.name)
                  })
                Text(`${folder.color}`)
                  .fontSize(12)
                  .fontColor('#999999')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .onClick(() => {
                this.filterByFolder(folder.id)
              })
            }
          }, (folder: Category) => `${folder.id}`)
        }
        .height(180)
        .padding({ left: 16, right: 16 })
      }

      Text('标签')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 16, top: 16, bottom: 8 })

      if (this.tags.length === 0) {
        EmptyState({ icon: '🏷️', message: '暂无标签', subMessage: '在分类管理中创建' })
          .height(120)
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tags, (tag: Category) => {
            TagChip({
              category: tag,
              selected: this.selectedTagId === tag.id,
              onTagClick: (categoryId: number) => {
                this.filterByTag(categoryId)
              }
            })
          }, (tag: Category) => `${tag.id}`)
        }
        .padding({ left: 16, right: 16 })
      }

      if (this.selectedFolderId >= 0 || this.selectedTagId >= 0) {
        Row() {
          Text('筛选结果')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          Text('导出BibTeX')
            .fontSize(14)
            .fontColor('#44B949')
            .margin({ right: 12 })
            .onClick(() => {
              this.exportFilteredToLatex()
            })
          Text('清除筛选')
            .fontSize(14)
            .fontColor('#4A90D9')
            .onClick(() => {
              this.selectedFolderId = -1
              this.selectedTagId = -1
              this.papers = this.allPapers
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })

        List({ space: 8 }) {
          ForEach(this.papers, (paper: Paper) => {
            this.PaperListItem(paper)
          }, (paper: Paper) => `${paper.id}`)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 104 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  SearchTab() {
    Column() {
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入网址', text: this.urlInput })
          .layoutWeight(1)
          .height(40)
          .borderRadius(8)
          .backgroundColor('#F0F0F0')
          .onChange((value: string) => {
            this.urlInput = value
          })
          .onSubmit(() => {
            this.loadUrl()
          })

        Button('前往')
          .height(40)
          .fontSize(14)
          .backgroundColor('#4A90D9')
          .borderRadius(8)
          .onClick(() => {
            this.loadUrl()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Row({ space: 8 }) {
        this.QuickLinkItem('arXiv', 'https://arxiv.org')
        this.QuickLinkItem('Semantic Scholar', 'https://www.semanticscholar.org')
        this.QuickLinkItem('Google Scholar', 'https://scholar.google.com')
        this.QuickLinkItem('CrossRef', 'https://search.crossref.org')
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Web({ src: this.urlInput, controller: this.webController })
        .layoutWeight(1)
        .width('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .databaseAccess(true)
        .geolocationAccess(false)
        .onAttach(() => {
          setTimeout(() => {
            if (this.downloadService !== undefined) {
              this.downloadService.attachToController(this.webController)
            }
          }, 100)
        })
        .onPageEnd(() => {
          const url = this.webController.getUrl()
          if (url !== undefined) {
            this.urlInput = url
          }
          if (this.downloadService !== undefined) {
            this.downloadService.attachToController(this.webController)
          }
        })
        .onControllerAttached(() => {
          if (this.downloadService !== undefined) {
            this.downloadService.attachToController(this.webController)
          }
        })


      Row({ space: 16 }) {
        Button('←')
          .fontSize(18)
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => {
            if (this.webController.accessBackward()) {
              this.webController.backward()
            }
          })
        Button('→')
          .fontSize(18)
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => {
            if (this.webController.accessForward()) {
              this.webController.forward()
            }
          })
        Button('↻')
          .fontSize(18)
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => {
            this.webController.refresh()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(8)
      .margin({ bottom: 84 })
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  QuickLinkItem(name: string, url: string) {
    Text(name)
      .fontSize(12)
      .fontColor('#4A90D9')
      .backgroundColor('#E8F0FE')
      .borderRadius(12)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .onClick(() => {
        this.urlInput = url
        this.loadUrl()
      })
  }

  private isDraggable(): boolean {
    return this.sortMode === 5 && this.filterMode === 0 &&
      this.searchText.length === 0 && !this.selectionMode
  }

  private toggleSelectionMode(): void {
    this.selectionMode = !this.selectionMode
    if (!this.selectionMode) {
      this.selectedIds = []
    }
  }

  private toggleSelected(paperId: number): void {
    const index = this.selectedIds.indexOf(paperId)
    if (index >= 0) {
      this.selectedIds.splice(index, 1)
    } else {
      this.selectedIds.push(paperId)
    }
  }

  private toggleAllSelection(): void {
    if (this.selectedIds.length === this.papers.length) {
      this.selectedIds = []
    } else {
      const ids: Array<number> = []
      for (let i = 0; i < this.papers.length; i++) {
        ids.push(this.papers[i].id)
      }
      this.selectedIds = ids
    }
  }

  private confirmDeleteSelected(): void {
    if (this.selectedIds.length === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '批量删除',
      message: `确定删除选中的 ${this.selectedIds.length} 篇论文吗？此操作不可撤销。`,
      primaryButton: {
        value: '删除',
        action: () => {
          this.deleteSelected()
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  // 批量选择 → 追加到 LaTeX 文献库（references.bib）
  private async exportSelectedToLatex(): Promise<void> {
    if (this.selectedIds.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '请先选择论文' })
      return
    }
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '导出失败' })
      return
    }
    const selected = this.allPapers.filter((p: Paper): boolean => this.selectedIds.indexOf(p.id) >= 0)
    const result = LatexLibraryService.appendPapers(context, selected)
    this.getUIContext().getPromptAction().showToast({
      message: `已加入 LaTeX 文献库：新增 ${result.added} 条${result.skipped > 0 ? `，跳过重复 ${result.skipped} 条` : ''}`
    })
  }

  // 文件夹整库导出 → 追加到 LaTeX 文献库
  private async exportCategoryToLatex(categoryId: number, categoryName: string): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '导出失败' })
      return
    }
    const papers = await this.paperService.getPapersByCategory(categoryId)
    if (papers.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '该分类暂无论文' })
      return
    }
    const result = LatexLibraryService.appendPapers(context, papers)
    this.getUIContext().getPromptAction().showToast({
      message: `「${categoryName}」已加入 LaTeX 文献库：新增 ${result.added} 条${result.skipped > 0 ? `，跳过重复 ${result.skipped} 条` : ''}`
    })
  }

  // 当前筛选结果导出 → 追加到 LaTeX 文献库
  private exportFilteredToLatex(): void {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.getUIContext().getPromptAction().showToast({ message: '导出失败' })
      return
    }
    if (this.papers.length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: '暂无可导出的论文' })
      return
    }
    const result = LatexLibraryService.appendPapers(context, this.papers)
    this.getUIContext().getPromptAction().showToast({
      message: `已加入 LaTeX 文献库：新增 ${result.added} 条${result.skipped > 0 ? `，跳过重复 ${result.skipped} 条` : ''}`
    })
  }

  private async deleteSelected(): Promise<void> {
    const ids = this.selectedIds.slice()
    for (let i = 0; i < ids.length; i++) {
      await this.paperService.deletePaper(ids[i])
    }
    this.selectedIds = []
    this.selectionMode = false
    await this.loadData()
    this.getUIContext().getPromptAction().showToast({ message: `已删除 ${ids.length} 篇论文` })
  }

  private confirmSwipeDelete(paper: Paper): void {
    this.getUIContext().showAlertDialog({
      title: '确认删除',
      message: `确定要删除「${paper.title}」吗？此操作不可撤销。`,
      primaryButton: {
        value: '删除',
        action: () => {
          this.deletePaperDirect(paper.id)
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  private async deletePaperDirect(paperId: number): Promise<void> {
    await this.paperService.deletePaper(paperId)
    await this.loadData()
    this.getUIContext().getPromptAction().showToast({ message: '论文已删除' })
  }

  private async persistSortOrder(): Promise<void> {
    for (let i = 0; i < this.papers.length; i++) {
      const paper = this.papers[i]
      if (paper.sortOrder !== i) {
        paper.sortOrder = i
        await this.paperService.updateSortOrder(paper.id, i)
      }
    }
    this.applyFilters()
  }

  private async onSearch(query: string): Promise<void> {
    this.searchText = query
    this.fulltextHits = []
    if (query.length === 0) {
      this.applyFilters()
      return
    }
    this.papers = await this.paperService.searchPapers(query)
    this.searchingFulltext = true
    try {
      const candidates = this.allPapers.filter((p: Paper): boolean => p.pdfPath.length > 0).slice(0, 30)
      this.fulltextHits = await FullTextSearchService.searchAllPapers(query, candidates, 3,
        (_done: number, _total: number) => {})
    } finally {
      this.searchingFulltext = false
    }
  }

  private async toggleFavorite(paperId: number): Promise<void> {
    const paper = this.allPapers.find((p: Paper): boolean => p.id === paperId)
    if (paper === undefined) {
      return
    }
    const newValue = paper.isFavorite > 0 ? 0 : 1
    paper.isFavorite = newValue
    await this.paperService.updateFavorite(paperId, newValue)
    this.applyFilters()
  }

  private async togglePin(paperId: number): Promise<void> {
    const paper = this.allPapers.find((p: Paper): boolean => p.id === paperId)
    if (paper === undefined) {
      return
    }
    const newValue = paper.isPinned > 0 ? 0 : 1
    paper.isPinned = newValue
    await this.paperService.updatePinned(paperId, newValue)
    this.applyFilters()
  }

  private openReaderAtPage(hit: PdfSearchHit): void {
    const params: PdfReaderParams = {
      pdfPath: hit.pdfPath,
      paperTitle: hit.paperTitle,
      paperId: hit.paperId,
      initialPage: hit.pageIndex
    }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/PdfReaderPage', params: params })
  }

  private async filterByTag(tagId: number): Promise<void> {
    if (this.selectedTagId === tagId) {
      this.selectedTagId = -1
      this.papers = this.allPapers
    } else {
      this.selectedTagId = tagId
      this.papers = await this.paperService.getPapersByCategory(tagId)
    }
  }

  private async filterByFolder(folderId: number): Promise<void> {
    if (this.selectedFolderId === folderId) {
      this.selectedFolderId = -1
      this.papers = this.allPapers
    } else {
      this.selectedFolderId = folderId
      this.papers = await this.paperService.getPapersByCategory(folderId)
    }
  }

  private goToPaperDetail(paperId: number): void {
    const params: PaperDetailParams = { paperId: paperId }
    this.getUIContext().getRouter().pushUrl({ url: 'pages/PaperDetailPage', params: params })
  }

  private goToAddPaper(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/AddPaperPage' })
  }

  private goToCategoryManage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CategoryManagePage' })
  }

  private goToDuplicates(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DuplicatesPage' })
  }

  private goToStatistics(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/StatisticsPage' })
  }

  private goToSync(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SyncSettingsPage' })
  }

  private goToDocumentScan(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DocumentScanPage' })
  }

  private goToCitationExport(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CitationExportPage' })
  }

  private loadUrl(): void {
    let url = this.urlInput
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://' + url
      this.urlInput = url
    }
    this.webController.loadUrl(url)
  }
}
