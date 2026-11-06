import { Paper, ReadStatus, ReadStatusHelper } from '../model/PaperModel'
import { Category } from '../model/CategoryModel'
import { PaperService } from '../service/PaperService'
import { CategoryService } from '../service/CategoryService'
import { FullTextSearchService, PdfSearchHit } from '../service/FullTextSearchService'
import { PaperCard } from '../components/PaperCard'
import { TagChip } from '../components/TagChip'
import { SearchBar } from '../components/SearchBar'
import { EmptyState } from '../components/EmptyState'
import { PaperDetailParams, PdfReaderParams } from '../model/RouteParams'
import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'

const SORT_LABELS: Array<string> = ['最新添加', '年份', '标题', '最近阅读', '评分']
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
  private paperService: PaperService = new PaperService()
  private categoryService: CategoryService = new CategoryService()
  private webController: webview.WebviewController = new webview.WebviewController()
  private downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate()
  private downloadDelegateSet: boolean = false
  private abilityContext: common.Context | undefined = undefined
  private downloadTargets: Map<string, string> = new Map<string, string>()

  constructor() {
    super()
  }

  async aboutToAppear(): Promise<void> {
    // 预捕获应用上下文，供下载回调使用（回调内无法可靠调用 getContext()）
    this.abilityContext = this.getUIContext().getHostContext()
    this.setupDownloadDelegate()
  }

  onPageShow(): void {
    // 页面每次显示时刷新数据（含从添加页/详情页返回的场景）
    this.loadData()
  }

  aboutToDisappear(): void {
    this.downloadTargets.clear()
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
    } else {
      sorted.sort((a: Paper, b: Paper): number => b.rating - a.rating)
    }
    const pinned = sorted.filter((p: Paper): boolean => p.isPinned > 0)
    const normal = sorted.filter((p: Paper): boolean => p.isPinned === 0)
    this.papers = pinned.concat(normal)
  }

  private setupDownloadDelegate(): void {
    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      console.log('Download triggered:', item.getUrl())
      const context = this.abilityContext
      if (context === undefined) {
        console.error('Ability context is not available, cannot start download')
        return
      }

      // 下载到 filesDir/papers（持久目录，cacheDir 可能被系统清理）
      const papersDir = `${context.filesDir}/papers`
      if (!fs.accessSync(papersDir)) {
        fs.mkdirSync(papersDir, true)
      }

      let fileName = item.getSuggestedFileName()
      if (fileName.trim().length === 0) {
        fileName = this.extractFileNameFromUrl(item.getUrl())
      }
      if (fileName.length === 0) {
        fileName = `download_${Date.now()}.pdf`
      }
      // 防路径穿越，并加时间戳前缀避免重名覆盖
      fileName = fileName.replace(/[/\\]/g, '_')
      const filePath = `${papersDir}/${Date.now()}_${fileName}`

      try {
        item.start(filePath)
        this.downloadTargets.set(item.getGuid(), filePath)
        console.log('Download started to:', filePath)
      } catch (startError) {
        console.error('Failed to start download:', startError)
      }
    })

    this.downloadDelegate.onDownloadFinish((item: webview.WebDownloadItem) => {
      const guid = item.getGuid()
      const filePath = this.downloadTargets.get(guid)
      this.downloadTargets.delete(guid)
      if (filePath === undefined) {
        return
      }
      if (!filePath.toLowerCase().endsWith('.pdf')) {
        console.log('Download finished (not a PDF, skip import):', filePath)
        return
      }
      console.log('Download finished, importing PDF into library:', filePath)
      this.importDownloadedPaper(filePath)
    })

    this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      this.downloadTargets.delete(item.getGuid())
      console.error('Download failed, guid:', item.getGuid())
    })
  }

  private extractFileNameFromUrl(url: string): string {
    const pathStart = url.lastIndexOf('/')
    if (pathStart === -1) {
      return ''
    }
    let name = url.substring(pathStart + 1)
    const queryIndex = name.indexOf('?')
    if (queryIndex !== -1) {
      name = name.substring(0, queryIndex)
    }
    return name
  }

  private async importDownloadedPaper(filePath: string): Promise<void> {
    const slashIndex = filePath.lastIndexOf('/')
    const fullFileName = slashIndex >= 0 ? filePath.substring(slashIndex + 1) : filePath
    const dotIndex = fullFileName.lastIndexOf('.')
    const baseName = dotIndex > 0 ? fullFileName.substring(0, dotIndex) : fullFileName
    // 去掉时间戳前缀（第一个下划线前）并用空格还原文件名
    const noPrefix = baseName.indexOf('_') >= 0 ? baseName.substring(baseName.indexOf('_') + 1) : baseName
    const title = noPrefix.replace(/_/g, ' ').trim()
    const paper = Paper.create(
      title.length > 0 ? title : fullFileName,
      '[]',
      0,
      '',
      '',
      '',
      '',
      '[]',
      filePath
    )
    const paperId = await this.paperService.addPaper(paper)
    if (paperId > 0) {
      this.getUIContext().getPromptAction().showToast({ message: 'PDF 已下载并加入论文库' })
      this.loadData()
    } else {
      console.error('Failed to insert downloaded paper into library:', filePath)
    }
  }

  private retrySetDownloadDelegate(attempt: number): void {
    const maxAttempts = 10  // 最多尝试10次
    const retryDelay = 500  // 每次重试延迟500ms

    if (this.downloadDelegateSet) {
      console.log('Download delegate already set, stopping retry')
      return
    }

    if (attempt >= maxAttempts) {
      console.log('Max retry attempts reached, giving up on setting download delegate')
      return
    }

    console.log(`Attempt ${attempt + 1} to set download delegate...`)

    try {
      // 检查Web控制器是否已初始化
      if (this.webController) {
        // 尝试设置下载委托
        this.webController.setDownloadDelegate(this.downloadDelegate)
        this.downloadDelegateSet = true
        console.log(`Download delegate successfully set on attempt ${attempt + 1}`)
      } else {
        console.log(`Web controller not ready on attempt ${attempt + 1}, retrying in ${retryDelay}ms...`)
        // 继续重试
        setTimeout(() => {
          this.retrySetDownloadDelegate(attempt + 1)
        }, retryDelay)
      }
    } catch (error) {
      console.error(`Failed to set download delegate on attempt ${attempt + 1}:`, error)
      // 继续重试
      setTimeout(() => {
        this.retrySetDownloadDelegate(attempt + 1)
      }, retryDelay)
    }
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
      TabContent() {
        this.LibraryTab()
      }.tabBar('论文库')

      TabContent() {
        this.CategoryTab()
      }.tabBar('分类')

      TabContent() {
        this.SearchTab()
      }.tabBar('搜索')
    }
    .onChange((index: number) => {
      this.currentTab = index
    })
    .width('100%')
    .height('100%')
  }

  @Builder
  LibraryTab() {
    Stack() {
      Column() {
        Row() {
          Text('论文库')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
          Text('查重')
            .fontSize(14)
            .fontColor('#4A90D9')
            .onClick(() => {
              this.goToDuplicates()
            })
          Text('统计')
            .fontSize(14)
            .fontColor('#4A90D9')
            .margin({ left: 16 })
            .onClick(() => {
              this.goToStatistics()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })

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
        } else {
          List({ space: 8 }) {
            ForEach(this.papers, (paper: Paper) => {
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
            }, (paper: Paper) => `${paper.id}`)
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        }

        if (this.searchingFulltext || this.fulltextHits.length > 0) {
          this.FulltextHitsSection()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // 右下角浮动按钮
      Button('+')
        .width(56)
        .height(56)
        .fontSize(24)
        .fontColor(Color.White)
        .backgroundColor('#4A90D9')
        .borderRadius(28)
        .align(Alignment.BottomEnd)
        .offset({ x: -24, y: -24 })
        .onClick(() => {
          this.goToAddPaper()
        })
    }
    .width('100%')
    .height('100%')
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
    .padding({ left: 16, right: 16, top: 8, bottom: 72 })
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
          }, (paper: Paper) => `${paper.id}`)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
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
          console.log('Web component attached')
          // 组件附加后立即尝试设置下载委托
          setTimeout(() => {
            if (!this.downloadDelegateSet && this.webController) {
              console.log('Attempting to set download delegate in onAttach...')
              this.retrySetDownloadDelegate(0)
            }
          }, 100)
        })
        .onPageEnd(() => {
          const url = this.webController.getUrl()
          if (url !== undefined) {
            this.urlInput = url
          }

          console.log('Page loaded, checking download delegate...')
          // 页面加载完成后再次检查下载委托
          if (!this.downloadDelegateSet && this.webController) {
            console.log('Page loaded but download delegate not set, retrying...')
            this.retrySetDownloadDelegate(0)
          }
        })
        .onControllerAttached(() => {
          console.log('Web controller attached, attempting to set download delegate...')

          // 使用更可靠的重试机制设置下载委托
          this.retrySetDownloadDelegate(0)
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

  private loadUrl(): void {
    let url = this.urlInput
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://' + url
      this.urlInput = url
    }
    this.webController.loadUrl(url)
  }
}
