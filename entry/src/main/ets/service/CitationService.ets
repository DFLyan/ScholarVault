import { Paper } from '../model/PaperModel'
import { CitationFormat } from '../model/CitationStyle'

export class CitationService {
  static generateCitation(paper: Paper, format: CitationFormat): string {
    if (format === CitationFormat.BIBTEX) {
      return CitationService.generateBibTeX(paper)
    }
    if (format === CitationFormat.APA) {
      return CitationService.generateAPA(paper)
    }
    if (format === CitationFormat.MLA) {
      return CitationService.generateMLA(paper)
    }
    return CitationService.generateRIS(paper)
  }

  private static generateBibTeX(paper: Paper): string {
    const authors = paper.getAuthorList()
    const firstAuthor = authors.length > 0 ? authors[0] : 'Unknown'
    const key = firstAuthor.split(' ').pop() ?? firstAuthor
    const yearPart = paper.year > 0 ? `${paper.year}` : 'n.d.'
    const citeKey = `${key}${yearPart}`
    const authorStr = authors.join(' and ')
    let bibtex = `@article{${citeKey},\n`
    bibtex += `  title={${paper.title}},\n`
    bibtex += `  author={${authorStr}},\n`
    if (paper.year > 0) {
      bibtex += `  year={${paper.year}},\n`
    }
    if (paper.journal.length > 0) {
      bibtex += `  journal={${paper.journal}},\n`
    }
    if (paper.doi.length > 0) {
      bibtex += `  doi={${paper.doi}},\n`
    }
    if (paper.abstract.length > 0) {
      bibtex += `  abstract={${paper.abstract}},\n`
    }
    if (paper.keywords.length > 2) {
      const kw = paper.getKeywordList()
      if (kw.length > 0) {
        bibtex += `  keywords={${kw.join(', ')}},\n`
      }
    }
    bibtex += `}`
    return bibtex
  }

  private static generateAPA(paper: Paper): string {
    const authors = paper.getAuthorList()
    let authorPart = ''
    if (authors.length === 0) {
      authorPart = 'Unknown'
    } else if (authors.length === 1) {
      authorPart = authors[0]
    } else if (authors.length === 2) {
      authorPart = `${authors[0]} & ${authors[1]}`
    } else {
      const last = authors[authors.length - 1]
      authorPart = `${authors.slice(0, authors.length - 1).join(', ')}, & ${last}`
    }
    const yearPart = paper.year > 0 ? ` (${paper.year})` : ' (n.d.)'
    const titlePart = `. ${paper.title}.`
    const journalPart = paper.journal.length > 0 ? ` ${paper.journal}.` : ''
    const doiPart = paper.doi.length > 0 ? ` https://doi.org/${paper.doi}` : ''
    return `${authorPart}${yearPart}${titlePart}${journalPart}${doiPart}`
  }

  private static generateMLA(paper: Paper): string {
    const authors = paper.getAuthorList()
    let authorPart = ''
    if (authors.length === 0) {
      authorPart = 'Unknown'
    } else if (authors.length === 1) {
      authorPart = authors[0]
    } else if (authors.length === 2) {
      authorPart = `${authors[0]}, and ${authors[1]}`
    } else {
      authorPart = `${authors[0]}, et al.`
    }
    const titlePart = `"${paper.title}."`
    const journalPart = paper.journal.length > 0 ? ` ${paper.journal},` : ''
    const yearPart = paper.year > 0 ? ` ${paper.year}.` : '.'
    return `${authorPart} ${titlePart}${journalPart}${yearPart}`
  }

  private static generateRIS(paper: Paper): string {
    const lines: Array<string> = []
    lines.push('TY  - JOUR')
    lines.push(`TI  - ${paper.title}`)
    const authors = paper.getAuthorList()
    for (let i = 0; i < authors.length; i++) {
      lines.push(`AU  - ${authors[i]}`)
    }
    if (paper.year > 0) {
      lines.push(`PY  - ${paper.year}`)
    }
    if (paper.journal.length > 0) {
      lines.push(`JO  - ${paper.journal}`)
    }
    if (paper.doi.length > 0) {
      lines.push(`DO  - ${paper.doi}`)
    }
    if (paper.abstract.length > 0) {
      lines.push(`AB  - ${paper.abstract}`)
    }
    const kw = paper.getKeywordList()
    for (let i = 0; i < kw.length; i++) {
      lines.push(`KW  - ${kw[i]}`)
    }
    lines.push('ER  - ')
    return lines.join('\n')
  }

  static generateMultipleCitations(papers: Array<Paper>, format: CitationFormat): string {
    if (format === CitationFormat.RIS) {
      const parts: Array<string> = []
      for (let i = 0; i < papers.length; i++) {
        parts.push(CitationService.generateRIS(papers[i]))
      }
      return parts.join('\n')
    }
    const lines: Array<string> = []
    for (let i = 0; i < papers.length; i++) {
      lines.push(CitationService.generateCitation(papers[i], format))
      if (i < papers.length - 1) {
        lines.push('')
      }
    }
    return lines.join('\n')
  }
}
