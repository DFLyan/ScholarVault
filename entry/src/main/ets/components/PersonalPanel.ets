import { HuaweiAccountService, HuaweiLoginInfo } from '../service/HuaweiAccountService'
import { CloudBackupService } from '../service/CloudBackupService'
import { ZoteroSyncPanel } from './ZoteroSyncPanel'

// 个人页：华为账号登录、华为云空间备份同步、Zotero 等账户同步
@Component
export struct PersonalPanel {
  @State loginInfo: HuaweiLoginInfo = new HuaweiLoginInfo()
  @State loggingIn: boolean = false
  @State backingUp: boolean = false
  @State restoring: boolean = false
  @State lastBackupTime: number = 0
  @State cloudMessage: string = ''
  @State cloudError: string = ''

  async aboutToAppear(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      return
    }
    this.loginInfo = await HuaweiAccountService.getSavedLogin(context)
    this.lastBackupTime = await CloudBackupService.getLastBackupTime(context)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.ProfileCard()
        this.CloudSyncCard()
        ZoteroSyncPanel()
        this.AboutCard()
      }
      .padding(16)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  ProfileCard() {
    Column({ space: 12 }) {
      Row({ space: 14 }) {
        Text('👤')
          .fontSize(28)
          .width(60)
          .height(60)
          .textAlign(TextAlign.Center)
          .backgroundColor('#1A4A90D9')
          .borderRadius(30)
        Column({ space: 4 }) {
          Text(this.isLoggedIn() ? (this.loginInfo.nickname.length > 0 ? this.loginInfo.nickname : '华为账号用户') : '未登录')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Text(this.isLoggedIn() ? `UnionID: ${this.shortId(this.loginInfo.unionID)}` : '登录华为账号后可使用云空间同步')
            .fontSize(12)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.isLoggedIn()) {
          Button('退出登录')
            .fontSize(13)
            .backgroundColor(Color.White)
            .fontColor('#D94444')
            .border({ width: 1, color: '#D94444', style: BorderStyle.Solid })
            .borderRadius(14)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              this.logout()
            })
        } else {
          Button(this.loggingIn ? '登录中...' : '华为账号登录')
            .fontSize(13)
            .backgroundColor('#4A90D9')
            .fontColor(Color.White)
            .borderRadius(14)
            .padding({ left: 12, right: 12 })
            .enabled(!this.loggingIn)
            .onClick(() => {
              this.login()
            })
        }
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
  CloudSyncCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('☁️')
          .fontSize(20)
        Text('华为空间同步')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(this.isLoggedIn() ? '已登录' : '未登录')
          .fontSize(12)
          .fontColor(this.isLoggedIn() ? '#44B949' : '#999999')
          .backgroundColor(this.isLoggedIn() ? '#E8F7E8' : '#F0F0F0')
          .borderRadius(8)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .width('100%')

      Text('登录华为账号后，可将论文库数据库一键备份到华为云空间，或在换机/重装后从云端恢复。云端最多保留最近 5 份备份。')
        .fontSize(12)
        .fontColor('#999999')
        .lineHeight(18)
        .width('100%')

      if (this.lastBackupTime > 0) {
        Text(`上次备份：${this.formatTime(this.lastBackupTime)}`)
          .fontSize(13)
          .fontColor('#666666')
          .width('100%')
      }

      Row({ space: 12 }) {
        Button(this.backingUp ? '备份中...' : '立即备份到云空间')
          .fontSize(14)
          .backgroundColor('#4A90D9')
          .fontColor(Color.White)
          .borderRadius(8)
          .layoutWeight(1)
          .enabled(!this.backingUp && !this.restoring && this.isLoggedIn())
          .onClick(() => {
            this.backupNow()
          })

        Button(this.restoring ? '恢复中...' : '从云空间恢复')
          .fontSize(14)
          .backgroundColor(Color.White)
          .fontColor('#4A90D9')
          .border({ width: 1, color: '#4A90D9', style: BorderStyle.Solid })
          .borderRadius(8)
          .layoutWeight(1)
          .enabled(!this.backingUp && !this.restoring && this.isLoggedIn())
          .onClick(() => {
            this.confirmRestore()
          })

        if (this.backingUp || this.restoring) {
          LoadingProgress()
            .width(20)
            .height(20)
        }
      }
      .width('100%')

      if (this.cloudMessage.length > 0) {
        Text(this.cloudMessage)
          .fontSize(13)
          .fontColor('#44B949')
          .width('100%')
      }
      if (this.cloudError.length > 0) {
        Text(this.cloudError)
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
  AboutCard() {
    Column({ space: 8 }) {
      Row() {
        Text('关于')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text('v1.0.0')
          .fontSize(13)
          .fontColor('#999999')
      }
      .width('100%')
      Text('ScholarVault · 鸿蒙个人文献管理应用。数据存储在本机数据库，云备份依赖华为账号与 AGC 云空间服务。')
        .fontSize(12)
        .fontColor('#999999')
        .lineHeight(18)
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  private isLoggedIn(): boolean {
    return this.loginInfo.unionID.length > 0 || this.loginInfo.openID.length > 0
  }

  private shortId(id: string): string {
    if (id.length <= 10) {
      return id
    }
    return `${id.substring(0, 6)}...${id.substring(id.length - 4)}`
  }

  private async login(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      return
    }
    this.loggingIn = true
    try {
      this.loginInfo = await HuaweiAccountService.login(context)
      this.getUIContext().getPromptAction().showToast({
        message: this.loginInfo.nickname.length > 0 ? `欢迎，${this.loginInfo.nickname}` : '登录成功'
      })
    } catch (e) {
      this.getUIContext().showAlertDialog({
        title: '登录失败',
        message: (e as Error).message,
        autoCancel: true,
        alignment: DialogAlignment.Center,
        confirm: {
          value: '知道了',
          action: () => {}
        }
      })
    }
    this.loggingIn = false
  }

  private async logout(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      return
    }
    await HuaweiAccountService.logout(context)
    this.loginInfo = new HuaweiLoginInfo()
    this.cloudMessage = ''
    this.cloudError = ''
    this.getUIContext().getPromptAction().showToast({ message: '已退出登录' })
  }

  private async backupNow(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      return
    }
    this.backingUp = true
    this.cloudMessage = ''
    this.cloudError = ''
    try {
      await CloudBackupService.backupNow(context)
      this.lastBackupTime = Date.now()
      this.cloudMessage = `备份成功（${this.formatTime(this.lastBackupTime)}）`
    } catch (e) {
      this.cloudError = (e as Error).message
    }
    this.backingUp = false
  }

  private confirmRestore(): void {
    this.getUIContext().showAlertDialog({
      title: '从云空间恢复',
      message: '将用云端最近一次备份覆盖当前论文库数据，该操作不可撤销，确定继续吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '恢复',
        fontColor: '#D94444',
        action: () => {
          this.restoreNow()
        }
      }
    })
  }

  private async restoreNow(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      return
    }
    this.restoring = true
    this.cloudMessage = ''
    this.cloudError = ''
    try {
      const name = await CloudBackupService.restoreLatest(context)
      this.cloudMessage = `已从云端恢复（${name}），返回论文库刷新后生效`
    } catch (e) {
      this.cloudError = (e as Error).message
    }
    this.restoring = false
  }

  private formatTime(time: number): string {
    const d = new Date(time)
    const pad = (v: number): string => v < 10 ? `0${v}` : `${v}`
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ` +
      `${pad(d.getHours())}:${pad(d.getMinutes())}`
  }
}
