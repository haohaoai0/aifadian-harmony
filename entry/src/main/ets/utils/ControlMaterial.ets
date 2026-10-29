import { CommonModifier, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

class ControlMaterialAttribute extends CommonModifier {
  private effect: uiMaterial.Material | undefined;
  constructor(effect: uiMaterial.Material | undefined) { super(); this.effect = effect; }
  applyNormalAttribute(instance: CommonAttribute): void {
    if (deviceInfo.apiAvailable('26.0.0')) {
      instance.systemMaterial(this.effect ?? uiMaterial.Material.empty);
    }
  }
}

// Keep the native material instance while title state, focus and query text change.
// Matches HarmonyX TitleBarControlMaterialCache: THIN, interactive and color inversion.
export class ControlMaterial {
  private cached: uiMaterial.Material | undefined = undefined;
  private cachedTint: ResourceColor | undefined = undefined;
  modifier(active: boolean, shadow: boolean = false, tint: ResourceColor | undefined = undefined): CommonModifier {
    if (active && deviceInfo.apiAvailable('26.0.0') && uiMaterial.isImmersiveMaterialSupported()) {
      if (this.cached === undefined || this.cachedTint !== tint) {
        this.cached = new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.THIN,
          interactive: true, colorInvert: tint === undefined, applyShadow: shadow, materialColor: tint,
          lightEffect: { color: $r('app.color.accent') } });
        this.cachedTint = tint;
      }
      return new ControlMaterialAttribute(this.cached);
    }
    return new ControlMaterialAttribute(undefined);
  }
}
