import { Paper } from '../model/PaperModel'

export class DuplicateGroup {
  papers: Array<Paper> = []
  reason: string = ''

  constructor(papers: Array<Paper>, reason: string) {
    this.papers = papers
    this.reason = reason
  }
}

export class DuplicateService {
  static normalizeTitle(title: string): string {
    return title.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fa5]/g, '')
  }

  static findDuplicates(papers: Array<Paper>): Array<DuplicateGroup> {
    const groups: Array<DuplicateGroup> = []
    const reportedSets: Array<string> = []

    const doiMap = new Map<string, Array<Paper>>()
    for (let i = 0; i < papers.length; i++) {
      const doi = papers[i].doi.trim().toLowerCase()
      if (doi.length === 0) {
        continue
      }
      const existing = doiMap.get(doi)
      if (existing === undefined) {
        doiMap.set(doi, [papers[i]])
      } else {
        existing.push(papers[i])
      }
    }
    doiMap.forEach((groupPapers: Array<Paper>, doi: string) => {
      if (groupPapers.length > 1) {
        groups.push(new DuplicateGroup(groupPapers, 'DOI 相同'))
        reportedSets.push(DuplicateService.makeSetKey(groupPapers))
      }
    })

    const titleMap = new Map<string, Array<Paper>>()
    for (let i = 0; i < papers.length; i++) {
      const normalized = DuplicateService.normalizeTitle(papers[i].title)
      if (normalized.length === 0) {
        continue
      }
      const existing = titleMap.get(normalized)
      if (existing === undefined) {
        titleMap.set(normalized, [papers[i]])
      } else {
        existing.push(papers[i])
      }
    }
    titleMap.forEach((groupPapers: Array<Paper>, normalized: string) => {
      if (groupPapers.length > 1) {
        const setKey = DuplicateService.makeSetKey(groupPapers)
        if (reportedSets.indexOf(setKey) < 0) {
          groups.push(new DuplicateGroup(groupPapers, '标题相同'))
        }
      }
    })

    return groups
  }

  private static makeSetKey(papers: Array<Paper>): string {
    const ids = papers.map((p: Paper): number => p.id)
    ids.sort((a: number, b: number): number => a - b)
    return ids.join(',')
  }

  static findDuplicateOf(title: string, doi: string, papers: Array<Paper>): Paper | undefined {
    const normalizedDoi = doi.trim().toLowerCase()
    const normalizedTitle = DuplicateService.normalizeTitle(title)
    for (let i = 0; i < papers.length; i++) {
      const paper = papers[i]
      if (normalizedDoi.length > 0 && paper.doi.trim().toLowerCase() === normalizedDoi) {
        return paper
      }
      if (normalizedTitle.length > 0 &&
        DuplicateService.normalizeTitle(paper.title) === normalizedTitle) {
        return paper
      }
    }
    return undefined
  }
}
