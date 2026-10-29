@Component
export struct PostImageGrid {
  @Prop images: string[] = [];
  onOpen: (url: string) => void = (url: string): void => {};

  @Builder private Thumb(url: string, square: boolean) {
    Image(url).width('100%')
      .aspectRatio(square ? 1 : 4 / 3)
      .objectFit(ImageFit.Cover)
      .borderRadius(10)
      .clip(true)
      .onClick((): void => this.onOpen(url))
  }

  build() {
    if (this.images.length === 1) {
      this.Thumb(this.images[0], false)
    } else if (this.images.length === 2 || this.images.length === 3) {
      Row({ space: 6 }) {
        ForEach(this.images, (url: string) => {
          Column() { this.Thumb(url, true) }.layoutWeight(1)
        }, (url: string): string => url)
      }.width('100%')
    } else {
      GridRow({ columns: 3, gutter: { x: 6, y: 6 } }) {
        ForEach(this.images.slice(0, 9), (url: string) => {
          GridCol() { this.Thumb(url, true) }
        }, (url: string, index: number): string => url + ':' + index.toString())
      }.width('100%')
    }
  }
}
