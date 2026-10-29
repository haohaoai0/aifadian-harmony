import { Platform } from '../utils/Platform';
import { ControlMaterial } from '../utils/ControlMaterial';
import { MaterialSurfaceHost } from './MaterialSurfaceHost';
import { hdsEffect } from '@kit.UIDesignKit';

const FAB_SIZE: number = 56;
const FAB_SIDE_MARGIN: number = 16;
const TAB_BAR_HEIGHT: number = 56;
const FAB_BAR_GAP: number = 24;

@Component
export struct FloatingComposeButton {
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.bottomInset') bottomInset: number = 0;
  @State private areaWidth: number = 0;
  @State private areaHeight: number = 0;
  @State private buttonX: number = FAB_SIDE_MARGIN;
  @State private buttonY: number = 0;
  @State private pressed: boolean = false;
  @State private pointLightActive: boolean = false;
  @State private isDragging: boolean = false;
  private initialX: number = 0;
  private initialY: number = 0;
  private manualPosition: boolean = false;
  private moved: boolean = false;
  private composeMaterial: ControlMaterial = new ControlMaterial();
  onCompose: () => void = (): void => {};

  private usesMaterial(): boolean { return this.material && Platform.materialAvailable(); }
  private defaultX(): number { return Math.max(FAB_SIDE_MARGIN, this.areaWidth - FAB_SIZE - FAB_SIDE_MARGIN); }
  private defaultY(): number {
    return Math.max(12, this.areaHeight - FAB_SIZE - TAB_BAR_HEIGHT - FAB_BAR_GAP - Math.max(0, this.bottomInset));
  }
  private clampX(value: number): number { return Math.min(Math.max(0, value), Math.max(0, this.areaWidth - FAB_SIZE)); }
  private clampY(value: number): number { return Math.min(Math.max(0, value), Math.max(0, this.areaHeight - FAB_SIZE)); }
  private updateArea(width: number, height: number): void {
    this.areaWidth = width; this.areaHeight = height;
    if (this.manualPosition) {
      this.buttonX = this.clampX(this.buttonX); this.buttonY = this.clampY(this.buttonY);
    } else {
      this.buttonX = this.defaultX(); this.buttonY = this.defaultY();
    }
  }
  private panStart(): void {
    this.initialX = this.buttonX; this.initialY = this.buttonY;
    this.pressed = true; this.isDragging = true; this.pointLightActive = true; this.moved = false;
  }
  private panUpdate(event: GestureEvent): void {
    this.manualPosition = true;
    this.moved = true;
    this.buttonX = this.clampX(this.initialX + event.offsetX);
    this.buttonY = this.clampY(this.initialY + event.offsetY);
  }
  private panEnd(): void {
    this.pressed = false; this.isDragging = false; this.pointLightActive = false;
    setTimeout((): void => { this.moved = false; }, 120);
  }
  private click(): void {
    if (this.moved) { this.moved = false; return; }
    this.onCompose();
  }
  @Builder private ComposeContent() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(FAB_SIZE).height(FAB_SIZE).borderRadius(FAB_SIZE / 2)
        .backgroundColor(this.usesMaterial() ? Color.Transparent : $r('app.color.accent'))
        .attributeModifier(this.composeMaterial.modifier(this.usesMaterial(), true, '#CC946CE6'))
      SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(24).fontColor([Color.White])
    }.width(FAB_SIZE).height(FAB_SIZE).borderRadius(FAB_SIZE / 2).clip(false)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.Center }) {
      if (this.usesMaterial()) {
        MaterialSurfaceHost({ surfaceHeight: FAB_SIZE, overflowMargin: 8,
          surfaceContent: (): void => { this.ComposeContent(); } })
          .width(FAB_SIZE).height(FAB_SIZE)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Column().width(FAB_SIZE).height(FAB_SIZE).borderRadius(FAB_SIZE / 2)
            .backgroundColor($r('app.color.accent'))
          SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(24).fontColor([Color.White])
        }.width(FAB_SIZE).height(FAB_SIZE).borderRadius(FAB_SIZE / 2).clip(false)
      }
      }.width(FAB_SIZE).height(FAB_SIZE).borderRadius(FAB_SIZE / 2).clip(false)
        .accessibilityText($r('app.string.compose_new_post'))
        .position({ x: this.buttonX, y: this.buttonY })
        .scale({ x: this.isDragging ? 1.08 : this.pressed ? 0.94 : 1,
          y: this.isDragging ? 1.08 : this.pressed ? 0.94 : 1 })
        .shadow({ radius: this.pointLightActive ? 20 : 12,
          color: this.pointLightActive ? '#80946CE6' : '#40946CE6', offsetY: 4 })
        .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({
          sourceType: this.pointLightActive ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
          illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
        }).buildEffect())
        .animation({ duration: 160, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent): void => {
          const down: boolean = event.type === TouchType.Down;
          this.pressed = down;
          this.pointLightActive = down;
        })
        .onClick((): void => this.click())
        .gesture(PanGesture({ fingers: 1, direction: PanDirection.All })
          .onActionStart((): void => this.panStart())
          .onActionUpdate((event: GestureEvent): void => this.panUpdate(event))
          .onActionEnd((): void => this.panEnd())
          .onActionCancel((): void => this.panEnd()))
    }.width('100%').height('100%').clip(false).hitTestBehavior(HitTestMode.Transparent)
      .onAreaChange((_old: Area, area: Area): void => {
        this.updateArea(Number(area.width), Number(area.height));
      })
  }
}
