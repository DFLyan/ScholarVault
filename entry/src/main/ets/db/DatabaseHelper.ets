import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Paper, ReadStatus } from '../model/PaperModel'
import { Category, PaperCategory } from '../model/CategoryModel'
import { PaperNote, ReaderNote, StatItem } from '../model/NoteModel'

const DOMAIN = 0x0000
const TAG = 'ScholarVaultDB'
const DB_NAME = 'scholarvault.db'
const DB_VERSION = 2

const CREATE_PAPERS_TABLE = `CREATE TABLE IF NOT EXISTS papers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL DEFAULT '',
  authors TEXT DEFAULT '[]',
  year INTEGER DEFAULT 0,
  journal TEXT DEFAULT '',
  doi TEXT DEFAULT '',
  arxivId TEXT DEFAULT '',
  abstract TEXT DEFAULT '',
  keywords TEXT DEFAULT '[]',
  pdfPath TEXT DEFAULT '',
  thumbnailPath TEXT DEFAULT '',
  dateAdded INTEGER DEFAULT 0,
  dateModified INTEGER DEFAULT 0,
  notes TEXT DEFAULT '',
  readStatus INTEGER DEFAULT 0,
  rating INTEGER DEFAULT 0,
  isFavorite INTEGER DEFAULT 0,
  isPinned INTEGER DEFAULT 0,
  citationCount INTEGER DEFAULT -1,
  lastReadPage INTEGER DEFAULT 0,
  lastReadTime INTEGER DEFAULT 0
)`

const CREATE_CATEGORIES_TABLE = `CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL DEFAULT '',
  type TEXT DEFAULT 'tag',
  color TEXT DEFAULT '#4A90D9',
  parentId INTEGER DEFAULT 0,
  sortOrder INTEGER DEFAULT 0
)`

const CREATE_PAPER_CATEGORIES_TABLE = `CREATE TABLE IF NOT EXISTS paper_categories (
  paperId INTEGER NOT NULL,
  categoryId INTEGER NOT NULL,
  PRIMARY KEY (paperId, categoryId)
)`

const CREATE_PAPER_NOTES_TABLE = `CREATE TABLE IF NOT EXISTS paper_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  paperId INTEGER NOT NULL,
  content TEXT DEFAULT '',
  createdAt INTEGER DEFAULT 0,
  modifiedAt INTEGER DEFAULT 0
)`

const CREATE_PDF_ANNOTATIONS_TABLE = `CREATE TABLE IF NOT EXISTS pdf_annotations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  paperId INTEGER NOT NULL,
  page INTEGER DEFAULT 0,
  content TEXT DEFAULT '',
  createdAt INTEGER DEFAULT 0
)`

const PAPER_NEW_COLUMNS: Array<Array<string>> = [
  ['readStatus', 'INTEGER DEFAULT 0'],
  ['rating', 'INTEGER DEFAULT 0'],
  ['isFavorite', 'INTEGER DEFAULT 0'],
  ['isPinned', 'INTEGER DEFAULT 0'],
  ['citationCount', 'INTEGER DEFAULT -1'],
  ['lastReadPage', 'INTEGER DEFAULT 0'],
  ['lastReadTime', 'INTEGER DEFAULT 0']
]

export class DatabaseHelper {
  private static instance: DatabaseHelper | undefined = undefined
  private store: relationalStore.RdbStore | undefined = undefined

  static getInstance(): DatabaseHelper {
    if (DatabaseHelper.instance === undefined) {
      DatabaseHelper.instance = new DatabaseHelper()
    }
    return DatabaseHelper.instance
  }

