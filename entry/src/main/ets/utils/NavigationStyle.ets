import { HdsTitleBarContentStyle, TitleBarStyleOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

export function navigationStyle(material: boolean = true): TitleBarStyleOptions {
  const ink: HdsTitleBarContentStyle = {
    titleStyle: { mainTitleColor: $r('app.color.text'), subTitleColor: $r('app.color.secondary') },
    backIconStyle: { iconColor: $r('app.color.text') },
    menuStyle: { iconColor: $r('app.color.text') }
  };
  const options: TitleBarStyleOptions = {
    scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0), blurEffectiveEndOffset: LengthMetrics.vp(16) },
    originalStyle: { backgroundStyle: { backgroundColor: Color.Transparent }, contentStyle: ink },
    scrollEffectStyle: { backgroundStyle: { backgroundColor: $r('app.color.canvas') }, contentStyle: ink }
  };
  if (deviceInfo.apiAvailable('6.1.0(23)')) {
    options.scrollEffectOpts = { enableScrollEffect: true, scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0), blurEffectiveEndOffset: LengthMetrics.vp(16) };
    if (material) { options.systemMaterialEffect = {
      materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    }; }
  }
  return options;
}
