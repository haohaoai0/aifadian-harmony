@Component
export struct MaterialSurfaceHost {
  @Prop surfaceHeight: number = 56;
  @Prop overflowMargin: number = 8;
  @BuilderParam surfaceContent: () => void = this.EmptyContent;
  @State private surfaceWidth: number = 0;

  @Builder private EmptyContent(): void {}

  @Builder private TitleContent(): void {
    Stack({ alignContent: Alignment.Center }) {
      Stack() { this.surfaceContent(); }
        .width('100%').height(this.surfaceHeight).clip(false)
    }.width('100%').height(this.surfaceHeight + this.overflowMargin * 2)
      .clip(false).hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Navigation() {
        Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      }
      .title({ builder: (): void => { this.TitleContent(); },
        height: this.surfaceHeight + this.overflowMargin * 2 }, {
        barStyle: BarStyle.STACK,
        backgroundColor: Color.Transparent,
        backgroundBlurStyle: BlurStyle.NONE
      })
      .titleMode(NavigationTitleMode.Full).mode(NavigationMode.Stack)
      .hideBackButton(true).hideToolBar(true)
      .width('calc(100% + ' + (this.overflowMargin * 2).toString() + 'vp)')
      .height(this.surfaceHeight + this.overflowMargin * 2)
      .position({ x: -this.overflowMargin, y: -this.overflowMargin })
      .responseRegion({ x: this.overflowMargin, y: this.overflowMargin,
        width: this.surfaceWidth, height: this.surfaceHeight })
      .backgroundColor(Color.Transparent).hitTestBehavior(HitTestMode.Transparent).clip(false)
    }.width('100%').height(this.surfaceHeight).clip(false).hitTestBehavior(HitTestMode.Transparent)
      .onAreaChange((_old: Area, area: Area): void => {
        const width: number = Number(area.width);
        if (width > 0 && width !== this.surfaceWidth) { this.surfaceWidth = width; }
      })
  }
}
