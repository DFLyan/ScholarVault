export class Category {
  id: number = 0
  name: string = ''
  type: string = 'tag'
  color: string = '#4A90D9'
  parentId: number = 0
  sortOrder: number = 0

  static createFolder(name: string, parentId: number, color: string): Category {
    const c = new Category()
    c.name = name
    c.type = 'folder'
    c.parentId = parentId
    c.color = color
    return c
  }

  static createTag(name: string, color: string): Category {
    const c = new Category()
    c.name = name
    c.type = 'tag'
    c.color = color
    return c
  }

  isFolder(): boolean {
    return this.type === 'folder'
  }

  isTag(): boolean {
    return this.type === 'tag'
  }
}

export class PaperCategory {
  paperId: number = 0
  categoryId: number = 0

  static create(paperId: number, categoryId: number): PaperCategory {
    const pc = new PaperCategory()
    pc.paperId = paperId
    pc.categoryId = categoryId
    return pc
  }
}
