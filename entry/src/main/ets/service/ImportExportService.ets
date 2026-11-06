import { Paper } from '../model/PaperModel'

export class BibTeXEntry {
  entryType: string = 'article'
  title: string = ''
  authors: Array<string> = []
  year: number = 0
  journal: string = ''
  doi: string = ''
  abstract: string = ''
  keywords: Array<string> = []

  toPaper(): Paper {
    const paper = new Paper()
    paper.title = this.title
    paper.authors = Paper.authorsToString(this.authors)
    paper.year = this.year
    paper.journal = this.journal
    paper.doi = this.doi
    paper.abstract = this.abstract
    paper.keywords = Paper.keywordsToString(this.keywords)
    const now = Date.now()
    paper.dateAdded = now
    paper.dateModified = now
    return paper
  }
}

export class ImportSummary {
  imported: number = 0
  duplicates: number = 0
  failed: number = 0

  constructor(imported: number, duplicates: number, failed: number) {
    this.imported = imported
    this.duplicates = duplicates
    this.failed = failed
  }
}

export class ImportExportService {
  static detectFormat(content: string): string {
    const trimmed = content.trim()
    if (trimmed.startsWith('@')) {
      return 'bibtex'
    }
    if (trimmed.indexOf('TY  -') >= 0 || trimmed.indexOf('TY  - ') >= 0) {
      return 'ris'
    }
    return 'unknown'
  }

  static parseBibTeX(content: string): Array<Paper> {
    const papers: Array<Paper> = []
    const entryRegex = /@([a-zA-Z]+)\s*\{/g
    let match = entryRegex.exec(content)
    while (match !== null) {
      const entryType = match[1].toLowerCase()
      const bodyStart = match.index + match[0].length
      const bodyResult = ImportExportService.extractBalancedBody(content, bodyStart)
      if (bodyResult === undefined) {
        break
      }
      if (entryType !== 'comment' && entryType !== 'string' && entryType !== 'preamble') {
        const entry = ImportExportService.parseBibTeXBody(bodyResult.body, entryType)
        if (entry.title.length > 0) {
          papers.push(entry.toPaper())
        }
      }
      entryRegex.lastIndex = bodyResult.endIndex
      match = entryRegex.exec(content)
    }
    return papers
  }

  private static extractBalancedBody(content: string, startIndex: number): BibTeXBody | undefined {
    let depth = 1
    let pos = startIndex
    while (pos < content.length) {
      const ch = content.charAt(pos)
      if (ch === '{') {
        depth++
      } else if (ch === '}') {
        depth--
        if (depth === 0) {
          return new BibTeXBody(content.substring(startIndex, pos), pos + 1)
        }
      }
      pos++
    }
    return undefined
  }

  private static parseBibTeXBody(body: string, entryType: string): BibTeXEntry {
    const entry = new BibTeXEntry()
    entry.entryType = entryType
    const fieldRegex = /([a-zA-Z]+)\s*=\s*(?:\{((?:[^{}]|\{[^{}]*\})*)\}|"([^"]*)")/g
    let fieldMatch = fieldRegex.exec(body)
    while (fieldMatch !== null) {
      const key = fieldMatch[1].toLowerCase()
      const value = (fieldMatch[2] !== undefined ? fieldMatch[2] : fieldMatch[3]) ?? ''
      ImportExportService.applyBibTeXField(entry, key, value)
      fieldMatch = fieldRegex.exec(body)
    }
    return entry
  }

  private static applyBibTeXField(entry: BibTeXEntry, key: string, value: string): void {
    if (key === 'title' || key === 'chapter') {
      entry.title = ImportExportService.cleanLatex(value)
    } else if (key === 'author' || key === 'editor') {
      if (entry.authors.length === 0) {
        const parts = value.split(/\s+and\s+/i)
        for (let i = 0; i < parts.length; i++) {
          const name = ImportExportService.cleanLatex(parts[i]).trim()
          if (name.length > 0) {
            entry.authors.push(name)
          }
        }
      }
    } else if (key === 'year' || key === 'date') {
      const yearMatch = value.match(/\d{4}/)
      if (yearMatch !== null) {
        entry.year = parseInt(yearMatch[0], 10)
      }
    } else if (key === 'journal' || key === 'journaltitle' || key === 'booktitle') {
      if (entry.journal.length === 0) {
        entry.journal = ImportExportService.cleanLatex(value)
      }
    } else if (key === 'doi') {
      entry.doi = value.trim()
    } else if (key === 'abstract') {
      entry.abstract = ImportExportService.cleanLatex(value)
    } else if (key === 'keywords') {
      const parts = value.split(',')
      for (let i = 0; i < parts.length; i++) {
        const kw = ImportExportService.cleanLatex(parts[i]).trim()
        if (kw.length > 0) {
          entry.keywords.push(kw)
        }
      }
    }
  }

  private static cleanLatex(text: string): string {
    return text.replace(/[{}]/g, '').replace(/\\[a-zA-Z]+/g, '').replace(/\s+/g, ' ').trim()
  }

  static parseRIS(content: string): Array<Paper> {
    const papers: Array<Paper> = []
    const blocks = content.split(/\n\s*ER\s{2,}-/)
    for (let i = 0; i < blocks.length; i++) {
      const block = blocks[i].trim()
      if (block.length === 0) {
        continue
      }
      const paper = ImportExportService.parseRISBlock(block)
      if (paper !== undefined && paper.title.length > 0) {
        papers.push(paper)
      }
    }
    return papers
  }

  private static parseRISBlock(block: string): Paper | undefined {
    const lines = block.split('\n')
    const titleParts: Array<string> = []
    const authors: Array<string> = []
    const journalParts: Array<string> = []
    const keywordParts: Array<string> = []
    const abstractParts: Array<string> = []
    let year = 0
    let doi = ''
    for (let i = 0; i < lines.length; i++) {
      const lineMatch = lines[i].match(/^([A-Z][A-Z0-9])\s{2,}-\s?(.*)$/)
      if (lineMatch === null || lineMatch.length < 3) {
        continue
      }
      const tag = lineMatch[1]
      const value = lineMatch[2].trim()
      if (tag === 'TI' || tag === 'T1') {
        titleParts.push(value)
      } else if (tag === 'AU' || tag === 'A1') {
        if (value.length > 0) {
          authors.push(value)
        }
      } else if (tag === 'JO' || tag === 'JF' || tag === 'T2') {
        journalParts.push(value)
      } else if (tag === 'PY' || tag === 'Y1') {
        const yearMatch = value.match(/\d{4}/)
        if (yearMatch !== null && yearMatch.length > 0 && year === 0) {
          year = parseInt(yearMatch[0], 10)
        }
      } else if (tag === 'DO') {
        doi = value
      } else if (tag === 'AB' || tag === 'N2') {
        abstractParts.push(value)
      } else if (tag === 'KW') {
        if (value.length > 0) {
          keywordParts.push(value)
        }
      }
    }
    if (titleParts.length === 0) {
      return undefined
    }
    const paper = new Paper()
    paper.title = titleParts.join(' ')
    paper.authors = Paper.authorsToString(authors)
    paper.year = year
    paper.journal = journalParts.length > 0 ? journalParts[0] : ''
    paper.doi = doi
    paper.abstract = abstractParts.join(' ')
    paper.keywords = Paper.keywordsToString(keywordParts)
    const now = Date.now()
    paper.dateAdded = now
    paper.dateModified = now
    return paper
  }
}

class BibTeXBody {
  body: string = ''
  endIndex: number = 0

  constructor(body: string, endIndex: number) {
    this.body = body
    this.endIndex = endIndex
  }
}
