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
  source: string = ''
}

export class CitationResult {
  source: string = ''
  count: number = -1
  year: number = 0
  venue: string = ''
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
      related.source = 'Google Scholar'

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
        related.source = 'Semantic Scholar'
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
        related.source = 'Semantic Scholar'
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

  // ===== 引用数多源同步（OpenAlex / CrossRef / Semantic Scholar，均免费公开、无限流）=====

  // 按 DOI 瀑布查询：OpenAlex → CrossRef → Semantic Scholar，任一成功即返回
  static async fetchCitationByDoi(doi: string): Promise<CitationResult | undefined> {
    const openalex = await ScholarService.fetchFromOpenAlexByDoi(doi)
    if (openalex !== undefined) {
      return openalex
    }
    const crossref = await ScholarService.fetchFromCrossRefByDoi(doi)
    if (crossref !== undefined) {
      return crossref
    }
    const s2 = await ScholarService.fetchFromSemanticScholarByDoi(doi)
    if (s2 !== undefined) {
      return s2
    }
    return undefined
  }

  // 标题多源候选：OpenAlex + Semantic Scholar + CrossRef 合并去重，供用户选择确认
  static async fetchTitleCandidatesMulti(title: string, limit: number): Promise<Array<RelatedPaper>> {
    const merged: Array<RelatedPaper> = []
    const seenDois: Array<string> = []
    const seenTitles: Array<string> = []
    const sources: Array<Promise<Array<RelatedPaper>>> = [
      ScholarService.fetchOpenAlexTitleCandidates(title, limit),
      ScholarService.fetchPaperCandidates(title, limit),
      ScholarService.fetchCrossRefTitleCandidates(title, limit)
    ]
    const all = await Promise.all(sources)
    for (let s = 0; s < all.length; s++) {
      const list = all[s]
      for (let i = 0; i < list.length; i++) {
        const item = list[i]
        const doiKey = item.doi.toLowerCase()
        const titleKey = item.title.toLowerCase().replace(/\s+/g, ' ').trim()
        if (item.doi.length > 0 && seenDois.indexOf(doiKey) >= 0) {
          continue
        }
        if (item.doi.length === 0 && seenTitles.indexOf(titleKey) >= 0) {
          continue
        }
        if (item.doi.length > 0) {
          seenDois.push(doiKey)
        } else {
          seenTitles.push(titleKey)
        }
        merged.push(item)
        if (merged.length >= limit) {
          return merged
        }
      }
    }
    return merged
  }

