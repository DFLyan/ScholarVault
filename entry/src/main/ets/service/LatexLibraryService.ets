import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Paper } from '../model/PaperModel'
import { CitationService } from '../service/CitationService'
import { CitationFormat } from '../model/CitationStyle'

const DOMAIN = 0x0000
const TAG = 'LatexLibraryService'

export class LatexAppendResult {
  added: number = 0
  skipped: number = 0

  constructor(added: number, skipped: number) {
    this.added = added
    this.skipped = skipped
  }
}

export class LatexLibraryService {
  static getLibraryDir(context: common.Context): string {
    return `${context.filesDir}/latex`
  }

  static getLibraryPath(context: common.Context): string {
    return `${LatexLibraryService.getLibraryDir(context)}/references.bib`
  }

  static extractCiteKeys(content: string): Array<string> {
    const keys: Array<string> = []
    const regex = /@[a-zA-Z]+\s*\{\s*([^,\s{}]+)\s*,/g
    let match = regex.exec(content)
    while (match !== null) {
      if (keys.indexOf(match[1]) < 0) {
        keys.push(match[1])
      }
      match = regex.exec(content)
    }
    return keys
  }

  private static extractKeyFromEntry(entry: string): string {
    const match = entry.match(/@[a-zA-Z]+\s*\{\s*([^,\s{}]+)\s*,/)
    return match !== null ? match[1] : ''
  }

  private static readLibrary(context: common.Context): string {
    const path = LatexLibraryService.getLibraryPath(context)
    try {
      if (!fs.accessSync(path)) {
        return ''
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
      try {
        const stat = fs.statSync(file.fd)
        const buf = new ArrayBuffer(stat.size)
        fs.readSync(file.fd, buf)
        return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf))
      } finally {
        fs.closeSync(file)
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Read latex library failed: ${(e as Error).message}`)
      return ''
    }
  }

  static getLibraryContent(context: common.Context): string {
    return LatexLibraryService.readLibrary(context)
  }

  static countEntries(context: common.Context): number {
    const content = LatexLibraryService.readLibrary(context)
    return LatexLibraryService.extractCiteKeys(content).length
  }

  static appendPapers(context: common.Context, papers: Array<Paper>): LatexAppendResult {
    const dir = LatexLibraryService.getLibraryDir(context)
    const path = LatexLibraryService.getLibraryPath(context)
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true)
      }
      let content = LatexLibraryService.readLibrary(context)
      const existingKeys = LatexLibraryService.extractCiteKeys(content)
      let added = 0
      let skipped = 0
      const parts: Array<string> = []
      for (let i = 0; i < papers.length; i++) {
        const entry = CitationService.generateCitation(papers[i], CitationFormat.BIBTEX)
        const key = LatexLibraryService.extractKeyFromEntry(entry)
        if (key.length === 0) {
          skipped++
          continue
        }
        if (existingKeys.indexOf(key) >= 0) {
          skipped++
          continue
        }
        existingKeys.push(key)
        parts.push(entry)
        added++
      }
      if (parts.length > 0) {
        if (content.length > 0 && !content.endsWith('\n')) {
          content += '\n'
        }
        content += parts.join('\n\n') + '\n'
        const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
        try {
          fs.writeSync(file.fd, content)
        } finally {
          fs.closeSync(file)
        }
      }
      return new LatexAppendResult(added, skipped)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Append to latex library failed: ${(e as Error).message}`)
      return new LatexAppendResult(0, 0)
    }
  }

  static saveLibraryToUri(context: common.Context, uri: string): boolean {
    try {
      const content = LatexLibraryService.readLibrary(context)
      const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      try {
        fs.writeSync(file.fd, content)
      } finally {
        fs.closeSync(file)
      }
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Save latex library failed: ${(e as Error).message}`)
      return false
    }
  }
}
