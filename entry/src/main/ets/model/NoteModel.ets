export class PaperNote {
  id: number = 0
  paperId: number = 0
  content: string = ''
  createdAt: number = 0
  modifiedAt: number = 0

  static create(paperId: number, content: string): PaperNote {
    const n = new PaperNote()
    n.paperId = paperId
    n.content = content
    const now = Date.now()
    n.createdAt = now
    n.modifiedAt = now
    return n
  }
}

export class ReaderNote {
  id: number = 0
  paperId: number = 0
  page: number = 0
  content: string = ''
  createdAt: number = 0

  static create(paperId: number, page: number, content: string): ReaderNote {
    const n = new ReaderNote()
    n.paperId = paperId
    n.page = page
    n.content = content
    n.createdAt = Date.now()
    return n
  }
}

export class StatItem {
  name: string = ''
  count: number = 0

  constructor(name: string, count: number) {
    this.name = name
    this.count = count
  }
}