  async initDB(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }
    try {
      this.store = await relationalStore.getRdbStore(context, config)
      await this.store.executeSql(CREATE_PAPERS_TABLE)
      await this.store.executeSql(CREATE_CATEGORIES_TABLE)
      await this.store.executeSql(CREATE_PAPER_CATEGORIES_TABLE)
      await this.store.executeSql(CREATE_PAPER_NOTES_TABLE)
      await this.store.executeSql(CREATE_PDF_ANNOTATIONS_TABLE)
      await this.migratePapersTable()
      hilog.info(DOMAIN, TAG, 'Database initialized successfully, version: %d', DB_VERSION)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Database init failed: ${(e as Error).message}`)
    }
  }

  private async migratePapersTable(): Promise<void> {
    if (this.store === undefined) {
      return
    }
    for (let i = 0; i < PAPER_NEW_COLUMNS.length; i++) {
      const column = PAPER_NEW_COLUMNS[i]
      try {
        await this.store.executeSql(`ALTER TABLE papers ADD COLUMN ${column[0]} ${column[1]}`)
        hilog.info(DOMAIN, TAG, `Added column ${column[0]} to papers`)
      } catch (e) {
        // 列已存在时忽略
      }
    }
  }

  getStore(): relationalStore.RdbStore | undefined {
    return this.store
  }

  async insertPaper(paper: Paper): Promise<number> {
    if (this.store === undefined) {
      return -1
    }
    const valueBucket: relationalStore.ValuesBucket = {
      title: paper.title,
      authors: paper.authors,
      year: paper.year,
      journal: paper.journal,
      doi: paper.doi,
      arxivId: paper.arxivId,
      abstract: paper.abstract,
      keywords: paper.keywords,
      pdfPath: paper.pdfPath,
      thumbnailPath: paper.thumbnailPath,
      dateAdded: paper.dateAdded,
      dateModified: paper.dateModified,
      notes: paper.notes,
      readStatus: paper.readStatus,
      rating: paper.rating,
      isFavorite: paper.isFavorite,
      isPinned: paper.isPinned,
      citationCount: paper.citationCount,
      lastReadPage: paper.lastReadPage,
      lastReadTime: paper.lastReadTime
    }
    try {
      const rowId = await this.store.insert('papers', valueBucket)
      hilog.info(DOMAIN, TAG, `Inserted paper rowId: ${rowId}`)
      return rowId
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Insert paper failed: ${(e as Error).message}`)
      return -1
    }
  }

  async updatePaper(paper: Paper): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    paper.dateModified = Date.now()
    const valueBucket: relationalStore.ValuesBucket = {
      title: paper.title,
      authors: paper.authors,
      year: paper.year,
      journal: paper.journal,
      doi: paper.doi,
      arxivId: paper.arxivId,
      abstract: paper.abstract,
      keywords: paper.keywords,
      pdfPath: paper.pdfPath,
      thumbnailPath: paper.thumbnailPath,
      dateModified: paper.dateModified,
      notes: paper.notes,
      readStatus: paper.readStatus,
      rating: paper.rating,
      isFavorite: paper.isFavorite,
      isPinned: paper.isPinned,
      citationCount: paper.citationCount,
      lastReadPage: paper.lastReadPage,
      lastReadTime: paper.lastReadTime
    }
    const predicates = new relationalStore.RdbPredicates('papers')
    predicates.equalTo('id', paper.id)
    try {
      const rows = await this.store.update(valueBucket, predicates)
      return rows > 0
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Update paper failed: ${(e as Error).message}`)
      return false
    }
  }

  async updateReadStatus(paperId: number, readStatus: number): Promise<boolean> {
    return await this.updatePaperFields(paperId, {
      readStatus: readStatus,
      dateModified: Date.now()
    } as relationalStore.ValuesBucket)
  }

  async updateRating(paperId: number, rating: number): Promise<boolean> {
    return await this.updatePaperFields(paperId, {
      rating: rating,
      dateModified: Date.now()
    } as relationalStore.ValuesBucket)
  }

  async updateFavorite(paperId: number, isFavorite: number): Promise<boolean> {
    return await this.updatePaperFields(paperId, {
      isFavorite: isFavorite,
      dateModified: Date.now()
    } as relationalStore.ValuesBucket)
  }

  async updatePinned(paperId: number, isPinned: number): Promise<boolean> {
    return await this.updatePaperFields(paperId, {
      isPinned: isPinned,
      dateModified: Date.now()
    } as relationalStore.ValuesBucket)
  }

  async updateCitationCount(paperId: number, citationCount: number): Promise<boolean> {
    return await this.updatePaperFields(paperId, { citationCount: citationCount } as relationalStore.ValuesBucket)
  }

  async updateReadingProgress(paperId: number, lastReadPage: number, lastReadTime: number,
    readStatus: number): Promise<boolean> {
    return await this.updatePaperFields(paperId, {
      lastReadPage: lastReadPage,
      lastReadTime: lastReadTime,
      readStatus: readStatus,
      dateModified: Date.now()
    } as relationalStore.ValuesBucket)
  }

  private async updatePaperFields(paperId: number, valueBucket: relationalStore.ValuesBucket): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    const predicates = new relationalStore.RdbPredicates('papers')
    predicates.equalTo('id', paperId)
    try {
      const rows = await this.store.update(valueBucket, predicates)
      return rows > 0
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Update paper fields failed: ${(e as Error).message}`)
      return false
    }
  }

  async deletePaper(paperId: number): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    const predicates = new relationalStore.RdbPredicates('papers')
    predicates.equalTo('id', paperId)
    try {
      await this.store.delete(predicates)
      const catPredicates = new relationalStore.RdbPredicates('paper_categories')
      catPredicates.equalTo('paperId', paperId)
      await this.store.delete(catPredicates)
      const notePredicates = new relationalStore.RdbPredicates('paper_notes')
      notePredicates.equalTo('paperId', paperId)
      await this.store.delete(notePredicates)
      const annPredicates = new relationalStore.RdbPredicates('pdf_annotations')
      annPredicates.equalTo('paperId', paperId)
      await this.store.delete(annPredicates)
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Delete paper failed: ${(e as Error).message}`)
      return false
    }
  }

  async queryAllPapers(): Promise<Array<Paper>> {
    if (this.store === undefined) {
      return []
    }
    const predicates = new relationalStore.RdbPredicates('papers')
    predicates.orderByDesc('dateAdded')
    try {
      const resultSet = await this.store.query(predicates)
      return this.resultSetToPapers(resultSet)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Query papers failed: ${(e as Error).message}`)
      return []
    }
  }

  async searchPapers(query: string): Promise<Array<Paper>> {
    if (this.store === undefined) {
      return []
    }
    const escaped = query.replace(/[\\%_]/g, (ch: string): string => `\\${ch}`)
    const pattern = `%${escaped}%`
    const sql = `SELECT * FROM papers WHERE title LIKE ? ESCAPE '\\'` +
      ` OR authors LIKE ? ESCAPE '\\'` +
      ` OR journal LIKE ? ESCAPE '\\'` +
      ` OR doi LIKE ? ESCAPE '\\'` +
      ` OR arxivId LIKE ? ESCAPE '\\'` +
      ` OR abstract LIKE ? ESCAPE '\\'` +
      ` OR keywords LIKE ? ESCAPE '\\'` +
      ` ORDER BY dateAdded DESC`
    try {
      const resultSet = await this.store.querySql(sql,
        [pattern, pattern, pattern, pattern, pattern, pattern, pattern])
      return this.resultSetToPapers(resultSet)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Search papers failed: ${(e as Error).message}`)
      return []
    }
  }

  async queryPaperById(paperId: number): Promise<Paper | undefined> {
    if (this.store === undefined) {
      return undefined
    }
    const predicates = new relationalStore.RdbPredicates('papers')
    predicates.equalTo('id', paperId)
    try {
      const resultSet = await this.store.query(predicates)
      const papers = this.resultSetToPapers(resultSet)
      if (papers.length > 0) {
        return papers[0]
      }
      return undefined
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Query paper by id failed: ${(e as Error).message}`)
      return undefined
    }
  }

  async queryPapersByCategory(categoryId: number): Promise<Array<Paper>> {
    if (this.store === undefined) {
      return []
    }
    try {
      const sql = `SELECT p.* FROM papers p INNER JOIN paper_categories pc ON p.id = pc.paperId WHERE pc.categoryId = ? ORDER BY p.dateAdded DESC`
      const resultSet = await this.store.querySql(sql, [categoryId])
      return this.resultSetToPapers(resultSet)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Query papers by category failed: ${(e as Error).message}`)
      return []
    }
  }

  private resultSetToPapers(resultSet: relationalStore.ResultSet): Array<Paper> {
    const papers: Array<Paper> = []
    if (resultSet.rowCount === 0) {
      resultSet.close()
      return papers
    }
    resultSet.goToFirstRow()
    do {
      const paper = new Paper()
      paper.id = resultSet.getLong(resultSet.getColumnIndex('id'))
      paper.title = resultSet.getString(resultSet.getColumnIndex('title'))
      paper.authors = resultSet.getString(resultSet.getColumnIndex('authors'))
      paper.year = resultSet.getLong(resultSet.getColumnIndex('year'))
      paper.journal = resultSet.getString(resultSet.getColumnIndex('journal'))
      paper.doi = resultSet.getString(resultSet.getColumnIndex('doi'))
      paper.arxivId = resultSet.getString(resultSet.getColumnIndex('arxivId'))
      paper.abstract = resultSet.getString(resultSet.getColumnIndex('abstract'))
      paper.keywords = resultSet.getString(resultSet.getColumnIndex('keywords'))
      paper.pdfPath = resultSet.getString(resultSet.getColumnIndex('pdfPath'))
      paper.thumbnailPath = resultSet.getString(resultSet.getColumnIndex('thumbnailPath'))
      paper.dateAdded = resultSet.getLong(resultSet.getColumnIndex('dateAdded'))
      paper.dateModified = resultSet.getLong(resultSet.getColumnIndex('dateModified'))
      paper.notes = resultSet.getString(resultSet.getColumnIndex('notes'))
      const readStatusIdx = resultSet.getColumnIndex('readStatus')
      if (readStatusIdx >= 0) {
        paper.readStatus = resultSet.getLong(readStatusIdx)
      }
      const ratingIdx = resultSet.getColumnIndex('rating')
      if (ratingIdx >= 0) {
        paper.rating = resultSet.getLong(ratingIdx)
      }
      const favoriteIdx = resultSet.getColumnIndex('isFavorite')
      if (favoriteIdx >= 0) {
        paper.isFavorite = resultSet.getLong(favoriteIdx)
      }
      const pinnedIdx = resultSet.getColumnIndex('isPinned')
      if (pinnedIdx >= 0) {
        paper.isPinned = resultSet.getLong(pinnedIdx)
      }
      const citationIdx = resultSet.getColumnIndex('citationCount')
      if (citationIdx >= 0) {
        paper.citationCount = resultSet.getLong(citationIdx)
      }
      const lastPageIdx = resultSet.getColumnIndex('lastReadPage')
      if (lastPageIdx >= 0) {
        paper.lastReadPage = resultSet.getLong(lastPageIdx)
      }
      const lastTimeIdx = resultSet.getColumnIndex('lastReadTime')
      if (lastTimeIdx >= 0) {
        paper.lastReadTime = resultSet.getLong(lastTimeIdx)
      }
      papers.push(paper)
    } while (resultSet.goToNextRow())
    resultSet.close()
    return papers
  }

  async insertNote(note: PaperNote): Promise<number> {
    if (this.store === undefined) {
      return -1
    }
    const valueBucket: relationalStore.ValuesBucket = {
      paperId: note.paperId,
      content: note.content,
      createdAt: note.createdAt,
      modifiedAt: note.modifiedAt
    }
    try {
      return await this.store.insert('paper_notes', valueBucket)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Insert note failed: ${(e as Error).message}`)
      return -1
    }
  }

  async updateNote(note: PaperNote): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    note.modifiedAt = Date.now()
    const valueBucket: relationalStore.ValuesBucket = {
      content: note.content,
      modifiedAt: note.modifiedAt
    }
    const predicates = new relationalStore.RdbPredicates('paper_notes')
    predicates.equalTo('id', note.id)
    try {
      const rows = await this.store.update(valueBucket, predicates)
      return rows > 0
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Update note failed: ${(e as Error).message}`)
      return false
    }
  }

  async deleteNote(noteId: number): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    const predicates = new relationalStore.RdbPredicates('paper_notes')
    predicates.equalTo('id', noteId)
    try {
      await this.store.delete(predicates)
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Delete note failed: ${(e as Error).message}`)
      return false
    }
  }

  async queryNotesForPaper(paperId: number): Promise<Array<PaperNote>> {
    if (this.store === undefined) {
      return []
    }
    const predicates = new relationalStore.RdbPredicates('paper_notes')
    predicates.equalTo('paperId', paperId)
    predicates.orderByDesc('createdAt')
    try {
      const resultSet = await this.store.query(predicates)
      return this.resultSetToNotes(resultSet)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Query notes failed: ${(e as Error).message}`)
      return []
    }
  }

  async countAllNotes(): Promise<number> {
    if (this.store === undefined) {
      return 0
    }
    try {
      const resultSet = await this.store.querySql('SELECT COUNT(*) AS cnt FROM paper_notes')
      let count = 0
      if (resultSet.goToFirstRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('cnt'))
      }
      resultSet.close()
      return count
    } catch (e) {
      return 0
    }
  }

  private resultSetToNotes(resultSet: relationalStore.ResultSet): Array<PaperNote> {
    const notes: Array<PaperNote> = []
    if (resultSet.rowCount === 0) {
      resultSet.close()
      return notes
    }
    resultSet.goToFirstRow()
    do {
      const note = new PaperNote()
      note.id = resultSet.getLong(resultSet.getColumnIndex('id'))
      note.paperId = resultSet.getLong(resultSet.getColumnIndex('paperId'))
      note.content = resultSet.getString(resultSet.getColumnIndex('content'))
      note.createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'))
      note.modifiedAt = resultSet.getLong(resultSet.getColumnIndex('modifiedAt'))
      notes.push(note)
    } while (resultSet.goToNextRow())
    resultSet.close()
    return notes
  }

  async insertReaderNote(note: ReaderNote): Promise<number> {
    if (this.store === undefined) {
      return -1
    }
    const valueBucket: relationalStore.ValuesBucket = {
      paperId: note.paperId,
      page: note.page,
      content: note.content,
      createdAt: note.createdAt
    }
    try {
      return await this.store.insert('pdf_annotations', valueBucket)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Insert reader note failed: ${(e as Error).message}`)
      return -1
    }
  }

  async deleteReaderNote(noteId: number): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    const predicates = new relationalStore.RdbPredicates('pdf_annotations')
    predicates.equalTo('id', noteId)
    try {
      await this.store.delete(predicates)
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Delete reader note failed: ${(e as Error).message}`)
      return false
    }
  }

  async queryReaderNotes(paperId: number): Promise<Array<ReaderNote>> {
    if (this.store === undefined) {
      return []
    }
    const predicates = new relationalStore.RdbPredicates('pdf_annotations')
    predicates.equalTo('paperId', paperId)
    predicates.orderByAsc('page')
    try {
      const resultSet = await this.store.query(predicates)
      return this.resultSetToReaderNotes(resultSet)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Query reader notes failed: ${(e as Error).message}`)
      return []
    }
  }

  private resultSetToReaderNotes(resultSet: relationalStore.ResultSet): Array<ReaderNote> {
    const notes: Array<ReaderNote> = []
    if (resultSet.rowCount === 0) {
      resultSet.close()
      return notes
    }
    resultSet.goToFirstRow()
    do {
      const note = new ReaderNote()
      note.id = resultSet.getLong(resultSet.getColumnIndex('id'))
      note.paperId = resultSet.getLong(resultSet.getColumnIndex('paperId'))
      note.page = resultSet.getLong(resultSet.getColumnIndex('page'))
      note.content = resultSet.getString(resultSet.getColumnIndex('content'))
      note.createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'))
      notes.push(note)
    } while (resultSet.goToNextRow())
    resultSet.close()
    return notes
  }

  async getYearStats(): Promise<Array<StatItem>> {
    if (this.store === undefined) {
      return []
    }
    try {
      const resultSet = await this.store.querySql(
        `SELECT year AS name, COUNT(*) AS cnt FROM papers WHERE year > 0 GROUP BY year ORDER BY year DESC`)
      return this.resultSetToStatItems(resultSet)
    } catch (e) {
      return []
    }
  }

  async getJournalStats(limit: number): Promise<Array<StatItem>> {
    if (this.store === undefined) {
      return []
    }
    try {
      const resultSet = await this.store.querySql(
        `SELECT journal AS name, COUNT(*) AS cnt FROM papers WHERE journal != '' GROUP BY journal ORDER BY cnt DESC LIMIT ?`,
        [limit])
      return this.resultSetToStatItems(resultSet)
    } catch (e) {
      return []
    }
  }

  async getTagStats(limit: number): Promise<Array<StatItem>> {
    if (this.store === undefined) {
      return []
    }
    try {
      const resultSet = await this.store.querySql(
        `SELECT c.name AS name, COUNT(*) AS cnt FROM paper_categories pc INNER JOIN categories c ON pc.categoryId = c.id WHERE c.type = 'tag' GROUP BY pc.categoryId ORDER BY cnt DESC LIMIT ?`,
        [limit])
      return this.resultSetToStatItems(resultSet)
    } catch (e) {
      return []
    }
  }

  private resultSetToStatItems(resultSet: relationalStore.ResultSet): Array<StatItem> {
    const items: Array<StatItem> = []
    if (resultSet.rowCount === 0) {
      resultSet.close()
      return items
    }
    resultSet.goToFirstRow()
    do {
      items.push(new StatItem(resultSet.getString(resultSet.getColumnIndex('name')),
        resultSet.getLong(resultSet.getColumnIndex('cnt'))))
    } while (resultSet.goToNextRow())
    resultSet.close()
    return items
  }

  async insertCategory(category: Category): Promise<number> {
    if (this.store === undefined) {
      return -1
    }
    const valueBucket: relationalStore.ValuesBucket = {
      name: category.name,
      type: category.type,
      color: category.color,
      parentId: category.parentId,
      sortOrder: category.sortOrder
    }
    try {
      const rowId = await this.store.insert('categories', valueBucket)
      return rowId
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Insert category failed: ${(e as Error).message}`)
      return -1
    }
  }

  async updateCategory(category: Category): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    const valueBucket: relationalStore.ValuesBucket = {
      name: category.name,
      type: category.type,
      color: category.color,
      parentId: category.parentId,
      sortOrder: category.sortOrder
    }
    const predicates = new relationalStore.RdbPredicates('categories')
    predicates.equalTo('id', category.id)
    try {
      const rows = await this.store.update(valueBucket, predicates)
      return rows > 0
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Update category failed: ${(e as Error).message}`)
      return false
    }
  }

  async deleteCategory(categoryId: number): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    const predicates = new relationalStore.RdbPredicates('categories')
    predicates.equalTo('id', categoryId)
    try {
      await this.store.delete(predicates)
      const pcPredicates = new relationalStore.RdbPredicates('paper_categories')
      pcPredicates.equalTo('categoryId', categoryId)
      await this.store.delete(pcPredicates)
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Delete category failed: ${(e as Error).message}`)
      return false
    }
  }

  async queryAllCategories(): Promise<Array<Category>> {
    if (this.store === undefined) {
      return []
    }
    const predicates = new relationalStore.RdbPredicates('categories')
    predicates.orderByAsc('sortOrder')
    try {
      const resultSet = await this.store.query(predicates)
      return this.resultSetToCategories(resultSet)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Query categories failed: ${(e as Error).message}`)
      return []
    }
  }

  async queryCategoriesByType(type: string): Promise<Array<Category>> {
    if (this.store === undefined) {
      return []
    }
    const predicates = new relationalStore.RdbPredicates('categories')
    predicates.equalTo('type', type)
    predicates.orderByAsc('sortOrder')
    try {
      const resultSet = await this.store.query(predicates)
      return this.resultSetToCategories(resultSet)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Query categories by type failed: ${(e as Error).message}`)
      return []
    }
  }

  private resultSetToCategories(resultSet: relationalStore.ResultSet): Array<Category> {
    const categories: Array<Category> = []
    if (resultSet.rowCount === 0) {
      resultSet.close()
      return categories
    }
    resultSet.goToFirstRow()
    do {
      const cat = new Category()
      cat.id = resultSet.getLong(resultSet.getColumnIndex('id'))
      cat.name = resultSet.getString(resultSet.getColumnIndex('name'))
      cat.type = resultSet.getString(resultSet.getColumnIndex('type'))
      cat.color = resultSet.getString(resultSet.getColumnIndex('color'))
      cat.parentId = resultSet.getLong(resultSet.getColumnIndex('parentId'))
      cat.sortOrder = resultSet.getLong(resultSet.getColumnIndex('sortOrder'))
      categories.push(cat)
    } while (resultSet.goToNextRow())
    resultSet.close()
    return categories
  }

  async addPaperCategory(paperId: number, categoryId: number): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    const valueBucket: relationalStore.ValuesBucket = {
      paperId: paperId,
      categoryId: categoryId
    }
    try {
      await this.store.insert('paper_categories', valueBucket)
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Add paper category failed: ${(e as Error).message}`)
      return false
    }
  }

  async removePaperCategory(paperId: number, categoryId: number): Promise<boolean> {
    if (this.store === undefined) {
      return false
    }
    const predicates = new relationalStore.RdbPredicates('paper_categories')
    predicates.equalTo('paperId', paperId)
    predicates.equalTo('categoryId', categoryId)
    try {
      await this.store.delete(predicates)
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Remove paper category failed: ${(e as Error).message}`)
      return false
    }
  }

  async queryCategoriesForPaper(paperId: number): Promise<Array<Category>> {
    if (this.store === undefined) {
      return []
    }
    try {
      const sql = `SELECT c.* FROM categories c INNER JOIN paper_categories pc ON c.id = pc.categoryId WHERE pc.paperId = ? ORDER BY c.sortOrder`
      const resultSet = await this.store.querySql(sql, [paperId])
      return this.resultSetToCategories(resultSet)
    } catch (e) {
      hilog.error(DOMAIN, TAG, `Query categories for paper failed: ${(e as Error).message}`)
      return []
    }
  }

  async getPaperCountForCategory(categoryId: number): Promise<number> {
    if (this.store === undefined) {
      return 0
    }
    const predicates = new relationalStore.RdbPredicates('paper_categories')
    predicates.equalTo('categoryId', categoryId)
    try {
      const resultSet = await this.store.query(predicates)
      const count = resultSet.rowCount
      resultSet.close()
      return count
    } catch (e) {
      return 0
    }
  }
}
