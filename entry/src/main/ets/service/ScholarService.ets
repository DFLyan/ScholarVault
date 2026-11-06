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
