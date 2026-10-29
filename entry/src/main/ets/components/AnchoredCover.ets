@Component
export struct AnchoredCover {
  @Prop coverHeight: number = 170;
  @Prop pullOffset: number = 0;
  @Prop scrollOffset: number = 0;
  @BuilderParam coverBuilder: () => void = this.EmptyCover;

  @Builder private EmptyCover(): void {}

  private pullScale(): number {
    return 1 + Math.max(0, this.pullOffset) / Math.max(1, this.coverHeight);
  }

  build() {
    Stack() { this.coverBuilder() }
      .width('100%').height(this.coverHeight).clip(true).renderGroup(true)
      .scale({ x: this.pullScale(), y: this.pullScale(), centerX: '50%', centerY: 0 })
      .translate({ y: -Math.max(0, this.scrollOffset) })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }
}
