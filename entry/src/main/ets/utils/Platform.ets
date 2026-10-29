import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

export class Platform {
  static materialAvailable(): boolean { return deviceInfo.apiAvailable('26.0.0') && uiMaterial.isImmersiveMaterialSupported(); }
  static columns(width: number): number { return width >= 840 ? 3 : width >= 600 ? 2 : 1; }
}
