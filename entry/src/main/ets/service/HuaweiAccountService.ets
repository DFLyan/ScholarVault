import { authentication } from '@kit.AccountKit'
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'

const DOMAIN = 0x0000
const TAG = 'HuaweiAccount'
const PREF_NAME = 'scholarvault_account'

export class HuaweiLoginInfo {
  unionID: string = ''
  openID: string = ''
  nickname: string = ''
}

export class HuaweiAccountService {
  private static async getPrefs(context: common.Context): Promise<preferences.Preferences> {
    return await preferences.getPreferences(context, PREF_NAME)
  }

  // 华为账号授权登录：scopes 含 profile 时可返回昵称（需用户授权）
  static async login(context: common.Context): Promise<HuaweiLoginInfo> {
    if (!canIUse('SystemCapability.AuthenticationServices.HuaweiID.Auth')) {
      return Promise.reject(new Error('当前设备不支持华为账号服务'))
    }
    const provider = new authentication.HuaweiIDProvider()
    const request = provider.createAuthorizationWithHuaweiIDRequest()
    request.scopes = ['openid', 'profile']
    const controller = new authentication.AuthenticationController(context)
    try {
      const response =
        await controller.executeRequest(request) as authentication.AuthorizationWithHuaweiIDResponse
      const data = response.data
      if (data === undefined) {
        return Promise.reject(new Error('授权返回为空，请重试'))
      }
      const info = new HuaweiLoginInfo()
      info.unionID = data.unionID ?? ''
      info.openID = data.openID ?? ''
      info.nickname = data.nickName ?? ''
      if (info.unionID.length === 0 && info.openID.length === 0) {
        return Promise.reject(new Error('未获取到华为账号标识，请重试'))
      }
      await HuaweiAccountService.saveLogin(context, info)
      return info
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, `Huawei ID login failed: ${err.code} ${err.message}`)
      return Promise.reject(new Error(HuaweiAccountService.mapLoginError(err)))
    }
  }

  static async saveLogin(context: common.Context, info: HuaweiLoginInfo): Promise<void> {
    const prefs = await HuaweiAccountService.getPrefs(context)
    prefs.putSync('hw_union_id', info.unionID)
    prefs.putSync('hw_open_id', info.openID)
    prefs.putSync('hw_nickname', info.nickname)
    await prefs.flush()
  }

  static async getSavedLogin(context: common.Context): Promise<HuaweiLoginInfo> {
    const info = new HuaweiLoginInfo()
    try {
      const prefs = await HuaweiAccountService.getPrefs(context)
      info.unionID = prefs.getSync('hw_union_id', '') as string
      info.openID = prefs.getSync('hw_open_id', '') as string
      info.nickname = prefs.getSync('hw_nickname', '') as string
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Read saved login failed: ${(e as Error).message}`)
    }
    return info
  }

  static async logout(context: common.Context): Promise<void> {
    // 清除本地登录态；同时尝试取消华为账号授权（失败不影响退出）
    try {
      const prefs = await HuaweiAccountService.getPrefs(context)
      prefs.deleteSync('hw_union_id')
      prefs.deleteSync('hw_open_id')
      prefs.deleteSync('hw_nickname')
      await prefs.flush()
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Clear login failed: ${(e as Error).message}`)
    }
    try {
      const provider = new authentication.HuaweiIDProvider()
      const request = provider.createCancelAuthorizationRequest()
      const controller = new authentication.AuthenticationController(context)
      await controller.executeRequest(request)
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Cancel authorization skipped: ${(e as BusinessError).code}`)
    }
  }

  private static mapLoginError(err: BusinessError): string {
    if (err.code === 1001500001) {
      return '应用指纹校验失败：请先在 AGC 配置 client_id 与证书指纹（见 README）'
    }
    if (err.code === 1001502001) {
      return '未登录华为账号，请先在系统设置中登录'
    }
    if (err.code === 1001502002) {
      return '应用未获授权'
    }
    if (err.code === 1001502012) {
      return '已取消授权'
    }
    if (err.code === 1001502005) {
      return '网络错误，请稍后重试'
    }
    if (err.code === 1001502014) {
      return '缺少所需 scope/permission，请检查 AGC 配置'
    }
    if (err.code === 1001502003) {
      return '登录参数无效：请确认 module.json5 已配置 AGC 真实 Client ID（当前可能仍是占位值），且签名 Profile 与 AGC 应用一致（见 README「华为云服务配置」）'
    }
    return `登录失败（${err.code}）：${err.message}`
  }
}
