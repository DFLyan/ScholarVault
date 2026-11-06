@Component
export struct SearchBar {
  @State searchText: string = ''
  placeholder: string = '搜索论文...'
  onSearch: (query: string) => void = (_query: string) => {}
  onTextChange: (text: string) => void = (_text: string) => {}

  build() {
    Row({ space: 8 }) {
      TextInput({ placeholder: this.placeholder, text: this.searchText })
        .layoutWeight(1)
        .height(40)
        .borderRadius(20)
        .backgroundColor('#F5F5F5')
        .onChange((value: string) => {
          this.searchText = value
          this.onTextChange(value)
        })
        .onSubmit(() => {
          this.onSearch(this.searchText)
        })

      if (this.searchText.length > 0) {
        Text('✕')
          .fontSize(16)
          .fontColor('#999999')
          .onClick(() => {
            this.searchText = ''
            this.onTextChange('')
            this.onSearch('')
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}
