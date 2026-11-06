import { pdfService } from '@kit.PDFKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Paper } from '../model/PaperModel'

const DOMAIN = 0x0000
const TAG = 'FullTextSearch'

export class PdfSearchHit {
  paperId: number = 0
  paperTitle: string = ''
  pdfPath: string = ''
  pageIndex: number = 0
  context: string = ''

  constructor(paperId: number, paperTitle: string, pdfPath: string, pageIndex: number, context: string) {
    this.paperId = paperId
    this.paperTitle = paperTitle
    this.pdfPath = pdfPath
    this.pageIndex = pageIndex
    this.context = context
  }
}

export class FullTextSearchService {
  static async searchPdf(pdfPath: string, query: string, maxHits: number): Promise<Array<PdfSearchHit>> {
    const hits: Array<PdfSearchHit> = []
    const document = new pdfService.PdfDocument()
    try {
      const parseResult = document.loadDocument(pdfPath)
      if (parseResult !== pdfService.ParseResult.PARSE_SUCCESS) {
        hilog.warn(DOMAIN, TAG, `Load PDF failed: ${pdfPath}, result: ${parseResult}`)
        return hits
      }
      const options: pdfService.SearchOptions = {
        contextStringLength: 60
      }
      await document.searchKey(query, (results: Array<pdfService.SearchResultData>): boolean => {
        for (let i = 0; i < results.length; i++) {
          const result = results[i]
          const context = result.contextString.replace(/\s+/g, ' ').trim()
          hits.push(new PdfSearchHit(0, '', pdfPath, result.pageIndex + 1, context))
          if (hits.length >= maxHits) {
            return true
          }
        }
        return hits.length >= maxHits
      }, options)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Search PDF failed: ${(e as Error).message}`)
    } finally {
      try {
        document.releaseDocument()
      } catch (e) {
        // 忽略释放异常
      }
    }
    return hits
  }

  static async searchAllPapers(query: string, papers: Array<Paper>, maxHitsPerPaper: number,
    onProgress: (done: number, total: number) => void): Promise<Array<PdfSearchHit>> {
    const allHits: Array<PdfSearchHit> = []
    const withPdf = papers.filter((p: Paper): boolean => p.pdfPath.length > 0)
    let done = 0
    for (let i = 0; i < withPdf.length; i++) {
      const paper = withPdf[i]
      const hits = await FullTextSearchService.searchPdf(paper.pdfPath, query, maxHitsPerPaper)
      for (let j = 0; j < hits.length; j++) {
        hits[j].paperId = paper.id
        hits[j].paperTitle = paper.title
        allHits.push(hits[j])
      }
      done++
      onProgress(done, withPdf.length)
    }
    return allHits
  }
}
