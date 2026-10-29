import { Category } from '../models/Models';
import { Platform } from '../utils/Platform';
import { ControlMaterial } from '../utils/ControlMaterial';

// Selection is an observed component input. A captured @Builder boolean would
// leave the underline at its initial value in a retained HDS title builder.
@Component
struct HeaderTab {
  @Prop label: Resource = $r('app.string.recommended');
  @Prop selected: boolean = false;
  onSelect: () => void = (): void => {};
  build() {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 4 }) {
        Text(this.label).fontSize($r('sys.float.Title_S')).fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selected ? $r('app.color.accent') : $r('app.color.secondary'))
        Row().height(3).width(22).borderRadius(2).backgroundColor(this.selected ? $r('app.color.accent') : Color.Transparent)
      }.justifyContent(FlexAlign.Center).height($r('app.float.touch_target')).padding({ left: 8, right: 8 })
    }.backgroundColor(Color.Transparent).onClick((): void => this.onSelect())
      .accessibilityText(this.label).accessibilitySelected(this.selected)
  }
}

@Component
struct TintedFilterPill {
  @Prop label: ResourceStr = $r('app.string.all_categories');
  @Prop selected: boolean = false;
  @Prop tint: ResourceColor = $r('app.color.filter_violet');
  @StorageProp('afd.material') material: boolean = true;
  private chipMaterial: ControlMaterial = new ControlMaterial();
  onSelect: () => void = (): void => {};
  private usesMaterial(): boolean { return this.material && Platform.materialAvailable(); }
  build() {
    Button({ type: ButtonType.Normal }) {
      Text(this.label).fontSize(14).fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selected ? $r('app.color.accent') : $r('app.color.secondary')).maxLines(1)
    }.height(40).padding({ left: 16, right: 16 }).borderRadius(20)
      .backgroundColor(this.usesMaterial() ? Color.Transparent : this.tint)
      .attributeModifier(this.chipMaterial.modifier(this.usesMaterial(), false, this.tint))
      .onClick((): void => this.onSelect()).accessibilitySelected(this.selected)
  }
}

@Component
export struct RootTitleControls {
  @Link tab: number;
  @Link following: boolean;
  @Link keyword: string;
  @Link creatorType: string;
  @Link category: string;
  @Link categories: Category[];
  @StorageProp('afd.material') material: boolean = true;
  private editMaterial: ControlMaterial = new ControlMaterial();
  private searchMaterial: ControlMaterial = new ControlMaterial();
  onCompose: () => void = (): void => {};
  private usesMaterial(): boolean { return this.material && Platform.materialAvailable(); }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
    Row({ space: 8 }) {
      if (this.tab === 0) {
        HeaderTab({ label: $r('app.string.recommended'), selected: !this.following,
          onSelect: (): void => { this.following = false; } }).id('afd-home-recommended')
        HeaderTab({ label: $r('app.string.following'), selected: this.following,
          onSelect: (): void => { this.following = true; } }).id('afd-home-following')
        Blank()
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(22).fontColor([$r('app.color.accent')])
        }.width($r('app.float.touch_target')).height($r('app.float.touch_target'))
          .backgroundColor(this.usesMaterial() ? Color.Transparent : $r('app.color.surface')).clip(false)
          .attributeModifier(this.editMaterial.modifier(this.usesMaterial(), true))
          .accessibilityText($r('app.string.publish')).id('afd-compose-button')
          .onClick((): void => this.onCompose())
      } else if (this.tab === 1) {
        Stack() {
          Search({ value: this.keyword, placeholder: $r('app.string.search_local_hint') })
            .height('100%').width('100%').backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text')).placeholderColor($r('app.color.secondary'))
            .borderRadius($r('app.float.title_bar_search_radius')).clip(true)
            .onChange((value: string): void => { this.keyword = value; })
        }.height($r('app.float.title_bar_search_height')).width('100%')
          .backgroundColor(this.usesMaterial() ? Color.Transparent : $r('app.color.surface'))
          .borderRadius($r('app.float.title_bar_search_radius')).clip(false)
          .attributeModifier(this.searchMaterial.modifier(this.usesMaterial(), true)).id('afd-explore-search')
      } else {
        Text(this.tab === 2 ? $r('app.string.messages') : $r('app.string.profile')).fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text')).layoutWeight(1)
      }
    }.width('100%').height($r('app.float.native_title_bar_height'))
      .padding({ left: $r('app.float.page_padding'), right: $r('app.float.page_padding') })
    if (this.tab === 1) {
      RootExploreFilters({ type: $creatorType, category: $category, categories: $categories })
        .position({ x: 0, y: $r('app.float.native_title_bar_height') })
    }
    }.width('100%').height($r('app.float.native_title_bar_height')).clip(false).id('afd-root-title-controls')
  }
}

@Component
export struct RootExploreFilters {
  @Link type: string;
  @Link category: string;
  @Link categories: Category[];
  build() {
    Column() {
      Row({ space: 8 }) {
        HeaderTab({ label: $r('app.string.recommended'), selected: this.type === 'rec', onSelect: (): void => { this.type = 'rec'; } })
        HeaderTab({ label: $r('app.string.hot'), selected: this.type === 'hot', onSelect: (): void => { this.type = 'hot'; } })
        HeaderTab({ label: $r('app.string.newest'), selected: this.type === 'new', onSelect: (): void => { this.type = 'new'; } })
      }.width('100%').padding({ left: 16, right: 16 })
      Scroll() {
        Row({ space: 8 }) {
          TintedFilterPill({ label: $r('app.string.all_categories'), selected: this.category === '',
            tint: $r('app.color.filter_violet'), onSelect: (): void => { this.category = ''; } })
          ForEach(this.categories, (item: Category, index: number) => {
            TintedFilterPill({ label: item.name, selected: this.category === item.category_id,
              tint: index % 4 === 0 ? $r('app.color.filter_blue') : index % 4 === 1 ? $r('app.color.filter_pink') :
                index % 4 === 2 ? $r('app.color.filter_green') : $r('app.color.filter_orange'),
              onSelect: (): void => { this.category = item.category_id; } })
          }, (item: Category): string => item.category_id)
        }.padding({ left: 16, right: 16 })
      }.width('100%').height($r('app.float.touch_target')).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
    }.width('100%').height($r('app.float.explore_filter_height')).id('afd-explore-title-filters')
  }
}
