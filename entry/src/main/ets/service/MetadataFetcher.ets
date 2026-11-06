import { http } from '@kit.NetworkKit'
import { Paper } from '../model/PaperModel'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'MetadataFetcher'

export class MetadataFetcher {
  static async fetchByDOI(doi: string): Promise<Paper | undefined> {
    const url = `https://api.crossref.org/works/${doi}`
    try {
      const request = http.createHttp()
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' }
      })
      request.destroy()
      if (response.responseCode === 200 && typeof response.result === 'string') {
        return MetadataFetcher.parseCrossRefResponse(response.result, doi)
      }
      hilog.error(DOMAIN, TAG, `CrossRef request failed: ${response.responseCode}`)
      return undefined
    } catch (e) {
      hilog.error(DOMAIN, TAG, `CrossRef fetch error: ${(e as Error).message}`)
      return undefined
    }
  }

  private static parseCrossRefResponse(jsonStr: string, doi: string): Paper | undefined {
    try {
      const obj = JSON.parse(jsonStr) as Record<string, Object>
      const message = obj['message'] as Record<string, Object>
      if (message === undefined) {
        return undefined
      }
      const paper = new Paper()
      paper.doi = doi
      const titleArr = message['title'] as Array<string>
      paper.title = (titleArr !== undefined && titleArr.length > 0) ? titleArr[0] : ''
      const authorObjs = message['author'] as Array<Record<string, string>>
      if (authorObjs !== undefined) {
        const authors: Array<string> = []
        for (let i = 0; i < authorObjs.length; i++) {
          const given = authorObjs[i]['given'] ?? ''
          const family = authorObjs[i]['family'] ?? ''
          authors.push(`${given} ${family}`.trim())
        }
        paper.authors = Paper.authorsToString(authors)
      }
      const published = message['published-print'] as Record<string, Object>
      if (published !== undefined) {
        const dateParts = published['date-parts'] as Array<Array<number>>
        if (dateParts !== undefined && dateParts.length > 0 && dateParts[0].length > 0) {
          paper.year = dateParts[0][0]
        }
      }
      if (paper.year === 0) {
        const publishedOnline = message['published-online'] as Record<string, Object>
        if (publishedOnline !== undefined) {
          const dateParts2 = publishedOnline['date-parts'] as Array<Array<number>>
          if (dateParts2 !== undefined && dateParts2.length > 0 && dateParts2[0].length > 0) {
            paper.year = dateParts2[0][0]
          }
        }
      }
      const containerTitle = message['container-title'] as Array<string>
      paper.journal = (containerTitle !== undefined && containerTitle.length > 0) ? containerTitle[0] : ''
      paper.abstract = (message['abstract'] as string) ?? ''
      const now = Date.now()
      paper.dateAdded = now
      paper.dateModified = now
      return paper
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Parse CrossRef response failed: ${(e as Error).message}`)
      return undefined
    }
  }

  static async fetchByArxivId(arxivId: string): Promise<Paper | undefined> {
    const url = `http://export.arxiv.org/api/query?id_list=${arxivId}`
    try {
      const request = http.createHttp()
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/xml' }
      })
      request.destroy()
      if (response.responseCode === 200 && typeof response.result === 'string') {
        return MetadataFetcher.parseArxivResponse(response.result, arxivId)
      }
      hilog.error(DOMAIN, TAG, `arXiv request failed: ${response.responseCode}`)
      return undefined
    } catch (e) {
      hilog.error(DOMAIN, TAG, `arXiv fetch error: ${(e as Error).message}`)
      return undefined
    }
  }

  private static parseArxivResponse(xmlStr: string, arxivId: string): Paper | undefined {
    try {
      // arXiv Atom 响应中第一个 <title> 是 feed 标题，论文信息必须从 <entry> 中解析
      const entryMatch = xmlStr.match(/<entry>([\s\S]*?)<\/entry>/)
      if (entryMatch === null || entryMatch.length < 2) {
        hilog.error(DOMAIN, TAG, 'No entry found in arXiv response')
        return undefined
      }
      const entry = entryMatch[1]
      const paper = new Paper()
      paper.arxivId = arxivId
      const titleMatch = entry.match(/<title[^>]*>([\s\S]*?)<\/title>/)
      if (titleMatch !== null && titleMatch.length > 1) {
        paper.title = titleMatch[1].replace(/\n/g, ' ').trim()
      }
      const authorMatches = entry.match(/<name>([\s\S]*?)<\/name>/g)
      if (authorMatches !== null) {
        const authors: Array<string> = []
        for (let i = 0; i < authorMatches.length; i++) {
          const nameMatch = authorMatches[i].match(/<name>([\s\S]*?)<\/name>/)
          if (nameMatch !== null && nameMatch.length > 1) {
            authors.push(nameMatch[1].trim())
          }
        }
        paper.authors = Paper.authorsToString(authors)
      }
      const summaryMatch = entry.match(/<summary[^>]*>([\s\S]*?)<\/summary>/)
      if (summaryMatch !== null && summaryMatch.length > 1) {
        paper.abstract = summaryMatch[1].replace(/\n/g, ' ').trim()
      }
      const publishedMatch = entry.match(/<published>([\s\S]*?)<\/published>/)
      if (publishedMatch !== null && publishedMatch.length > 1) {
        const yearStr = publishedMatch[1].substring(0, 4)
        paper.year = parseInt(yearStr, 10)
        if (isNaN(paper.year)) {
          paper.year = 0
        }
      }
      const doiMatch = entry.match(/<doi[^>]*>([\s\S]*?)<\/doi>/)
      if (doiMatch !== null && doiMatch.length > 1) {
        paper.doi = doiMatch[1].trim()
      }
      const categoryMatch = entry.match(/category term="([^"]*)"/g)
      if (categoryMatch !== null) {
        const keywords: Array<string> = []
        for (let i = 0; i < categoryMatch.length; i++) {
          const termMatch = categoryMatch[i].match(/term="([^"]*)"/)
          if (termMatch !== null && termMatch.length > 1) {
            keywords.push(termMatch[1])
          }
        }
        paper.keywords = Paper.keywordsToString(keywords)
      }
      const now = Date.now()
      paper.dateAdded = now
      paper.dateModified = now
      return paper
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Parse arXiv response failed: ${(e as Error).message}`)
      return undefined
    }
  }
}
