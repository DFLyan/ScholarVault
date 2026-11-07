import { cloudStorage } from '@kit.CloudFoundationKit'
import { request } from '@kit.BasicServicesKit'
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { DatabaseHelper } from '../db/DatabaseHelper'

const DOMAIN = 0x0000
const TAG = 'CloudBackup'
const PREF_NAME = 'scholarvault_cloud'
const CLOUD_DIR = 'scholarvault'
const LOCAL_BACKUP_NAME = 'sv_cloud_backup.db'
const LOCAL_RESTORE_NAME = 'sv_cloud_restore.db'
const MAX_CLOUD_BACKUPS = 5

export class CloudBackupService {
  private static async getPrefs(context: common.Context): Promise<preferences.Preferences> {
    return await preferences.getPreferences(context, PREF_NAME)
  }

  // 立即备份：RDB 备份到本地 → 上传华为云空间 → 清理旧备份 → 记录时间
  static async backupNow(context: common.Context): Promise<string> {
    if (!canIUse('SystemCapability.DeviceCloudGateway.CloudFoundation')) {
      return Promise.reject(new Error('当前设备不支持华为云空间服务'))
    }
    // 1. 数据库备份到本地
    const dbOk = await DatabaseHelper.getInstance().backupDatabase(LOCAL_BACKUP_NAME)
    if (!dbOk) {
      return Promise.reject(new Error('数据库本地备份失败'))
    }
    const localPath = `${context.databaseDir}/${LOCAL_BACKUP_NAME}`
    const stamp = CloudBackupService.formatStamp(Date.now())
    const cloudPath = `${CLOUD_DIR}/backup_${stamp}.db`
    // 2. 上传云空间（前台任务，等待完成）
    try {
      const bucket = cloudStorage.bucket()
      const params: cloudStorage.UploadParams = {
        localPath: localPath,
        cloudPath: cloudPath,
        mode: request.agent.Mode.FOREGROUND
      }
      const task = await bucket.uploadFile(context, params)
      await CloudBackupService.waitTask(task)
      hilog.info(DOMAIN, TAG, `Backup uploaded to ${cloudPath}`)
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, `Cloud upload failed: ${err.code} ${err.message}`)
      return Promise.reject(new Error(CloudBackupService.mapCloudError(err)))
    }
    // 3. 记录备份时间
    try {
      const prefs = await CloudBackupService.getPrefs(context)
      prefs.putSync('last_backup_time', Date.now())
      await prefs.flush()
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Save last backup time failed: ${(e as Error).message}`)
    }
    // 4. 清理云端旧备份（保留最近 MAX_CLOUD_BACKUPS 个，失败不影响结果）
    await CloudBackupService.cleanOldBackups(context)
    return cloudPath
  }

  // 从云端恢复最近一次备份：列出云端备份 → 下载 → RDB restore
  static async restoreLatest(context: common.Context): Promise<string> {
    if (!canIUse('SystemCapability.DeviceCloudGateway.CloudFoundation')) {
      return Promise.reject(new Error('当前设备不支持华为云空间服务'))
    }
    let latest = ''
    try {
      const bucket = cloudStorage.bucket()
      const results = await bucket.list(CLOUD_DIR)
      for (let i = 0; i < results.files.length; i++) {
        const name = results.files[i]
        if (name.startsWith('backup_') && name.endsWith('.db') && name > latest) {
          latest = name
        }
      }
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, `Cloud list failed: ${err.code} ${err.message}`)
      return Promise.reject(new Error(CloudBackupService.mapCloudError(err)))
    }
    if (latest.length === 0) {
      return Promise.reject(new Error('云空间中未找到备份文件'))
    }
    const localPath = `${context.databaseDir}/${LOCAL_RESTORE_NAME}`
    try {
      const bucket = cloudStorage.bucket()
      const params: cloudStorage.DownloadParams = {
        localPath: localPath,
        cloudPath: `${CLOUD_DIR}/${latest}`,
        mode: request.agent.Mode.FOREGROUND,
        overwrite: true
      }
      const task = await bucket.downloadFile(context, params)
      await CloudBackupService.waitTask(task)
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, `Cloud download failed: ${err.code} ${err.message}`)
      return Promise.reject(new Error(CloudBackupService.mapCloudError(err)))
    }
    const ok = await DatabaseHelper.getInstance().restoreDatabase(LOCAL_RESTORE_NAME)
    if (!ok) {
      return Promise.reject(new Error('数据库恢复失败'))
    }
    return latest
  }

  static async getLastBackupTime(context: common.Context): Promise<number> {
    try {
      const prefs = await CloudBackupService.getPrefs(context)
      return prefs.getSync('last_backup_time', 0) as number
    } catch (e) {
      return 0
    }
  }

  // 等待前台任务完成/失败
  private static waitTask(task: request.agent.Task): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      task.on('completed', (progress: request.agent.Progress) => {
        resolve()
      })
      task.on('failed', (progress: request.agent.Progress) => {
        reject(new Error(`云空间传输失败（state: ${progress.state}）`))
      })
    })
  }

  private static async cleanOldBackups(context: common.Context): Promise<void> {
    try {
      const bucket = cloudStorage.bucket()
      const results = await bucket.list(CLOUD_DIR)
      const names: Array<string> = []
      for (let i = 0; i < results.files.length; i++) {
        const name = results.files[i]
        if (name.startsWith('backup_') && name.endsWith('.db')) {
          names.push(name)
        }
      }
      names.sort()
      while (names.length > MAX_CLOUD_BACKUPS) {
        const oldest = names.shift()
        if (oldest === undefined) {
          break
        }
        await bucket.deleteFile(`${CLOUD_DIR}/${oldest}`)
        hilog.info(DOMAIN, TAG, `Deleted old cloud backup ${oldest}`)
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Clean old backups skipped: ${(e as Error).message}`)
    }
  }

  private static formatStamp(time: number): string {
    const d = new Date(time)
    const pad = (v: number): string => v < 10 ? `0${v}` : `${v}`
    return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}` +
      `_` + `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  }

  private static mapCloudError(err: BusinessError): string {
    if (err.code === 1008220001) {
      return '网络连接错误，请检查网络后重试'
    }
    if (err.code === 1008220009) {
      return '云空间客户端错误：请确认已在 AGC 开通云存储/云备份服务（见 README）'
    }
    if (err.code === 1008221001) {
      return '云空间服务端错误：请确认 AGC 云空间实例已创建且应用已关联'
    }
    return `云空间操作失败（${err.code}）：${err.message}`
  }
}
