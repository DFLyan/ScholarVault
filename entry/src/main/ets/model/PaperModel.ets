export enum ReadStatus {
  UNREAD = 0,
  READING = 1,
  DONE = 2
}

export class ReadStatusHelper {
  static getLabel(status: ReadStatus): string {
    if (status === ReadStatus.UNREAD) {
      return '未读'
    }
    if (status === ReadStatus.READING) {
      return '在读'
    }
    return '已读'
  }

  static getColor(status: ReadStatus): string {
    if (status === ReadStatus.UNREAD) {
      return '#999999'
    }
    if (status === ReadStatus.READING) {
      return '#E8913D'
    }
    return '#44B949'
  }
}

export class Paper {
  id: number = 0
  title: string = ''
  authors: string = '[]'
  year: number = 0
  journal: string = ''
  doi: string = ''
  arxivId: string = ''
  abstract: string = ''
  keywords: string = '[]'
  pdfPath: string = ''
  thumbnailPath: string = ''
  dateAdded: number = 0
  dateModified: number = 0
  notes: string = ''
  readStatus: number = ReadStatus.UNREAD
  rating: number = 0
  isFavorite: number = 0
  isPinned: number = 0
  citationCount: number = -1
  lastReadPage: number = 0
  lastReadTime: number = 0
  sortOrder: number = 0

  static create(title: string, authors: string, year: number, journal: string, doi: string,
    arxivId: string, abstractVal: string, keywords: string, pdfPath: string): Paper {
    const p = new Paper()
    p.title = title
    p.authors = authors
    p.year = year
    p.journal = journal
    p.doi = doi
    p.arxivId = arxivId
    p.abstract = abstractVal
    p.keywords = keywords
    p.pdfPath = pdfPath
    const now = Date.now()
    p.dateAdded = now
    p.dateModified = now
    return p
  }

  getAuthorList(): Array<string> {
    try {
      return JSON.parse(this.authors) as Array<string>
    } catch (e) {
      return []
    }
  }

  getKeywordList(): Array<string> {
    try {
      return JSON.parse(this.keywords) as Array<string>
    } catch (e) {
      return []
    }
  }

  static authorsToString(authors: Array<string>): string {
    return JSON.stringify(authors)
  }

  static keywordsToString(keywords: Array<string>): string {
    return JSON.stringify(keywords)
  }
}
