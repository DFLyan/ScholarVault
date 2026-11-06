import { Category } from '../model/CategoryModel'

@Component
export struct TagChip {
  @Prop category: Category = new Category()
  @Prop selected: boolean = false
  onTagClick: (categoryId: number) => void = (_categoryId: number) => {}

  build() {
    Text(this.category.name)
      .fontSize(13)
      .fontColor(this.selected ? Color.White : this.category.color)
      .backgroundColor(this.selected ? this.category.color : '#F0F0F0')
      .borderRadius(14)
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .border({ width: 1, color: this.category.color, style: BorderStyle.Solid })
      .onClick(() => {
        this.onTagClick(this.category.id)
      })
  }
}
