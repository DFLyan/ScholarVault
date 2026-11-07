import { WebViewerParams } from '../model/RouteParams'
import { WebDownloadService } from '../service/WebDownloadService'
import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'

@Entry
@Component
struct WebViewerPage {
  @State url: string = ''
  @State title: string = '浏览器'
  private webController: webview.WebviewController = new webview.WebviewController()
  private downloadService: WebDownloadService | undefined = undefined

  async aboutToAppear(): Promise<void> {
    const params = this.getUIContext().getRouter().getParams() as WebViewerParams
    this.url = params?.url ?? ''
    this.title = params?.title ?? '浏览器'
    const context = this.getUIContext().getHostContext()
    if (context !== undefined) {
      this.downloadService = new WebDownloadService(context, () => {
        this.getUIContext().getPromptAction().showToast({ message: 'PDF 已下载并加入论文库' })
      })
    }
  }

  aboutToDisappear(): void {
    if (this.downloadService !== undefined) {
      this.downloadService.destroy()
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 8, right: 8 })
        Text('  ')
          .fontSize(22)
      }
      .width('100%')
      .padding(12)
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(Color.White)

      Web({ src: this.url, controller: this.webController })
        .layoutWeight(1)
        .width('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .databaseAccess(true)
        .geolocationAccess(false)
        .onAttach(() => {
          if (this.downloadService !== undefined) {
            setTimeout(() => {
              if (this.downloadService !== undefined) {
                this.downloadService.attachToController(this.webController)
              }
            }, 100)
          }
        })
        .onControllerAttached(() => {
          if (this.downloadService !== undefined) {
            this.downloadService.attachToController(this.webController)
          }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
