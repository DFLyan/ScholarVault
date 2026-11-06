import { DatabaseHelper } from '../db/DatabaseHelper'
import { Category } from '../model/CategoryModel'

export class CategoryService {
  private db: DatabaseHelper = DatabaseHelper.getInstance()

  async getAllCategories(): Promise<Array<Category>> {
    return await this.db.queryAllCategories()
  }

  async getFolders(): Promise<Array<Category>> {
    return await this.db.queryCategoriesByType('folder')
  }

  async getTags(): Promise<Array<Category>> {
    return await this.db.queryCategoriesByType('tag')
  }

  async addCategory(category: Category): Promise<number> {
    return await this.db.insertCategory(category)
  }

  async updateCategory(category: Category): Promise<boolean> {
    return await this.db.updateCategory(category)
  }

  async deleteCategory(categoryId: number): Promise<boolean> {
    return await this.db.deleteCategory(categoryId)
  }

  async getPaperCountForCategory(categoryId: number): Promise<number> {
    return await this.db.getPaperCountForCategory(categoryId)
  }
}
