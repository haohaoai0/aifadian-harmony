import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { RouteParam } from '../models/Models';
import { navigationStyle } from '../utils/NavigationStyle';

@Component
export struct ImageViewerDestination {
  @Consume('pageStack') stack: NavPathStack;
  @Prop param: RouteParam = new RouteParam();
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.bottomInset') bottomInset: number = 0;
  private scroller: Scroller = new Scroller();

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Image(this.param.url)
          .width('100%')
          .objectFit(ImageFit.Fill)
          .backgroundColor(Color.Black)
          .onClick((): void => { this.stack.pop(); })
      }
      .width('100%').height('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(Color.Black)
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false,
      style: navigationStyle(this.material),
      content: { title: { mainTitle: this.param.title || $r('app.string.image_viewer') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .backgroundColor(Color.Black)
      .bindToScrollable([this.scroller])
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
  }
}
