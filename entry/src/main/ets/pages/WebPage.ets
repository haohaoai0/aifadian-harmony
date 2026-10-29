import { common } from '@kit.AbilityKit';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { webview } from '@kit.ArkWeb';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { appStore } from '../services/AppStore';
import { afdianApi } from '../services/AfdianApi';
import { RouteParam } from '../models/Models';
import { BASE_URL, trustedSite, paymentLink, paymentSite } from '../common/UrlPolicy';
import { navigationStyle } from '../utils/NavigationStyle';

@Component
export struct WebDestination {
  @Consume('pageStack') stack: NavPathStack;
  @Prop param: RouteParam = new RouteParam();
  @StorageProp('afd.material') material: boolean = true;
  @State address: string = '';
  @State progress: number = 0;
  @State importing: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private confirming: boolean = false;
  private sharing: boolean = false;
  private disposed: boolean = false;
  private text(resource: Resource): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? '';
  }
  aboutToAppear(): void { this.prepare(); }
  aboutToDisappear(): void { this.disposed = true; }
  private async prepare(): Promise<void> {
    if (!trustedSite(this.param.url)) { this.address = BASE_URL; return; }
    try { await appStore.syncWebCookies(); } catch (error) {}
    if (!this.disposed) { this.address = this.param.url; }
  }
  private intercept(value: string): boolean {
    if (trustedSite(value) || paymentSite(value) || value === 'about:blank') { return false; }
    if (paymentLink(value) || /^https:\/\//i.test(value)) { this.external(value); }
    return true;
  }
  private external(value: string): void {
    if (this.confirming || this.disposed) { return; } this.confirming = true;
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.external_link'), message: $r('app.string.external_hint'),
      buttons: [{ text: $r('app.string.cancel'), color: $r('app.color.secondary') }, { text: $r('app.string.confirm'), color: $r('app.color.accent') }]
    }).then((result): void => {
      if (result.index === 1 && !this.disposed) {
        const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        context.startAbility({ action: 'ohos.want.action.viewData', uri: value }).catch((): void => {
          this.getUIContext().getPromptAction().showToast({ message: $r('app.string.report_error') });
        });
      }
    }).finally((): void => { this.confirming = false; });
  }
  private async finishLogin(): Promise<void> {
    if (this.importing) { return; } this.importing = true;
    try {
      if (!await appStore.importWebSession()) { this.getUIContext().getPromptAction().showToast({ message: $r('app.string.web_session_missing') }); return; }
      appStore.saveUser((await afdianApi.myProfile()).user);
      if (!this.disposed) { this.stack.pop(); this.stack.pop(); }
    } catch (error) { if (!this.disposed) { this.getUIContext().getPromptAction().showToast({ message: $r('app.string.report_error') }); } }
    finally { this.importing = false; }
  }
  private async shareLink(): Promise<void> {
    if (this.sharing || this.disposed) { return; }
    let link: string = this.param.url;
    try { link = this.controller.getUrl() || link; } catch (error) {}
    if (!trustedSite(link)) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.blocked_url') });
      return;
    }
    this.sharing = true;
    try {
      const record: systemShare.SharedRecord = {
        utd: utd.UniformDataType.HYPERLINK,
        content: link,
        title: this.param.title || this.text($r('app.string.app_name')),
        description: this.text($r('app.string.share_description'))
      };
      const data: systemShare.SharedData = new systemShare.SharedData(record);
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      });
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.share_failed') });
    } finally {
      this.sharing = false;
    }
  }
  build() {
    HdsNavDestination() {
      Column() {
        if (this.progress < 100) { Progress({ value: this.progress, total: 100, type: ProgressType.Linear }).color($r('app.color.accent')).height(2).width('100%') }
        if (this.address.length > 0) {
          Web({ src: this.address, controller: this.controller }).layoutWeight(1).width('100%')
            .javaScriptAccess(true).domStorageAccess(true).fileAccess(false).mixedMode(MixedMode.None)
            .onLoadIntercept((event): boolean => event === undefined ? true : this.intercept(event.data.getRequestUrl()))
            .onPageBegin((event): void => { if (event?.url) { this.address = event.url; } })
            .onProgressChange((event): void => { this.progress = event?.newProgress ?? 0; })
        } else { LoadingProgress().width(32).height(32).margin(30).color($r('app.color.accent')) }
        if (this.param.login) { Button($r('app.string.finish_login')).backgroundColor($r('app.color.accent')).width('92%').height(48).margin(12).enabled(!this.importing).onClick((): void => { this.finishLogin(); }) }
      }.width('100%').height('100%')
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: this.param.title || $r('app.string.official_page') },
        menu: { maxCount: 1, value: [{
          content: {
            icon: $r('sys.symbol.share'),
            label: $r('app.string.share'),
            isEnabled: !this.param.login && this.address.length > 0,
            action: (): void => { this.shareLink(); }
          }
        }] } } }).titleMode(HdsNavDestinationTitleMode.MINI)
      .backgroundColor($r('app.color.canvas')).onBackPressed((): boolean => {
        try { if (this.controller.accessBackward()) { this.controller.backward(); return true; } } catch (error) {}
        return false;
      })
  }
}
