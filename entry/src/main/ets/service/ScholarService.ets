import { http } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'ScholarService'

export class RelatedPaper {
  title: string = ''
  year: number = 0
  venue: string = ''
  citationCount: number = -1
  doi: string = ''
}

export class ScholarService {
  static async fetchCitationCount(doi: string): Promise<number> {
    const url = `https://api.openalex.org/works/https://doi.org/${doi}`
    try {
      const request = http.createHttp()
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' }
      })
      request.destroy()
      if (response.responseCode === 200 && typeof response.result === 'string') {
        const obj = JSON.parse(response.result) as Record<string, Object>
        const count = obj['cited_by_count'] as number
        if (count !== undefined) {
          return count
        }
      }
      hilog.error(DOMAIN, TAG, `OpenAlex request failed: ${response.responseCode}`)
      return -1
    } catch (e) {
      hilog.error(DOMAIN, TAG, `OpenAlex fetch error: ${(e as Error).message}`)
      return -1
    }
  }

  static async fetchRelatedPapers(doi: string, limit: number): Promise<Array<RelatedPaper>> {
    const url = `https://api.semanticscholar.org/recommendations/v1/papers/forpaper/DOI:${doi}` +
      `?fields=title,year,venue,citationCount,externalIds&limit=${limit}`
    try {
      const request = http.createHttp()
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        connectTimeout: 15000,
        readTimeout: 15000
      })
      request.destroy()
      if (response.responseCode === 200 && typeof response.result === 'string') {
        return ScholarService.parseRecommendations(response.result)
      }
      hilog.error(DOMAIN, TAG, `Semantic Scholar request failed: ${response.responseCode}`)
      return []
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Semantic Scholar fetch error: ${(e as Error).message}`)
      return []
    }
  }

  static async fetchPaperCandidates(title: string, limit: number): Promise<Array<RelatedPaper>> {
    const query = encodeURIComponent(title)
    const url = `https://api.semanticscholar.org/graph/v1/paper/search?query=${query}` +
      `&fields=title,year,venue,citationCount,externalIds&limit=${limit}`
    try {
      const request = http.createHttp()
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        connectTimeout: 15000,
        readTimeout: 15000
      })
      request.destroy()
      if (response.responseCode === 200 && typeof response.result === 'string') {
        return ScholarService.parseSearchResults(response.result)
      }
      hilog.error(DOMAIN, TAG, `Semantic Scholar search failed: ${response.responseCode}`)
      return []
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Semantic Scholar search error: ${(e as Error).message}`)
      return []
    }
  }

  // Google Scholar 无公开 API：模拟浏览器请求搜索页 HTML，
  // 解析结果条目（标题/年份/来源/被引数），做法同 Zotero 的 GS 引用数插件
  static async fetchGoogleScholarCandidates(title: string, limit: number): Promise<Array<RelatedPaper>> {
    const query = encodeURIComponent(title)
    const url = `https://scholar.google.com/scholar?hl=en&as_sdt=0,5&q=${query}`
    try {
      const request = http.createHttp()
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
            '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9'
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 15000
      })
      request.destroy()
      if (response.responseCode !== 200 || typeof response.result !== 'string') {
        hilog.error(DOMAIN, TAG, `Google Scholar request failed: ${response.responseCode}`)
        return []
      }
      const html = response.result
      // 触发人机验证/限流时 GS 返回验证页
      if (html.indexOf('unusual traffic') >= 0 || html.indexOf('gs_captcha') >= 0 ||
        html.indexOf('not a robot') >= 0) {
        hilog.warn(DOMAIN, TAG, 'Google Scholar returned captcha page')
        return []
      }
      return ScholarService.parseGoogleScholarHtml(html, limit)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Google Scholar fetch error: ${(e as Error).message}`)
      return []
    }
  }

  private static parseGoogleScholarHtml(html: string, limit: number): Array<RelatedPaper> {
    const results: Array<RelatedPaper> = []
    // 每条结果的信息区以 <div class="gs_ri"> 开始，块内含 h3 标题、gs_a 作者行、Cited by 链接
    const chunks = html.split('<div class="gs_ri">')
    for (let i = 1; i < chunks.length && results.length < limit; i++) {
      const chunk = chunks[i]
      const related = ScholarService.parseGsChunk(chunk)
      if (related !== undefined) {
        results.push(related)
      }
    }
    return results
  }

  private static parseGsChunk(chunk: string): RelatedPaper | undefined {
    try {
      const titleMatch = chunk.match(/<h3[^>]*>([\s\S]*?)<\/h3>/)
      if (titleMatch === null) {
        return undefined
      }
      const title = ScholarService.cleanGsText(titleMatch[1])
      if (title.length === 0) {
        return undefined
      }
      const related = new RelatedPaper()
      related.title = title

      // gs_a 行格式：作者列表 - 来源, 年份 - 域名
      const infoMatch = chunk.match(/<div class="gs_a">([\s\S]*?)<\/div>/)
      if (infoMatch !== null) {
        const infoLine = ScholarService.cleanGsText(infoMatch[1])
        const yearMatch = infoLine.match(/\b(19|20)\d{2}\b/)
        if (yearMatch !== null) {
          related.year = parseInt(yearMatch[0], 10)
        }
        const parts = infoLine.split(' - ')
        if (parts.length >= 3) {
          related.venue = parts[1].replace(/\b(19|20)\d{2}\b/g, '').replace(/,\s*$/, '').trim()
        }
      }

      const citedMatch = chunk.match(/Cited by\s*([\d,]+)/)
      if (citedMatch !== null) {
        related.citationCount = parseInt(citedMatch[1].replace(/,/g, ''), 10)
      }
      return related
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Parse GS chunk failed: ${(e as Error).message}`)
      return undefined
    }
  }

  private static cleanGsText(raw: string): string {
    let text = raw.replace(/<[^>]*>/g, ' ')
    text = text.replace(/\[(CITATION|C|PDF|DOC|HTML|BOOK|SLIDES?)\]/gi, '')
    text = text.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&#39;/g, '\'').replace(/&nbsp;/g, ' ')
    text = text.replace(/\s+/g, ' ').trim()
    return text
  }

  private static parseSearchResults(jsonStr: string): Array<RelatedPaper> {
    const results: Array<RelatedPaper> = []
    try {
      const obj = JSON.parse(jsonStr) as Record<string, Object>
      const dataArr = obj['data'] as Array<Record<string, Object>>
      if (dataArr === undefined) {
        return results
      }
      for (let i = 0; i < dataArr.length; i++) {
        const item = dataArr[i]
        const related = new RelatedPaper()
        related.title = (item['title'] as string) ?? ''
        const yearVal = item['year'] as number
        related.year = yearVal ?? 0
        related.venue = (item['venue'] as string) ?? ''
        const citeVal = item['citationCount'] as number
        related.citationCount = citeVal ?? -1
        const extIds = item['externalIds'] as Record<string, string>
        if (extIds !== undefined) {
          related.doi = extIds['DOI'] ?? ''
        }
        if (related.title.length > 0) {
          results.push(related)
        }
      }
      return results
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Parse search results failed: ${(e as Error).message}`)
      return results
    }
  }

  private static parseRecommendations(jsonStr: string): Array<RelatedPaper> {
    const results: Array<RelatedPaper> = []
    try {
      const obj = JSON.parse(jsonStr) as Record<string, Object>
      const recommended = obj['recommendedPapers'] as Array<Record<string, Object>>
      if (recommended === undefined) {
        return results
      }
      for (let i = 0; i < recommended.length; i++) {
        const item = recommended[i]
        const related = new RelatedPaper()
        related.title = (item['title'] as string) ?? ''
        const yearVal = item['year'] as number
        related.year = yearVal ?? 0
        related.venue = (item['venue'] as string) ?? ''
        const citeVal = item['citationCount'] as number
        related.citationCount = citeVal ?? -1
        const extIds = item['externalIds'] as Record<string, string>
        if (extIds !== undefined) {
          related.doi = extIds['DOI'] ?? ''
        }
        if (related.title.length > 0) {
          results.push(related)
        }
      }
      return results
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Parse recommendations failed: ${(e as Error).message}`)
      return results
    }
  }
}
