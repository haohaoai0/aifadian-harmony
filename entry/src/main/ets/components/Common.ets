import { CreatorInfo, Post, User, plainText } from '../models/Models';

@Component
export struct StateView {
  @Prop loading: boolean = false;
  @Prop error: boolean = false;
  @Prop title: ResourceStr = $r('app.string.empty');
  onAction: () => void = (): void => {};
  build() {
    Column({ space: 16 }) {
      if (this.loading) { LoadingProgress().width(36).height(36).color($r('app.color.accent')) }
      else { SymbolGlyph(this.error ? $r('sys.symbol.wifi_badge_exclamationmark') : $r('sys.symbol.heart'))
        .fontSize(36).fontColor([$r('app.color.accent')]) }
      Text(this.loading ? $r('app.string.loading') : this.error ? $r('app.string.network_error') : this.title)
        .fontSize(15).fontColor($r('app.color.secondary')).textAlign(TextAlign.Center)
      if (this.error) { Button($r('app.string.retry')).onClick((): void => this.onAction()).backgroundColor($r('app.color.accent')) }
    }.width('100%').padding(32).constraintSize({ minHeight: 220 })
  }
}

@Component
export struct Avatar {
  @Prop src: string = '';
  @Prop diameter: number = 48;
  build() {
    if (this.src.length > 0) {
      Image(this.src).width(this.diameter).height(this.diameter).objectFit(ImageFit.Cover).borderRadius(this.diameter / 2)
        .backgroundColor($r('app.color.accent_soft'))
    } else {
      SymbolGlyph($r('sys.symbol.person_fill')).fontSize(this.diameter / 2).fontColor([$r('app.color.accent')])
        .width(this.diameter).height(this.diameter).borderRadius(this.diameter / 2).backgroundColor($r('app.color.accent_soft'))
    }
  }
}

@Component
export struct CreatorCard {
  @Prop user: User = new User();
  onOpen: (user: User) => void = (user: User): void => {};
  private price(): string {
    if (this.user.plan === undefined) { return ''; }
    const regular: string = this.user.plan.show_price ?? '';
    return regular.length > 0 ? regular : (this.user.plan.price ?? '');
  }
  private unit(): Resource {
    if (this.user.plan?.product_type === 1) { return $r('app.string.explore_item_unit'); }
    return $r('app.string.explore_month_unit');
  }
  build() {
    Button({ type: ButtonType.Normal }) {
      Column() {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.user.cover.length > 0) {
            Image(this.user.cover).width('100%').height(88).objectFit(ImageFit.Cover)
          } else {
            Column().width('100%').height(88).backgroundColor($r('app.color.accent_soft'))
          }
          Row({ space: 10 }) {
            Avatar({ src: this.user.avatar, diameter: 46 })
            Text(this.user.name).fontWeight(FontWeight.Bold).fontSize(16).fontColor($r('app.color.text'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          }.position({ x: 12, y: 64 }).width('100%').padding({ right: 12 })
        }.width('100%').height(88).clip(false)
        Column({ space: 8 }) {
          Text() {
            Span($r('app.string.explore_creating')).fontColor($r('app.color.secondary'))
            Span(this.user.creator?.doing || $r('app.string.creator')).fontColor($r('app.color.text'))
          }.fontSize(13).lineHeight(19).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').height(38).textAlign(TextAlign.Start)
          Text(this.user.creator?.category?.name || $r('app.string.creator')).fontSize(12)
            .fontColor($r('app.color.accent')).padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.accent_soft')).borderRadius(5).alignSelf(ItemAlign.Start)
          Blank()
          Divider().color($r('app.color.separator'))
          Row({ space: 5 }) {
            if (this.price().length > 0) {
              Text('¥' + this.price()).fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
              Text('/').fontSize(12).fontColor($r('app.color.secondary'))
              Text(this.unit()).fontSize(12).fontColor($r('app.color.secondary'))
              Text($r('app.string.explore_price_start')).fontSize(12).fontColor($r('app.color.secondary'))
            } else {
              Text($r('app.string.explore_view_plan')).fontSize(14).fontColor($r('app.color.accent'))
            }
          }.width('100%').alignItems(VerticalAlign.Bottom)
        }.width('100%').layoutWeight(1).padding({ left: 12, right: 12, top: 26, bottom: 10 }).alignItems(HorizontalAlign.Start)
      }.width('100%').height(252).backgroundColor($r('app.color.surface')).borderRadius($r('app.float.card_radius')).clip(true)
    }.width('100%').height(252).padding(0).backgroundColor(Color.Transparent)
      .onClick((): void => this.onOpen(this.user))
  }
}

@Component
export struct PostCard {
  @StorageProp('afd.height') heightVp: number = 800;
  @Prop post: Post = new Post();
  onOpen: (post: Post) => void = (post: Post): void => {};
  onUser: (id: string) => void = (id: string): void => {};
  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Avatar({ src: this.post.user?.avatar ?? '', diameter: 38 })
        Column({ space: 3 }) {
          Text(this.post.user?.name || $r('app.string.creator')).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          Text(this.post.publish_time > 0 ? new Date(this.post.publish_time * 1000).toLocaleDateString() : '')
            .fontSize(12).fontColor($r('app.color.secondary'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('app.color.secondary')])
      }.width('100%').onClick((): void => this.onUser(this.post.user_id))
      Column({ space: 10 }) {
        if (this.post.cover.length > 0) {
          Image(this.post.cover).width('100%').height(Math.min(190, this.heightVp * 0.32))
            .objectFit(ImageFit.Cover).borderRadius(14)
        }
        if (this.post.title.length > 0) {
          Text(this.post.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if ((this.post.preview_text || this.post.content).length > 0) {
          Text(plainText(this.post.preview_text || this.post.content)).fontSize(15).lineHeight(24)
            .fontColor($r('app.color.secondary')).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Row({ space: 6 }) {
          SymbolGlyph(this.post.has_right === 0 ? $r('sys.symbol.lock') : $r('sys.symbol.heart'))
            .fontSize(15).fontColor([$r('app.color.accent')])
          Text(this.post.like_count.toString()).fontSize(13).fontColor($r('app.color.secondary'))
          Blank()
          SymbolGlyph($r('sys.symbol.message')).fontSize(15).fontColor([$r('app.color.secondary')])
          Text(this.post.comment_count.toString()).fontSize(13).fontColor($r('app.color.secondary'))
        }.width('100%').margin({ top: 2 })
      }.alignItems(HorizontalAlign.Start).width('100%').onClick((): void => this.onOpen(this.post))
    }.width('100%').padding(18).backgroundColor($r('app.color.surface')).borderRadius(20)
  }
}
