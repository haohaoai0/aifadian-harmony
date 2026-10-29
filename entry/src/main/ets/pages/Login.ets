import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { afdianApi } from '../services/AfdianApi';
import { appStore } from '../services/AppStore';
import { LoginData, RouteParam } from '../models/Models';
import { SendCodeResult } from '../models/AuthModels';
import { SavedAccountSummary } from '../models/AuthModels';
import { User } from '../models/Models';
import { navigationStyle } from '../utils/NavigationStyle';
import { afdianPreferredOrigin } from '../common/UrlPolicy';

@Component
export struct LoginDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @State account: string = '';
  @State password: string = '';
  @State code: string = '';
  @State captchaCode: string = '';
  @State captchaPixelMap: image.PixelMap | undefined = undefined;
  @State mode: number = 0;
  @State accepted: boolean = false;
  @State working: boolean = false;
  @State sending: boolean = false;
  @State cooldown: number = 0;
  @State savedAccounts: SavedAccountSummary[] = [];
  @State switchingAccount: string = '';
  private generation: number = 0;
  private timer: number = -1;
  private scroller: Scroller = new Scroller();
  private text(resource: Resource): string { return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? ''; }
  aboutToAppear(): void { this.savedAccounts = appStore.savedAccounts(); }
  aboutToDisappear(): void {
    this.generation++;
    this.password = '';
    this.code = '';
    this.captchaCode = '';
    this.captchaPixelMap = undefined;
    if (this.timer >= 0) { clearInterval(this.timer); }
  }
  private async submit(): Promise<void> {
    if (!this.accepted || this.account.trim().length === 0 || (this.mode === 0 ? this.password.length === 0 : this.code.length === 0)) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.invalid_login') }); return;
    }
    this.working = true; const generation: number = this.generation;
    try {
      const data: LoginData = this.mode === 0 ? await afdianApi.login(this.account.trim(), this.password) : await afdianApi.quickLogin(this.account.trim(), this.code.trim());
      if (generation !== this.generation) { return; }
      if (!data.auth_token) { throw new Error('Empty session'); }
      await appStore.saveSession(data.auth_token);
      try { appStore.saveUser((await afdianApi.myProfile()).user); } catch (error) {}
      if (generation === this.generation) { this.stack.pop(); }
    } catch (error) { if (generation === this.generation) { this.getUIContext().getPromptAction().showToast({ message: $r('app.string.login_failed') }); } }
    finally { this.password = ''; if (generation === this.generation) { this.working = false; } }
  }
  private async switchAccount(account: SavedAccountSummary): Promise<void> {
    if (this.switchingAccount.length > 0) { return; }
    this.switchingAccount = account.userId;
    this.working = true;
    try {
      await appStore.activateSavedAccount(account.userId);
      const profile = await afdianApi.myProfile();
      const user: User = profile.user;
      if (user.user_id !== account.userId) { throw new Error('Account mismatch'); }
      appStore.saveUser(user);
      await appStore.commitActiveAccount();
      this.stack.pop();
    } catch (error) {
      try { await appStore.restoreSession(); } catch (restoreError) {}
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.login_failed') });
    } finally {
      this.switchingAccount = '';
      this.working = false;
    }
  }
  private async loadCaptcha(dataUri: string): Promise<void> {
    this.captchaPixelMap = undefined;
    if (dataUri.length === 0) { return; }
    const comma: number = dataUri.indexOf(',');
    const base64: string = comma >= 0 ? dataUri.substring(comma + 1) : dataUri;
    const bytes: Uint8Array = new util.Base64Helper().decodeSync(base64);
    const source: image.ImageSource = image.createImageSource(bytes.buffer as ArrayBuffer);
    this.captchaPixelMap = await source.createPixelMap();
  }
  private async sendCode(refresh: boolean = false): Promise<void> {
    if (this.sending || this.cooldown > 0 || !this.accepted || this.account.trim().length === 0) { return; }
    if (!refresh && this.captchaPixelMap !== undefined && this.captchaCode.trim().length === 0) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.captcha_required') });
      return;
    }
    this.sending = true; const generation: number = this.generation;
    try {
      const result: SendCodeResult = await afdianApi.sendCode(this.account.trim(),
        refresh ? '' : this.captchaCode.trim());
      if (generation !== this.generation) { return; }
      if (result.sent) {
        this.captchaPixelMap = undefined;
        this.captchaCode = '';
        this.cooldown = 60;
        this.timer = setInterval((): void => {
          this.cooldown--;
          if (this.cooldown <= 0) { clearInterval(this.timer); this.timer = -1; }
        }, 1000);
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.code_sent') });
      } else {
        await this.loadCaptcha(result.captchaImg);
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.captcha_required') });
      }
    } catch (error) { if (generation === this.generation) { this.getUIContext().getPromptAction().showToast({ message: $r('app.string.report_error') }); } }
    finally { this.sending = false; }
  }
  private webLogin(): void { const param: RouteParam = new RouteParam(
    afdianPreferredOrigin(appStore.getRoute()) + '/login', ''); param.login = true; this.stack.pushPath({ name: 'Web', param: param }); }
  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 22 }) {
          Image($r('app.media.afd_icon')).width(76).height(76).borderRadius(22).margin({ top: 24 })
          Text($r('app.string.login_title')).fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
          Text($r('app.string.login_hint')).fontSize(15).fontColor($r('app.color.secondary')).textAlign(TextAlign.Center)
          if (this.savedAccounts.length > 0) {
            Column({ space: 8 }) {
              Text($r('app.string.saved_accounts')).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
              ForEach(this.savedAccounts, (account: SavedAccountSummary) => {
                Button({ type: ButtonType.Normal }) {
                  Row({ space: 12 }) {
                    Image(account.avatar).width(38).height(38).borderRadius(19)
                      .backgroundColor($r('app.color.accent_soft')).objectFit(ImageFit.Cover)
                    Text(account.name || $r('app.string.creator')).fontSize(15).fontColor($r('app.color.text')).layoutWeight(1)
                    if (account.userId === appStore.getUser().user_id) {
                      Text($r('app.string.saved_account_current')).fontSize(12).fontColor($r('app.color.accent'))
                    } else if (this.switchingAccount === account.userId) {
                      LoadingProgress().width(20).height(20).color($r('app.color.accent'))
                    } else {
                      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.secondary')])
                    }
                  }.width('100%').padding(12)
                }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(14)
                  .enabled(!this.working && account.userId !== appStore.getUser().user_id)
                  .onClick((): void => { this.switchAccount(account); })
              }, (account: SavedAccountSummary): string => account.userId)
            }.width('100%')
          }
          Row({ space: 12 }) {
            Button($r('app.string.password_login')).fontColor(this.mode === 0 ? Color.White : $r('app.color.secondary')).backgroundColor(this.mode === 0 ? $r('app.color.accent') : $r('app.color.surface')).onClick((): void => { this.mode = 0; })
            Button($r('app.string.code_login')).fontColor(this.mode === 1 ? Color.White : $r('app.color.secondary')).backgroundColor(this.mode === 1 ? $r('app.color.accent') : $r('app.color.surface')).onClick((): void => { this.mode = 1; })
          }
          TextInput({ text: this.account, placeholder: this.text($r('app.string.account')) }).height(54).backgroundColor($r('app.color.surface'))
            .onChange((value: string): void => {
              this.account = value;
              this.captchaPixelMap = undefined;
              this.captchaCode = '';
            })
          if (this.mode === 0) {
            TextInput({ text: this.password, placeholder: this.text($r('app.string.password')) }).type(InputType.Password).height(54).backgroundColor($r('app.color.surface')).onChange((value: string): void => { this.password = value; })
          } else {
            Row({ space: 10 }) {
              TextInput({ text: this.code, placeholder: this.text($r('app.string.code')) }).type(InputType.Number).height(54).layoutWeight(1).backgroundColor($r('app.color.surface')).onChange((value: string): void => { this.code = value; })
              Button(this.cooldown > 0 ? this.cooldown + 's' : $r('app.string.send_code')).onClick((): void => { this.sendCode(); }).enabled(!this.sending && this.cooldown === 0 && this.accepted)
                .backgroundColor($r('app.color.accent_soft')).fontColor($r('app.color.accent'))
            }
            if (this.captchaPixelMap !== undefined) {
              Column({ space: 8 }) {
                Text($r('app.string.captcha_hint')).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
                Row({ space: 10 }) {
                  TextInput({ text: this.captchaCode, placeholder: this.text($r('app.string.captcha_code')) })
                    .height(48).layoutWeight(1).backgroundColor($r('app.color.surface'))
                    .onChange((value: string): void => { this.captchaCode = value; })
                  Image(this.captchaPixelMap).width(118).height(48).objectFit(ImageFit.Contain)
                    .borderRadius(8).backgroundColor($r('app.color.surface'))
                    .onClick((): void => { this.sendCode(true); })
                    .accessibilityText($r('app.string.captcha_refresh'))
                }.width('100%')
              }.width('100%').padding(12).backgroundColor($r('app.color.accent_soft')).borderRadius(14)
            }
          }
          Row({ space: 4 }) {
            Checkbox().select(this.accepted).selectedColor($r('app.color.accent')).onChange((value: boolean): void => { this.accepted = value; })
            Text($r('app.string.terms_accept')).fontSize(13).fontColor($r('app.color.secondary')).layoutWeight(1)
          }.width('100%')
          Button($r('app.string.login')).width('100%').height(50).backgroundColor($r('app.color.accent')).enabled(!this.working).onClick((): void => { this.submit(); })
          if (this.working) { LoadingProgress().width(28).height(28).color($r('app.color.accent')) }
          Button($r('app.string.web_login')).fontColor($r('app.color.accent')).backgroundColor(Color.Transparent).onClick((): void => this.webLogin())
          Row({ space: 8 }) {
            Button($r('app.string.register_action')).layoutWeight(1).fontColor($r('app.color.accent'))
              .backgroundColor($r('app.color.accent_soft'))
              .onClick((): void => this.stack.pushPath({ name: 'Register' }))
            Button($r('app.string.forgot_password')).layoutWeight(1).fontColor($r('app.color.secondary'))
              .backgroundColor($r('app.color.surface'))
              .onClick((): void => this.stack.pushPath({ name: 'ForgotPassword' }))
          }.width('100%')
          Button($r('app.string.terms')).fontColor($r('app.color.secondary')).fontSize(13).backgroundColor(Color.Transparent)
            .onClick((): void => this.stack.pushPath({ name: 'Web', param: new RouteParam(
              afdianPreferredOrigin(appStore.getRoute()) + '/term', '') }))
        }.padding({ left: 24, right: 24, top: this.topInset + 72, bottom: this.bottomInset + 24 }).width('100%').constraintSize({ maxWidth: 520 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(), content: { title: { mainTitle: $r('app.string.login') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
