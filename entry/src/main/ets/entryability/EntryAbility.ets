import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { appStore } from '../services/AppStore';
import { trustedSite } from '../common/UrlPolicy';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined;
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    appStore.init(this.context);
    AppStorage.setOrCreate<boolean>('afd.dark', this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    this.handleWant(want);
  }
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void { this.handleWant(want); }
  onForeground(): void { AppStorage.setOrCreate<boolean>('afd.foreground', true); }
  onBackground(): void { AppStorage.setOrCreate<boolean>('afd.foreground', false); }
  private handleWant(want: Want): void { if (want.uri && trustedSite(want.uri)) { AppStorage.setOrCreate<string>('afd.pendingUrl', want.uri); } }
  onWindowStageCreate(stage: window.WindowStage): void {
    this.mainWindow = stage.getMainWindowSync();
    this.mainWindow.setWindowLayoutFullScreen(true).catch((): void => {});
    this.restoreSessionAndLoad(stage);
  }
  private async restoreSessionAndLoad(stage: window.WindowStage): Promise<void> {
    try { await appStore.restoreSession(); } catch (error) {}
    stage.loadContent('pages/Index', (error): void => {
      if (error.code) { hilog.error(0xFF00, 'Aifadian', 'Unable to load app: %{public}d', error.code); return; }
      this.publishMetrics();
      this.mainWindow?.on('windowSizeChange', (): void => this.publishMetrics());
      this.mainWindow?.on('avoidAreaChange', (): void => this.publishMetrics());
    });
  }
  private publishMetrics(): void {
    if (this.mainWindow === undefined) { return; }
    const ui = this.mainWindow.getUIContext();
    const rect: window.Rect = this.mainWindow.getWindowProperties().windowRect;
    AppStorage.setOrCreate<number>('afd.width', ui.px2vp(rect.width));
    AppStorage.setOrCreate<number>('afd.height', ui.px2vp(rect.height));
    const top: window.AvoidArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const bottom: window.AvoidArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    AppStorage.setOrCreate<number>('afd.topInset', ui.px2vp(top.topRect.height));
    AppStorage.setOrCreate<number>('afd.bottomInset', ui.px2vp(bottom.bottomRect.height));
  }
  onConfigurationUpdate(config: Configuration): void {
    AppStorage.setOrCreate<boolean>('afd.dark', config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }
  onWindowStageDestroy(): void {
    this.mainWindow?.off('windowSizeChange'); this.mainWindow?.off('avoidAreaChange'); this.mainWindow = undefined;
  }
}
