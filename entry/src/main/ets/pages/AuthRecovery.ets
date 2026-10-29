import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { afdianApi } from '../services/AfdianApi';
import { appStore } from '../services/AppStore';
import { LoginData, User } from '../models/Models';
import { ResetTokenData, SendCodeResult } from '../models/AuthModels';
import { navigationStyle } from '../utils/NavigationStyle';

@Component
export struct RegisterDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @State name: string = '';
  @State account: string = '';
  @State password: string = '';
  @State code: string = '';
  @State captchaCode: string = '';
  @State captchaPixelMap: image.PixelMap | undefined = undefined;
  @State accepted: boolean = false;
  @State working: boolean = false;
  @State sending: boolean = false;
  @State cooldown: number = 0;
  private generation: number = 0;
  private timer: number = -1;
  private scroller: Scroller = new Scroller();
  private text(resource: Resource): string { return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? ''; }
  aboutToDisappear(): void {
    this.generation++;
    this.password = '';
    this.code = '';
    this.captchaCode = '';
    this.captchaPixelMap = undefined;
    if (this.timer >= 0) { clearInterval(this.timer); }
  }
  private show(resource: Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: resource });
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
    if (this.sending || this.cooldown > 0) { return; }
    if (this.account.trim().length === 0 || this.password.length === 0 || this.name.trim().length === 0) {
      this.show($r('app.string.auth_fields_required'));
      return;
    }
    if (!refresh && this.captchaPixelMap !== undefined && this.captchaCode.trim().length === 0) {
      this.show($r('app.string.captcha_required'));
      return;
    }
    this.sending = true;
    const generation: number = this.generation;
    try {
      const result: SendCodeResult = await afdianApi.sendRegisterCode(this.account.trim(), this.password,
        this.name.trim(), refresh ? '' : this.captchaCode.trim());
      if (generation !== this.generation) { return; }
      if (result.sent) {
        this.captchaPixelMap = undefined;
        this.captchaCode = '';
        this.cooldown = 60;
        this.timer = setInterval((): void => {
          this.cooldown--;
          if (this.cooldown <= 0) { clearInterval(this.timer); this.timer = -1; }
        }, 1000);
        this.show($r('app.string.code_sent'));
      } else {
        await this.loadCaptcha(result.captchaImg);
        this.show($r('app.string.captcha_required'));
      }
    } catch (error) {
      if (generation === this.generation) { this.show($r('app.string.report_error')); }
    } finally {
      this.sending = false;
    }
  }
  private async register(): Promise<void> {
    if (this.working) { return; }
    if (!this.accepted || this.name.trim().length === 0 || this.account.trim().length === 0 ||
      this.password.length < 6 || this.code.trim().length === 0) {
      this.show($r('app.string.auth_fields_required'));
      return;
    }
    this.working = true;
    const generation: number = this.generation;
    try {
      let data: LoginData = await afdianApi.register(this.account.trim(), this.password,
        this.name.trim(), this.code.trim());
      if (!data.auth_token) {
        data = await afdianApi.login(this.account.trim(), this.password);
      }
      if (!data.auth_token) { throw new Error('Registration did not return a session'); }
      await appStore.saveSession(data.auth_token);
      const profile = await afdianApi.myProfile();
      const user: User = profile.user;
      appStore.saveUser(user);
      await appStore.commitActiveAccount();
      if (generation === this.generation) { this.stack.pop(); }
    } catch (error) {
      if (generation === this.generation) { this.show($r('app.string.register_failed')); }
    } finally {
      this.password = '';
      if (generation === this.generation) { this.working = false; }
    }
  }
  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Image($r('app.media.afd_icon')).width(68).height(68).borderRadius(20)
          Text($r('app.string.register_title')).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
          Text($r('app.string.register_hint')).fontSize(14).fontColor($r('app.color.secondary')).textAlign(TextAlign.Center)
          TextInput({ text: this.name, placeholder: this.text($r('app.string.auth_name')) })
            .height(52).backgroundColor($r('app.color.surface')).onChange((value: string): void => { this.name = value; })
          TextInput({ text: this.account, placeholder: this.text($r('app.string.account')) })
            .height(52).backgroundColor($r('app.color.surface')).onChange((value: string): void => {
              this.account = value;
              this.captchaPixelMap = undefined;
              this.captchaCode = '';
            })
          TextInput({ text: this.password, placeholder: this.text($r('app.string.password')) }).type(InputType.Password)
            .height(52).backgroundColor($r('app.color.surface')).onChange((value: string): void => { this.password = value; })
          Row({ space: 10 }) {
            TextInput({ text: this.code, placeholder: this.text($r('app.string.code')) }).type(InputType.Number)
              .height(52).layoutWeight(1).backgroundColor($r('app.color.surface'))
              .onChange((value: string): void => { this.code = value; })
            Button(this.cooldown > 0 ? this.cooldown + 's' : $r('app.string.send_code')).height(48)
              .backgroundColor($r('app.color.accent_soft')).fontColor($r('app.color.accent'))
              .enabled(!this.sending && this.cooldown === 0).onClick((): void => { this.sendCode(); })
          }.width('100%')
          if (this.captchaPixelMap !== undefined) {
            Column({ space: 8 }) {
              Text($r('app.string.captcha_hint')).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
              Row({ space: 10 }) {
                TextInput({ text: this.captchaCode, placeholder: this.text($r('app.string.captcha_code')) })
                  .height(48).layoutWeight(1).backgroundColor($r('app.color.surface'))
                  .onChange((value: string): void => { this.captchaCode = value; })
                Image(this.captchaPixelMap).width(118).height(48).objectFit(ImageFit.Contain).borderRadius(8)
                  .backgroundColor($r('app.color.surface')).onClick((): void => { this.sendCode(true); })
              }.width('100%')
            }.width('100%').padding(12).backgroundColor($r('app.color.accent_soft')).borderRadius(14)
          }
          Row({ space: 4 }) {
            Checkbox().select(this.accepted).selectedColor($r('app.color.accent'))
              .onChange((value: boolean): void => { this.accepted = value; })
            Text($r('app.string.terms_accept')).fontSize(13).fontColor($r('app.color.secondary')).layoutWeight(1)
          }.width('100%')
          Button(this.working ? $r('app.string.register_working') : $r('app.string.register_action')).height(50).width('100%')
            .backgroundColor($r('app.color.accent')).enabled(!this.working).onClick((): void => { this.register(); })
          if (this.working) { LoadingProgress().width(28).height(28).color($r('app.color.accent')) }
        }.width('100%').constraintSize({ maxWidth: 520 }).padding({ left: 24, right: 24,
          top: this.topInset + 72, bottom: this.bottomInset + 28 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(),
      content: { title: { mainTitle: $r('app.string.register_action') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}

@Component
export struct ForgotPasswordDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @State account: string = '';
  @State code: string = '';
  @State resetToken: string = '';
  @State password: string = '';
  @State confirm: string = '';
  @State step: number = 0;
  @State working: boolean = false;
  @State cooldown: number = 0;
  private generation: number = 0;
  private timer: number = -1;
  private scroller: Scroller = new Scroller();
  private text(resource: Resource): string { return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? ''; }
  aboutToDisappear(): void {
    this.generation++;
    this.password = '';
    this.confirm = '';
    this.resetToken = '';
    if (this.timer >= 0) { clearInterval(this.timer); }
  }
  private toast(resource: Resource): void { this.getUIContext().getPromptAction().showToast({ message: resource }); }
  private async sendCode(): Promise<void> {
    if (this.working || this.cooldown > 0 || this.account.trim().length === 0) { return; }
    this.working = true;
    const generation: number = this.generation;
    try {
      const result: SendCodeResult = await afdianApi.sendForgotCode(this.account.trim());
      if (generation !== this.generation) { return; }
      if (!result.sent) { throw new Error('Captcha is required for this account'); }
      this.cooldown = 60;
      this.timer = setInterval((): void => {
        this.cooldown--;
        if (this.cooldown <= 0) { clearInterval(this.timer); this.timer = -1; }
      }, 1000);
      this.toast($r('app.string.code_sent'));
    } catch (error) {
      if (generation === this.generation) { this.toast($r('app.string.report_error')); }
    } finally {
      this.working = false;
    }
  }
  private async checkCode(): Promise<void> {
    if (this.working || this.account.trim().length === 0 || this.code.trim().length === 0) { return; }
    this.working = true;
    try {
      const data: ResetTokenData = await afdianApi.checkForgotCode(this.account.trim(), this.code.trim());
      this.resetToken = data.reset_token || data.token;
      if (this.resetToken.length === 0) { throw new Error('Reset token missing'); }
      this.step = 1;
    } catch (error) {
      this.toast($r('app.string.auth_code_invalid'));
    } finally {
      this.working = false;
    }
  }
  private async reset(): Promise<void> {
    if (this.working) { return; }
    if (this.password.length < 6 || this.password !== this.confirm) {
      this.toast($r('app.string.auth_password_invalid'));
      return;
    }
    this.working = true;
    try {
      await afdianApi.resetPassword(this.resetToken, this.password);
      const data: LoginData = await afdianApi.login(this.account.trim(), this.password);
      if (!data.auth_token) { throw new Error('Session missing'); }
      await appStore.saveSession(data.auth_token);
      const profile = await afdianApi.myProfile();
      const user: User = profile.user;
      appStore.saveUser(user);
      await appStore.commitActiveAccount();
      this.toast($r('app.string.auth_reset_success'));
      this.stack.pop();
    } catch (error) {
      this.toast($r('app.string.auth_reset_failed'));
    } finally {
      this.working = false;
    }
  }
  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          Text($r('app.string.forgot_title')).fontSize(26).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
          Text(this.step === 0 ? $r('app.string.forgot_hint') : $r('app.string.forgot_password_hint'))
            .fontSize(14).fontColor($r('app.color.secondary')).textAlign(TextAlign.Center)
          if (this.step === 0) {
            TextInput({ text: this.account, placeholder: this.text($r('app.string.account')) })
              .height(52).backgroundColor($r('app.color.surface')).onChange((value: string): void => { this.account = value; })
            Row({ space: 10 }) {
              TextInput({ text: this.code, placeholder: this.text($r('app.string.code')) }).type(InputType.Number)
                .height(52).layoutWeight(1).backgroundColor($r('app.color.surface'))
                .onChange((value: string): void => { this.code = value; })
              Button(this.cooldown > 0 ? this.cooldown + 's' : $r('app.string.send_code')).height(48)
                .backgroundColor($r('app.color.accent_soft')).fontColor($r('app.color.accent'))
                .enabled(!this.working && this.cooldown === 0).onClick((): void => { this.sendCode(); })
            }.width('100%')
            Button(this.working ? $r('app.string.loading') : $r('app.string.forgot_check'))
              .height(50).width('100%').backgroundColor($r('app.color.accent')).enabled(!this.working)
              .onClick((): void => { this.checkCode(); })
          } else {
            TextInput({ text: this.password, placeholder: this.text($r('app.string.account_new_password')) })
              .type(InputType.Password).height(52).backgroundColor($r('app.color.surface'))
              .onChange((value: string): void => { this.password = value; })
            TextInput({ text: this.confirm, placeholder: this.text($r('app.string.account_confirm_password')) })
              .type(InputType.Password).height(52).backgroundColor($r('app.color.surface'))
              .onChange((value: string): void => { this.confirm = value; })
            Button(this.working ? $r('app.string.saving') : $r('app.string.forgot_reset'))
              .height(50).width('100%').backgroundColor($r('app.color.accent')).enabled(!this.working)
              .onClick((): void => { this.reset(); })
          }
          if (this.working) { LoadingProgress().width(28).height(28).color($r('app.color.accent')) }
        }.width('100%').constraintSize({ maxWidth: 520 }).padding({ left: 24, right: 24,
          top: this.topInset + 72, bottom: this.bottomInset + 28 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(),
      content: { title: { mainTitle: $r('app.string.forgot_title') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