  private static async fetchFromOpenAlexByDoi(doi: string): Promise<CitationResult | undefined> {
    const url = `https://api.openalex.org/works/https://doi.org/${doi}`
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
        return ScholarService.parseOpenAlexWork(JSON.parse(response.result) as Record<string, Object>, 'OpenAlex')
      }
      return undefined
    } catch (e) {
      hilog.error(DOMAIN, TAG, `OpenAlex by DOI failed: ${(e as Error).message}`)
      return undefined
    }
  }

  private static async fetchFromCrossRefByDoi(doi: string): Promise<CitationResult | undefined> {
    const url = `https://api.crossref.org/works/${doi}`
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
        const obj = JSON.parse(response.result) as Record<string, Object>
        const message = obj['message'] as Record<string, Object>
        if (message === undefined) {
          return undefined
        }
        const result = new CitationResult()
        result.source = 'CrossRef'
        const count = message['is-referenced-by-count'] as number
        result.count = count ?? -1
        const issued = message['issued'] as Record<string, Object>
        if (issued !== undefined) {
          const dateParts = issued['date-parts'] as Array<Array<number>>
          if (dateParts !== undefined && dateParts.length > 0 && dateParts[0].length > 0) {
            result.year = dateParts[0][0]
          }
        }
        const containers = message['container-title'] as Array<string>
        if (containers !== undefined && containers.length > 0) {
          result.venue = containers[0]
        }
        result.doi = doi
        if (result.count >= 0) {
          return result
        }
      }
      return undefined
    } catch (e) {
      hilog.error(DOMAIN, TAG, `CrossRef by DOI failed: ${(e as Error).message}`)
      return undefined
    }
  }

  private static async fetchFromSemanticScholarByDoi(doi: string): Promise<CitationResult | undefined> {
    const url = `https://api.semanticscholar.org/graph/v1/paper/DOI:${doi}` +
      `?fields=title,year,venue,citationCount,externalIds`
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
        const related = ScholarService.parseSearchResults(`{"data":[${response.result}]}`)[0]
        if (related !== undefined) {
          const result = new CitationResult()
          result.source = 'Semantic Scholar'
          result.count = related.citationCount
          result.year = related.year
          result.venue = related.venue
          result.doi = related.doi
          if (result.count >= 0) {
            return result
          }
        }
      }
      return undefined
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Semantic Scholar by DOI failed: ${(e as Error).message}`)
      return undefined
    }
  }

  private static async fetchOpenAlexTitleCandidates(title: string, limit: number): Promise<Array<RelatedPaper>> {
    const query = encodeURIComponent(title)
    const url = `https://api.openalex.org/works?filter=title.search:${query}&per-page=${limit}`
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
        const obj = JSON.parse(response.result) as Record<string, Object>
        const results = obj['results'] as Array<Record<string, Object>>
        const candidates: Array<RelatedPaper> = []
        if (results === undefined) {
          return candidates
        }
        for (let i = 0; i < results.length; i++) {
          const work = ScholarService.parseOpenAlexWork(results[i], 'OpenAlex')
          const related = new RelatedPaper()
          related.title = (results[i]['title'] as string) ?? ''
          related.year = work !== undefined ? work.year : 0
          related.venue = work !== undefined ? work.venue : ''
          related.citationCount = work !== undefined ? work.count : -1
          related.doi = work !== undefined ? work.doi : ''
          related.source = 'OpenAlex'
          if (related.title.length > 0) {
            candidates.push(related)
          }
        }
        return candidates
      }
      return []
    } catch (e) {
      hilog.error(DOMAIN, TAG, `OpenAlex title search failed: ${(e as Error).message}`)
      return []
    }
  }

  private static async fetchCrossRefTitleCandidates(title: string, limit: number): Promise<Array<RelatedPaper>> {
    const query = encodeURIComponent(title)
    const url = `https://api.crossref.org/works?query.bibliographic=${query}&rows=${limit}` +
      `&select=DOI,title,is-referenced-by-count,issued,container-title`
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
        const obj = JSON.parse(response.result) as Record<string, Object>
        const message = obj['message'] as Record<string, Object>
        const items: Array<RelatedPaper> = []
        if (message === undefined) {
          return items
        }
        const works = message['items'] as Array<Record<string, Object>>
        if (works === undefined) {
          return items
        }
        for (let i = 0; i < works.length; i++) {
          const work = works[i]
          const related = new RelatedPaper()
          const titleArr = work['title'] as Array<string>
          related.title = titleArr !== undefined && titleArr.length > 0 ? titleArr[0] : ''
          const count = work['is-referenced-by-count'] as number
          related.citationCount = count ?? -1
          related.doi = (work['DOI'] as string) ?? ''
          const issued = work['issued'] as Record<string, Object>
          if (issued !== undefined) {
            const dateParts = issued['date-parts'] as Array<Array<number>>
            if (dateParts !== undefined && dateParts.length > 0 && dateParts[0].length > 0) {
              related.year = dateParts[0][0]
            }
          }
          const containers = work['container-title'] as Array<string>
          if (containers !== undefined && containers.length > 0) {
            related.venue = containers[0]
          }
          related.source = 'CrossRef'
          if (related.title.length > 0) {
            items.push(related)
          }
        }
        return items
      }
      return []
    } catch (e) {
      hilog.error(DOMAIN, TAG, `CrossRef title search failed: ${(e as Error).message}`)
      return []
    }
  }

  // 解析 OpenAlex 单个 work 对象（cited_by_count / publication_year / primary_location.source）
  private static parseOpenAlexWork(work: Record<string, Object>, source: string): CitationResult | undefined {
    try {
      const result = new CitationResult()
      result.source = source
      const count = work['cited_by_count'] as number
      if (count === undefined) {
        return undefined
      }
      result.count = count
      result.year = (work['publication_year'] as number) ?? 0
      const doiUrl = (work['doi'] as string) ?? ''
      if (doiUrl.startsWith('https://doi.org/')) {
        result.doi = doiUrl.substring('https://doi.org/'.length)
      }
      const primaryLocation = work['primary_location'] as Record<string, Object>
      if (primaryLocation !== undefined) {
        const sourceObj = primaryLocation['source'] as Record<string, Object>
        if (sourceObj !== undefined) {
          result.venue = (sourceObj['display_name'] as string) ?? ''
        }
      }
      return result
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Parse OpenAlex work failed: ${(e as Error).message}`)
      return undefined
    }
  }
}
