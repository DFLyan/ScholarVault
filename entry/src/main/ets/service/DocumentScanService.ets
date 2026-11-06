import { fileIo as fs } from '@kit.CoreFileKit'
import { zlib } from '@kit.BasicServicesKit'
import { util } from '@kit.ArkTS'
import { common } from '@kit.AbilityKit'
import { pdfService } from '@kit.PDFKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Paper } from '../model/PaperModel'
import { DuplicateService } from '../service/DuplicateService'

const DOMAIN = 0x0000
const TAG = 'DocumentScan'

export class ScannedDocument {
  fileName: string = ''
  filePath: string = ''
  fileType: string = ''
  matchedPaperTitles: Array<string> = []
  matchedPages: Array<string> = []

  constructor(fileName: string, filePath: string, fileType: string) {
    this.fileName = fileName
    this.filePath = filePath
    this.fileType = fileType
  }
}

export class DocumentScanService {
  static readonly SUPPORTED_SUFFIXES: Array<string> = ['.pdf', '.docx', '.xlsx', '.txt', '.md']

  static isSupported(fileName: string): boolean {
    const lower = fileName.toLowerCase()
    for (let i = 0; i < DocumentScanService.SUPPORTED_SUFFIXES.length; i++) {
      if (lower.endsWith(DocumentScanService.SUPPORTED_SUFFIXES[i])) {
        return true
      }
    }
    return false
  }

  static getFileType(fileName: string): string {
    const lower = fileName.toLowerCase()
    if (lower.endsWith('.pdf')) {
      return 'pdf'
    }
    if (lower.endsWith('.docx')) {
      return 'docx'
    }
    if (lower.endsWith('.xlsx')) {
      return 'xlsx'
    }
    if (lower.endsWith('.txt')) {
      return 'txt'
    }
    if (lower.endsWith('.md')) {
      return 'md'
    }
    return 'unknown'
  }

  static async copyToScanDir(context: common.Context, sourceUri: string, fileName: string): Promise<string> {
    const scanDir = `${context.cacheDir}/scan`
    if (!fs.accessSync(scanDir)) {
      fs.mkdirSync(scanDir, true)
    }
    const safeName = fileName.replace(/[/\\:]/g, '_')
    const destPath = `${scanDir}/${Date.now()}_${safeName}`
    const source = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY)
    const dest = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    try {
      fs.copyFileSync(source.fd, dest.fd)
    } finally {
      fs.closeSync(source)
      fs.closeSync(dest)
    }
    return destPath
  }

  static async scanDocument(displayName: string, filePath: string, fileType: string,
    papers: Array<Paper>): Promise<ScannedDocument> {
    const doc = new ScannedDocument(displayName, filePath, fileType)
    if (fileType === 'pdf') {
      await DocumentScanService.scanPdf(doc, papers)
    } else {
      const text = await DocumentScanService.extractText(filePath, fileType)
      DocumentScanService.matchPlainText(doc, text, papers)
    }
    return doc
  }

  private static async scanPdf(doc: ScannedDocument, papers: Array<Paper>): Promise<void> {
    const document = new pdfService.PdfDocument()
    try {
      const parseResult = document.loadDocument(doc.filePath)
      if (parseResult !== pdfService.ParseResult.PARSE_SUCCESS) {
        hilog.warn(DOMAIN, TAG, `Load PDF failed: ${doc.fileName}, result: ${parseResult}`)
        return
      }
      const options: pdfService.SearchOptions = {
        contextStringLength: 20
      }
      for (let i = 0; i < papers.length; i++) {
        const paper = papers[i]
        const normalized = DuplicateService.normalizeTitle(paper.title)
        if (normalized.length < 4) {
          continue
        }
        const pages: Array<number> = []
        await document.searchKey(paper.title, (results: Array<pdfService.SearchResultData>): boolean => {
          for (let j = 0; j < results.length; j++) {
            const ctx = results[j].contextString.replace(/\s+/g, ' ').trim()
            if (DuplicateService.normalizeTitle(ctx).indexOf(normalized) >= 0) {
              if (pages.indexOf(results[j].pageIndex + 1) < 0) {
                pages.push(results[j].pageIndex + 1)
              }
            }
          }
          return pages.length >= 5
        }, options)
        if (pages.length > 0) {
          doc.matchedPaperTitles.push(paper.title)
          doc.matchedPages.push(pages.slice(0, 5).map((p: number): string => `${p}`).join('、'))
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Scan PDF failed: ${(e as Error).message}`)
    } finally {
      try {
        document.releaseDocument()
      } catch (e) {
        // 忽略释放异常
      }
    }
  }

  private static matchPlainText(doc: ScannedDocument, text: string, papers: Array<Paper>): void {
    if (text.length === 0) {
      return
    }
    const normalizedText = DuplicateService.normalizeTitle(text)
    for (let i = 0; i < papers.length; i++) {
      const normalized = DuplicateService.normalizeTitle(papers[i].title)
      if (normalized.length < 4) {
        continue
      }
      if (normalizedText.indexOf(normalized) >= 0) {
        doc.matchedPaperTitles.push(papers[i].title)
        doc.matchedPages.push('')
      }
    }
  }

  private static async extractText(filePath: string, fileType: string): Promise<string> {
    try {
      if (fileType === 'txt' || fileType === 'md') {
        return DocumentScanService.readTextFile(filePath)
      }
      if (fileType === 'docx' || fileType === 'xlsx') {
        return await DocumentScanService.extractOfficeXmlText(filePath, fileType)
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Extract text failed: ${(e as Error).message}`)
    }
    return ''
  }

  private static readTextFile(filePath: string): string {
    const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY)
    try {
      const stat = fs.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf))
    } finally {
      fs.closeSync(file)
    }
  }

  private static async extractOfficeXmlText(filePath: string, fileType: string): Promise<string> {
    const outDir = `${filePath}_extract_${Date.now()}`
    if (!fs.accessSync(outDir)) {
      fs.mkdirSync(outDir, true)
    }
    try {
      await zlib.decompressFile(filePath, outDir)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Unzip office file failed: ${(e as Error).message}`)
      return ''
    }
    let xmlPath = ''
    if (fileType === 'docx') {
      xmlPath = `${outDir}/word/document.xml`
    } else {
      xmlPath = `${outDir}/xl/sharedStrings.xml`
    }
    if (!fs.accessSync(xmlPath)) {
      return ''
    }
    const raw = DocumentScanService.readTextFile(xmlPath)
    return raw.replace(/<[^>]+>/g, ' ')
  }

  static cleanupScanDir(context: common.Context): void {
    const scanDir = `${context.cacheDir}/scan`
    try {
      if (fs.accessSync(scanDir)) {
        fs.rmdirSync(scanDir)
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `Cleanup scan dir failed: ${(e as Error).message}`)
    }
  }
}
