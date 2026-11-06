import { Category } from '../model/CategoryModel'
import { CategoryService } from '../service/CategoryService'

@Entry
@Component
struct CategoryManagePage {
  @State tags: Array<Category> = []
  @State folders: Array<Category> = []
  @State newTagName: string = ''
  @State newFolderName: string = ''
  @State tagColor: string = '#4A90D9'
  @State folderColor: string = '#E8913D'
  @State editingCategory: Category | undefined = undefined
  @State editName: string = ''
  private categoryService: CategoryService = new CategoryService()

  async aboutToAppear(): Promise<void> {
    await this.loadData()
  }

  async loadData(): Promise<void> {
    this.tags = await this.categoryService.getTags()
    this.folders = await this.categoryService.getFolders()
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(22)
          .onClick(() => {
            this.getUIContext().getRouter().back()
          })
        Text('分类管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('  ')
          .fontSize(22)
      }
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.SpaceBetween)

      Scroll() {
        Column({ space: 16 }) {
          this.FolderSection()
          this.TagSection()
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  FolderSection() {
    Column({ space: 8 }) {
      Text('文件夹')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)

      Row({ space: 8 }) {
        TextInput({ placeholder: '新文件夹名称', text: this.newFolderName })
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .onChange((v: string) => { this.newFolderName = v })

        Button('添加')
          .fontSize(14)
          .height(44)
          .backgroundColor(this.folderColor)
          .fontColor(Color.White)
          .borderRadius(8)
          .onClick(() => {
            this.addFolder()
          })
      }
      .width('100%')

      if (this.folders.length > 0) {
        List({ space: 4 }) {
          ForEach(this.folders, (folder: Category) => {
            ListItem() {
              Row() {
                Row()
                  .width(16)
                  .height(16)
                  .borderRadius(8)
                  .backgroundColor(folder.color)
                  .margin({ right: 8 })
                if (this.editingCategory !== undefined && this.editingCategory.id === folder.id) {
                  TextInput({ text: this.editName })
                    .layoutWeight(1)
                    .height(40)
                    .backgroundColor(Color.White)
                    .onChange((v: string) => { this.editName = v })
                  Text('保存')
                    .fontSize(14)
                    .fontColor('#4A90D9')
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.saveEdit(folder)
                    })
                } else {
                  Text(folder.name)
                    .fontSize(15)
                    .layoutWeight(1)
                  Text('编辑')
                    .fontSize(13)
                    .fontColor('#4A90D9')
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.startEdit(folder)
                    })
                  Text('删除')
                    .fontSize(13)
                    .fontColor('#D94444')
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.deleteCategory(folder.id)
                    })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Color.White)
              .borderRadius(8)
            }
          }, (folder: Category) => `${folder.id}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TagSection() {
    Column({ space: 8 }) {
      Text('标签')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)

      Row({ space: 8 }) {
        TextInput({ placeholder: '新标签名称', text: this.newTagName })
          .layoutWeight(1)
          .height(44)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .onChange((v: string) => { this.newTagName = v })

        Button('添加')
          .fontSize(14)
          .height(44)
          .backgroundColor(this.tagColor)
          .fontColor(Color.White)
          .borderRadius(8)
          .onClick(() => {
            this.addTag()
          })
      }
      .width('100%')

      Row({ space: 6 }) {
        Text('颜色:')
          .fontSize(14)
        ForEach(['#4A90D9', '#D94444', '#44B949', '#E8913D', '#9B59B6', '#1ABC9C'], (color: string) => {
          Row()
            .width(28)
            .height(28)
            .borderRadius(14)
            .backgroundColor(color)
            .border({ width: this.tagColor === color ? 3 : 0, color: '#333333', style: BorderStyle.Solid })
            .onClick(() => {
              this.tagColor = color
            })
        }, (color: string) => color)
      }
      .width('100%')

      if (this.tags.length > 0) {
        List({ space: 4 }) {
          ForEach(this.tags, (tag: Category) => {
            ListItem() {
              Row() {
                Row()
                  .width(16)
                  .height(16)
                  .borderRadius(8)
                  .backgroundColor(tag.color)
                  .margin({ right: 8 })
                if (this.editingCategory !== undefined && this.editingCategory.id === tag.id) {
                  TextInput({ text: this.editName })
                    .layoutWeight(1)
                    .height(40)
                    .backgroundColor(Color.White)
                    .onChange((v: string) => { this.editName = v })
                  Text('保存')
                    .fontSize(14)
                    .fontColor('#4A90D9')
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.saveEdit(tag)
                    })
                } else {
                  Text(tag.name)
                    .fontSize(15)
                    .layoutWeight(1)
                  Text('编辑')
                    .fontSize(13)
                    .fontColor('#4A90D9')
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.startEdit(tag)
                    })
                  Text('删除')
                    .fontSize(13)
                    .fontColor('#D94444')
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.deleteCategory(tag.id)
                    })
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Color.White)
              .borderRadius(8)
            }
          }, (tag: Category) => `${tag.id}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  private async addFolder(): Promise<void> {
    if (this.newFolderName.length === 0) {
      return
    }
    const folder = Category.createFolder(this.newFolderName, 0, this.folderColor)
    await this.categoryService.addCategory(folder)
    this.newFolderName = ''
    await this.loadData()
  }

  private async addTag(): Promise<void> {
    if (this.newTagName.length === 0) {
      return
    }
    const tag = Category.createTag(this.newTagName, this.tagColor)
    await this.categoryService.addCategory(tag)
    this.newTagName = ''
    await this.loadData()
  }

  private startEdit(category: Category): void {
    this.editingCategory = category
    this.editName = category.name
  }

  private async saveEdit(category: Category): Promise<void> {
    if (this.editName.length === 0) {
      return
    }
    category.name = this.editName
    await this.categoryService.updateCategory(category)
    this.editingCategory = undefined
    this.editName = ''
    await this.loadData()
  }

  private deleteCategory(categoryId: number): void {
    this.getUIContext().showAlertDialog({
      title: '确认删除',
      message: '删除分类会同时移除该分类与论文的关联，确定删除吗？',
      primaryButton: {
        value: '删除',
        fontColor: '#D94444',
        action: () => {
          this.doDeleteCategory(categoryId)
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  private async doDeleteCategory(categoryId: number): Promise<void> {
    await this.categoryService.deleteCategory(categoryId)
    await this.loadData()
  }
}
