import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { Paper } from '../model/PaperModel'
import { PaperService } from '../service/PaperService'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'WebDownloadService'

export class WebDownloadService {
  private context: common.Context | undefined = undefined
  private delegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate()
  private delegateSet: boolean = false
  private targets: Map<string, string> = new Map<string, string>()
  private paperService: PaperService = new PaperService()
  private onPdfImported: () => void = () => {}

  constructor(context: common.Context | undefined, onPdfImported: () => void) {
    this.context = context
    this.onPdfImported = onPdfImported
    this.setupDelegate()
  }

  getDownloadDelegate(): webview.WebDownloadDelegate {
    return this.delegate
  }

  destroy(): void {
    this.targets.clear()
  }

  private setupDelegate(): void {
    this.delegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      hilog.info(DOMAIN, TAG, `Download triggered: ${item.getUrl()}`)
      const context = this.context
      if (context === undefined) {
        hilog.error(DOMAIN, TAG, 'Ability context is not available, cannot start download')
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
        this.targets.set(item.getGuid(), filePath)
        hilog.info(DOMAIN, TAG, `Download started to: ${filePath}`)
      } catch (startError) {
        hilog.error(DOMAIN, TAG, `Failed to start download: ${(startError as Error).message}`)
      }
    })

    this.delegate.onDownloadFinish((item: webview.WebDownloadItem) => {
      const guid = item.getGuid()
      const filePath = this.targets.get(guid)
      this.targets.delete(guid)
      if (filePath === undefined) {
        return
      }
      if (!filePath.toLowerCase().endsWith('.pdf')) {
        hilog.info(DOMAIN, TAG, `Download finished (not a PDF, skip import): ${filePath}`)
        return
      }
      hilog.info(DOMAIN, TAG, `Download finished, importing PDF into library: ${filePath}`)
      this.importDownloadedPaper(filePath)
    })

    this.delegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      this.targets.delete(item.getGuid())
      hilog.error(DOMAIN, TAG, `Download failed, guid: ${item.getGuid()}`)
    })
  }

  attachToController(controller: webview.WebviewController): void {
    this.retrySetDelegate(controller, 0)
  }

  private retrySetDelegate(controller: webview.WebviewController, attempt: number): void {
    const maxAttempts = 10  // 最多尝试10次
    const retryDelay = 500  // 每次重试延迟500ms

    if (this.delegateSet) {
      return
    }

    if (attempt >= maxAttempts) {
      hilog.warn(DOMAIN, TAG, 'Max retry attempts reached, giving up on setting download delegate')
      return
    }

    try {
      controller.setDownloadDelegate(this.delegate)
      this.delegateSet = true
      hilog.info(DOMAIN, TAG, `Download delegate successfully set on attempt ${attempt + 1}`)
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Failed to set download delegate on attempt ${attempt + 1}: ${(error as Error).message}`)
      setTimeout(() => {
        this.retrySetDelegate(controller, attempt + 1)
      }, retryDelay)
    }
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
      this.onPdfImported()
    } else {
      hilog.error(DOMAIN, TAG, `Failed to insert downloaded paper into library: ${filePath}`)
    }
  }
}
