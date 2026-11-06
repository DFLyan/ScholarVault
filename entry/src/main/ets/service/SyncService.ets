import { http } from '@kit.NetworkKit'
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Paper } from '../model/PaperModel'

const DOMAIN = 0x0000
const TAG = 'SyncService'
const PREF_NAME = 'scholarvault_sync'

export class ZoteroConfig {
  userId: string = ''
  apiKey: string = ''
}

export class ZoteroItemResult {
  imported: number = 0
  duplicates: number = 0
  failed: number = 0
}

export class SyncService {
  private static async getPrefs(context: common.Context): Promise<preferences.Preferences> {
    return await preferences.getPreferences(context, PREF_NAME)
  }

  static async saveZoteroConfig(context: common.Context, config: ZoteroConfig): Promise<boolean> {
    try {
      const prefs = await SyncService.getPrefs(context)
      prefs.putSync('zotero_user_id', config.userId)
      prefs.putSync('zotero_api_key', config.apiKey)
      await prefs.flush()
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Save Zotero config failed: ${(e as Error).message}`)
      return false
    }
  }

  static async getZoteroConfig(context: common.Context): Promise<ZoteroConfig> {
    const config = new ZoteroConfig()
    try {
      const prefs = await SyncService.getPrefs(context)
      config.userId = prefs.getSync('zotero_user_id', '') as string
      config.apiKey = prefs.getSync('zotero_api_key', '') as string
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Read Zotero config failed: ${(e as Error).message}`)
    }
    return config
  }

  static async fetchZoteroItems(config: ZoteroConfig, maxItems: number): Promise<Array<Paper>> {
    const papers: Array<Paper> = []
    const limit = 50
    let start = 0
    while (start < maxItems) {
      const url = `https://api.zotero.org/users/${encodeURIComponent(config.userId)}/items` +
        `?v=3&format=json&limit=${limit}&start=${start}&sort=dateModified&direction=desc`
      try {
        const request = http.createHttp()
        const response = await request.request(url, {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json',
            'Zotero-API-Key': config.apiKey
          },
          connectTimeout: 15000,
          readTimeout: 30000
        })
        request.destroy()
        if (response.responseCode === 403 || response.responseCode === 401) {
          hilog.error(DOMAIN, TAG, `Zotero auth failed: ${response.responseCode}`)
          break
        }
        if (response.responseCode !== 200 || typeof response.result !== 'string') {
          hilog.error(DOMAIN, TAG, `Zotero request failed: ${response.responseCode}`)
          break
        }
        const items = JSON.parse(response.result) as Array<Record<string, Object>>
        if (items.length === 0) {
          break
        }
        for (let i = 0; i < items.length; i++) {
          const data = items[i]['data'] as Record<string, Object>
          if (data === undefined) {
            continue
          }
          const paper = SyncService.parseZoteroItem(data)
          if (paper !== undefined) {
            papers.push(paper)
          }
        }
        if (items.length < limit || papers.length >= maxItems) {
          break
        }
        start += limit
      } catch (e) {
        hilog.error(DOMAIN, TAG, `Fetch Zotero items error: ${(e as Error).message}`)
        break
      }
    }
    return papers
  }

  private static parseZoteroItem(data: Record<string, Object>): Paper | undefined {
    const itemType = (data['itemType'] as string) ?? ''
    if (itemType === 'attachment' || itemType === 'note' || itemType.length === 0) {
      return undefined
    }
    const paper = new Paper()
    paper.title = (data['title'] as string) ?? ''
    if (paper.title.trim().length === 0) {
      return undefined
    }
    const creators = data['creators'] as Array<Record<string, string>>
    if (creators !== undefined) {
      const authors: Array<string> = []
      for (let i = 0; i < creators.length; i++) {
        const name = creators[i]['name'] ?? ''
        if (name.length > 0) {
          authors.push(name)
          continue
        }
        const given = creators[i]['firstName'] ?? ''
        const family = creators[i]['lastName'] ?? ''
        const full = `${given} ${family}`.trim()
        if (full.length > 0) {
          authors.push(full)
        }
      }
      if (authors.length > 0) {
        paper.authors = Paper.authorsToString(authors)
      }
    }
    const dateStr = (data['date'] as string) ?? ''
    const yearMatch = dateStr.match(/\d{4}/)
    if (yearMatch !== null) {
      paper.year = parseInt(yearMatch[0], 10)
    }
    paper.journal = (data['publicationTitle'] as string) ?? ''
    paper.doi = (data['DOI'] as string) ?? ''
    paper.abstract = (data['abstractNote'] as string) ?? ''
    const tags = data['tags'] as Array<Record<string, string>>
    if (tags !== undefined && tags.length > 0) {
      const keywords: Array<string> = []
      for (let i = 0; i < tags.length; i++) {
        const tag = tags[i]['tag'] ?? ''
        if (tag.length > 0) {
          keywords.push(tag)
        }
      }
      if (keywords.length > 0) {
        paper.keywords = Paper.keywordsToString(keywords)
      }
    }
    const now = Date.now()
    paper.dateAdded = now
    paper.dateModified = now
    return paper
  }
}
