import { DatabaseHelper } from '../db/DatabaseHelper'
import { Paper } from '../model/PaperModel'
import { Category } from '../model/CategoryModel'
import { PaperNote, ReaderNote, StatItem } from '../model/NoteModel'

export class PaperService {
  private db: DatabaseHelper = DatabaseHelper.getInstance()

  async getAllPapers(): Promise<Array<Paper>> {
    return await this.db.queryAllPapers()
  }

  async searchPapers(query: string): Promise<Array<Paper>> {
    if (query.length === 0) {
      return await this.db.queryAllPapers()
    }
    return await this.db.searchPapers(query)
  }

  async getPaperById(paperId: number): Promise<Paper | undefined> {
    return await this.db.queryPaperById(paperId)
  }

  async getPapersByCategory(categoryId: number): Promise<Array<Paper>> {
    return await this.db.queryPapersByCategory(categoryId)
  }

  async addPaper(paper: Paper): Promise<number> {
    return await this.db.insertPaper(paper)
  }

  async updatePaper(paper: Paper): Promise<boolean> {
    return await this.db.updatePaper(paper)
  }

  async deletePaper(paperId: number): Promise<boolean> {
    return await this.db.deletePaper(paperId)
  }

  async updateReadStatus(paperId: number, readStatus: number): Promise<boolean> {
    return await this.db.updateReadStatus(paperId, readStatus)
  }

  async updateRating(paperId: number, rating: number): Promise<boolean> {
    return await this.db.updateRating(paperId, rating)
  }

  async updateFavorite(paperId: number, isFavorite: number): Promise<boolean> {
    return await this.db.updateFavorite(paperId, isFavorite)
  }

  async updatePinned(paperId: number, isPinned: number): Promise<boolean> {
    return await this.db.updatePinned(paperId, isPinned)
  }

  async updateCitationCount(paperId: number, citationCount: number): Promise<boolean> {
    return await this.db.updateCitationCount(paperId, citationCount)
  }

  async updateReadingProgress(paperId: number, lastReadPage: number, lastReadTime: number,
    readStatus: number): Promise<boolean> {
    return await this.db.updateReadingProgress(paperId, lastReadPage, lastReadTime, readStatus)
  }

  async getCategoriesForPaper(paperId: number): Promise<Array<Category>> {
    return await this.db.queryCategoriesForPaper(paperId)
  }

  async addPaperToCategory(paperId: number, categoryId: number): Promise<boolean> {
    return await this.db.addPaperCategory(paperId, categoryId)
  }

  async removePaperFromCategory(paperId: number, categoryId: number): Promise<boolean> {
    return await this.db.removePaperCategory(paperId, categoryId)
  }

  async getNotesForPaper(paperId: number): Promise<Array<PaperNote>> {
    return await this.db.queryNotesForPaper(paperId)
  }

  async addNote(note: PaperNote): Promise<number> {
    return await this.db.insertNote(note)
  }

  async updateNote(note: PaperNote): Promise<boolean> {
    return await this.db.updateNote(note)
  }

  async deleteNote(noteId: number): Promise<boolean> {
    return await this.db.deleteNote(noteId)
  }

  async countAllNotes(): Promise<number> {
    return await this.db.countAllNotes()
  }

  async getReaderNotes(paperId: number): Promise<Array<ReaderNote>> {
    return await this.db.queryReaderNotes(paperId)
  }

  async addReaderNote(note: ReaderNote): Promise<number> {
    return await this.db.insertReaderNote(note)
  }

  async deleteReaderNote(noteId: number): Promise<boolean> {
    return await this.db.deleteReaderNote(noteId)
  }

  async getYearStats(): Promise<Array<StatItem>> {
    return await this.db.getYearStats()
  }

  async getJournalStats(limit: number): Promise<Array<StatItem>> {
    return await this.db.getJournalStats(limit)
  }

  async getTagStats(limit: number): Promise<Array<StatItem>> {
    return await this.db.getTagStats(limit)
  }
}
