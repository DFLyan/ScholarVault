import { PaperService } from '../service/PaperService'
import { SyncService, ZoteroConfig } from '../service/SyncService'
import { DuplicateService } from '../service/DuplicateService'

// Zotero 账户同步面板：个人页与账户同步页共用
@Component
export struct ZoteroSyncPanel {
  @State zoteroUserId: string = ''
  @State zoteroApiKey: string = ''
  @State saving: boolean = false
  @State syncing: boolean = false
  @State syncResultText: string = ''
  @State syncErrorText: string = ''
  private paperService: PaperService = new PaperService()

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      return
    }
    const config = await SyncService.getZoteroConfig(context)
    this.zoteroUserId = config.userId
    this.zoteroApiKey = config.apiKey
  }

  build() {
    Column({ space: 16 }) {
      this.ZoteroSection()
      this.OtherProvidersSection()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ZoteroSection() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('🟡')
          .fontSize(20)
        Text('Zotero')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text('已连接')
          .fontSize(12)
          .fontColor(this.zoteroUserId.length > 0 ? '#44B949' : '#999999')
          .backgroundColor(this.zoteroUserId.length > 0 ? '#E8F7E8' : '#F0F0F0')
          .borderRadius(8)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')

      Column({ space: 4 }) {
        Text('用户 ID')
          .fontSize(13)
          .fontColor('#666666')
        TextInput({ placeholder: '如 12345678', text: this.zoteroUserId })
          .width('100%')
          .height(44)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .onChange((v: string) => {
            this.zoteroUserId = v.trim()
          })
      }
      .width('100%')

      Column({ space: 4 }) {
        Text('API Key')
          .fontSize(13)
          .fontColor('#666666')
        TextInput({ placeholder: '在 zotero.org/settings/keys 创建', text: this.zoteroApiKey })
          .width('100%')
          .height(44)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .onChange((v: string) => {
            this.zoteroApiKey = v.trim()
          })
      }
      .width('100%')

      Text('获取方式：登录 zotero.org → Settings → Feeds/API → 查看用户 ID；Settings → Create new private key，勾选 Allow library read 权限。')
        .fontSize(12)
        .fontColor('#999999')
        .lineHeight(18)
        .width('100%')

      Row({ space: 12 }) {
        Button(this.saving ? '保存中...' : '保存配置')
          .fontSize(14)
          .backgroundColor(Color.White)
          .fontColor('#4A90D9')
          .border({ width: 1, color: '#4A90D9', style: BorderStyle.Solid })
          .borderRadius(8)
          .layoutWeight(1)
          .enabled(!this.saving && !this.syncing && this.zoteroUserId.length > 0 && this.zoteroApiKey.length > 0)
          .onClick(() => {
            this.saveConfig()
          })

        Button(this.syncing ? '同步中...' : '立即同步')
          .fontSize(14)
          .backgroundColor('#4A90D9')
          .fontColor(Color.White)
          .borderRadius(8)
          .layoutWeight(1)
          .enabled(!this.syncing && this.zoteroUserId.length > 0 && this.zoteroApiKey.length > 0)
          .onClick(() => {
            this.startSync()
          })

        if (this.syncing) {
          LoadingProgress()
            .width(20)
            .height(20)
        }
      }
      .width('100%')

      if (this.syncResultText.length > 0) {
        Text(this.syncResultText)
          .fontSize(13)
          .fontColor('#44B949')
          .width('100%')
      }
      if (this.syncErrorText.length > 0) {
        Text(this.syncErrorText)
          .fontSize(13)
          .fontColor(Color.Red)
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  OtherProvidersSection() {
    Column({ space: 12 }) {
      Text('其他文献管理软件')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Row({ space: 10 }) {
        Text('🔵')
          .fontSize(18)
        Column({ space: 2 }) {
          Text('Mendeley')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
          Text('官方 API 需应用注册审核，暂未支持')
            .fontSize(12)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('暂不支持')
          .fontSize(12)
          .fontColor('#999999')
          .backgroundColor('#F0F0F0')
          .borderRadius(8)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Color.White)
      .borderRadius(10)

      Row({ space: 10 }) {
        Text('🟣')
          .fontSize(18)
        Column({ space: 2 }) {
          Text('EndNote')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
          Text('无公开云端 API，可通过导出 .ris 文件后在添加页导入')
            .fontSize(12)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text('暂不支持')
          .fontSize(12)
          .fontColor('#999999')
          .backgroundColor('#F0F0F0')
          .borderRadius(8)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Color.White)
      .borderRadius(10)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private async saveConfig(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.syncErrorText = '获取应用上下文失败'
      return
    }
    this.saving = true
    this.syncErrorText = ''
    const config = new ZoteroConfig()
    config.userId = this.zoteroUserId
    config.apiKey = this.zoteroApiKey
    const ok = await SyncService.saveZoteroConfig(context, config)
    this.saving = false
    if (ok) {
      this.syncResultText = '配置已保存'
      this.getUIContext().getPromptAction().showToast({ message: '配置已保存' })
    } else {
      this.syncErrorText = '保存配置失败，请重试'
    }
  }

  private async startSync(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.syncErrorText = '获取应用上下文失败'
      return
    }
    this.syncing = true
    this.syncResultText = ''
    this.syncErrorText = ''
    const config = new ZoteroConfig()
    config.userId = this.zoteroUserId
    config.apiKey = this.zoteroApiKey
    await SyncService.saveZoteroConfig(context, config)
    const fetched = await SyncService.fetchZoteroItems(config, 200)
    if (fetched.length === 0) {
      this.syncing = false
      this.syncErrorText = '未获取到文献，请检查用户 ID / API Key / 网络'
      return
    }
    const existing = await this.paperService.getAllPapers()
    let imported = 0
    let duplicates = 0
    for (let i = 0; i < fetched.length; i++) {
      const candidate = fetched[i]
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
      }
    }
    this.syncing = false
    this.syncResultText = `同步完成：共 ${fetched.length} 条，新增 ${imported} 篇，跳过重复 ${duplicates} 篇`
  }
}
