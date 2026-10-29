import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { Avatar } from '../components/Common';
import { User } from '../models/Models';
import { AccountData, PasswordChangeResult } from '../models/SponsoringModels';
import { afdianApi } from '../services/AfdianApi';
import { accountApi, BasicProfileFields } from '../services/AccountApi';
import { appStore } from '../services/AppStore';
import { navigationStyle } from '../utils/NavigationStyle';

@Component
export struct AccountManagementDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @State user: User = new User();
  @State account: AccountData = new AccountData();
  @State avatar: string = '';
  @State name: string = '';
  @State gender: string = '0';
  @State birthday: string = '';
  @State recipient: string = '';
  @State contact: string = '';
  @State address: string = '';
  @State bindType: string = '';
  @State bindAccount: string = '';
  @State bindCode: string = '';
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State saving: boolean = false;
  @State sendingCode: boolean = false;
  @State binding: boolean = false;
  @State changingPassword: boolean = false;
  @State unbinding: string = '';
  private generation: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.generation++; }

  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    this.failed = false;
    if (!this.loggedIn) { this.loading = false; return; }
    try {
      const profile = await afdianApi.myProfile();
      if (generation !== this.generation) { return; }
      this.user = profile.user;
      this.applyProfile(profile.user);
      const account: AccountData = await accountApi.account();
      if (generation === this.generation) { this.account = account; }
    } catch (error) {
      if (generation === this.generation) { this.failed = true; }
    } finally {
      if (generation === this.generation) { this.loading = false; }
    }
  }

  private applyProfile(user: User): void {
    this.avatar = user.avatar ?? '';
    this.name = user.name ?? '';
    this.gender = user.gender ?? '0';
    this.birthday = user.birthday ?? '';
    this.recipient = user.addr_name ?? '';
    this.contact = user.addr_phone ?? '';
    this.address = user.addr_address ?? '';
  }

  private form(): BasicProfileFields {
    const fields: BasicProfileFields = new BasicProfileFields();
    fields.avatar = this.avatar.trim();
    fields.name = this.name.trim();
    fields.gender = this.gender;
    fields.birthday = this.birthday.trim();
    fields.addrName = this.recipient.trim();
    fields.addrPhone = this.contact.trim();
    fields.addrAddress = this.address.trim();
    return fields;
  }

  private toast(message: Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  private async save(): Promise<void> {
    if (this.saving || this.name.trim().length === 0) {
      if (this.name.trim().length === 0) { this.toast($r('app.string.account_name_required')); }
      return;
    }
    if (this.birthday.trim().length > 0 && this.birthday.trim().length !== 8) {
      this.toast($r('app.string.account_birthday_hint')); return;
    }
    this.saving = true;
    try {
      await accountApi.saveBasic(this.form());
      const profile = await afdianApi.myProfile();
      this.user = profile.user;
      this.applyProfile(profile.user);
      appStore.saveUser(profile.user);
      this.toast($r('app.string.account_save_success'));
    } catch (error) {
      this.toast($r('app.string.account_save_failed'));
    } finally {
      this.saving = false;
    }
  }

  private beginBind(type: string): void {
    this.bindType = type;
    this.bindAccount = type === 'email' ? this.account.login.email : this.account.login.phone;
    this.bindCode = '';
  }

  private async sendCode(): Promise<void> {
    const value: string = this.bindAccount.trim();
    if (this.sendingCode || value.length === 0) { return; }
    this.sendingCode = true;
    try {
      await accountApi.sendVerifyCode(value);
      this.toast($r('app.string.account_code_sent'));
    } catch (error) {
      this.toast($r('app.string.account_code_failed'));
    } finally {
      this.sendingCode = false;
    }
  }

  private async bind(): Promise<void> {
    const accountText: string = this.bindAccount.trim();
    const codeText: string = this.bindCode.trim();
    if (this.binding || accountText.length === 0 || codeText.length === 0) { return; }
    this.binding = true;
    try {
      await accountApi.bind(accountText, codeText);
      this.account = await accountApi.account();
      this.bindType = '';
      this.bindAccount = '';
      this.bindCode = '';
      this.toast($r('app.string.account_bind_success'));
    } catch (error) {
      this.toast($r('app.string.account_bind_failed'));
    } finally {
      this.binding = false;
    }
  }

  private async changePassword(): Promise<void> {
    if (this.changingPassword) { return; }
    if (this.oldPassword.length === 0 || this.newPassword.length === 0) {
      this.toast($r('app.string.account_password_required')); return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.toast($r('app.string.account_password_mismatch')); return;
    }
    this.changingPassword = true;
    try {
      const changed: PasswordChangeResult = await accountApi.changePassword(this.oldPassword, this.newPassword);
      if (changed.auth_token.length > 0) { await appStore.saveSession(changed.auth_token); }
      this.oldPassword = '';
      this.newPassword = '';
      this.confirmPassword = '';
      this.toast($r('app.string.account_password_success'));
    } catch (error) {
      this.toast($r('app.string.account_password_failed'));
    } finally {
      this.changingPassword = false;
    }
  }
  private unbind(kind: string, label: Resource): void {
    if (this.unbinding.length > 0) { return; }
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.account_unbind_confirm', this.text(label)), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.confirm'), color: $r('app.color.danger') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1) { return; }
      this.unbinding = kind;
      try {
        await accountApi.unbind(kind);
        this.account = await accountApi.account();
        this.toast($r('app.string.account_unbind_success'));
      } catch (error) {
        this.toast($r('app.string.account_unbind_failed'));
      } finally {
        this.unbinding = '';
      }
    });
  }

  private logout(): void {
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.logout_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.confirm'), color: $r('app.color.danger') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1) { return; }
      try { await afdianApi.request<Object>('/api/passport/logout'); } catch (error) {}
      await appStore.clearSession();
      this.stack.pop();
    });
  }

  @Builder private SectionTitle(title: Resource) {
    Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.secondary'))
      .width('100%').margin({ top: 10, bottom: 2 })
  }

  @Builder private Field(label: Resource, value: string, password: boolean, change: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
      TextInput({ text: value, placeholder: label }).type(password ? InputType.Password : InputType.Normal)
        .height(50).width('100%').backgroundColor($r('app.color.canvas')).borderRadius(12)
        .onChange((text: string): void => change(text))
    }.width('100%')
  }

  @Builder private BindingAction(label: Resource, value: string, type: string) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(label).fontSize(14).fontColor($r('app.color.text'))
        Text(value.length > 0 ? value : $r('app.string.account_not_bound'))
          .fontSize(13).fontColor($r('app.color.secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button(value.length > 0 ? $r('app.string.account_change') : $r('app.string.account_bind'))
        .height(36).backgroundColor($r('app.color.accent_soft')).fontColor($r('app.color.accent'))
        .onClick((): void => this.beginBind(type))
    }.width('100%').padding({ top: 12, bottom: 12 })
  }
  @Builder private OAuthAction(label: Resource, nickname: string, kind: string) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(label).fontSize(14).fontColor($r('app.color.text'))
        Text(nickname.length > 0 ? nickname : $r('app.string.account_not_bound'))
          .fontSize(13).fontColor($r('app.color.secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (nickname.length > 0) {
        Button(this.unbinding === kind ? $r('app.string.loading') : $r('app.string.account_unbind'))
          .height(36).backgroundColor($r('app.color.accent_soft')).fontColor($r('app.color.danger'))
          .enabled(this.unbinding.length === 0).onClick((): void => this.unbind(kind, label))
      }
    }.width('100%').padding({ top: 12, bottom: 12 })
  }

  build() {
    HdsNavDestination() {
      if (this.loading || this.failed) {
        Column({ space: 16 }) {
          if (this.loading) { LoadingProgress().width(36).height(36).color($r('app.color.accent')) }
          else { Text($r('app.string.network_error')).fontColor($r('app.color.secondary')) }
          if (this.failed) { Button($r('app.string.retry')).backgroundColor($r('app.color.accent')).onClick((): void => { this.load(); }) }
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else if (!this.loggedIn) {
        Column({ space: 16 }) {
          Text($r('app.string.login_hint')).fontColor($r('app.color.secondary'))
          Button($r('app.string.login')).backgroundColor($r('app.color.accent')).onClick((): void => this.stack.pushPath({ name: 'Login' }))
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.scroller) {
          Column({ space: 14 }) {
            Row({ space: 14 }) {
              Avatar({ src: this.avatar, diameter: 64 })
              Column({ space: 5 }) {
                Text(this.name || $r('app.string.account_unnamed')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
                Text(this.account.user_private_id.length > 0 ?
                  $r('app.string.account_private_id', this.account.user_private_id) : $r('app.string.account_title'))
                  .fontSize(12).fontColor($r('app.color.secondary'))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.width('100%').padding(18).backgroundColor($r('app.color.surface')).borderRadius(20)

            this.SectionTitle($r('app.string.account_basic'))
            Column({ space: 14 }) {
              this.Field($r('app.string.account_avatar'), this.avatar, false, (value: string): void => { this.avatar = value; })
              this.Field($r('app.string.account_name'), this.name, false, (value: string): void => { this.name = value; })
              Row({ space: 12 }) {
                Text($r('app.string.account_gender')).fontSize(14).fontColor($r('app.color.text')).layoutWeight(1)
                Select([{ value: this.text($r('app.string.account_unknown')) },
                  { value: this.text($r('app.string.account_male')) }, { value: this.text($r('app.string.account_female')) }])
                  .selected(this.gender === '1' ? 1 : this.gender === '2' ? 2 : 0)
                  .value(this.gender === '1' ? this.text($r('app.string.account_male')) :
                    this.gender === '2' ? this.text($r('app.string.account_female')) : this.text($r('app.string.account_unknown')))
                  .onSelect((index: number): void => { this.gender = index === 1 ? '1' : index === 2 ? '2' : '0'; })
              }.width('100%')
              this.Field($r('app.string.account_birthday'), this.birthday, false, (value: string): void => { this.birthday = value; })
              this.Field($r('app.string.account_recipient'), this.recipient, false, (value: string): void => { this.recipient = value; })
              this.Field($r('app.string.account_contact'), this.contact, false, (value: string): void => { this.contact = value; })
              this.Field($r('app.string.account_address'), this.address, false, (value: string): void => { this.address = value; })
              Button(this.saving ? $r('app.string.saving') : $r('app.string.account_save')).height(46).width('100%')
                .backgroundColor($r('app.color.accent')).enabled(!this.saving).onClick((): void => { this.save(); })
            }.width('100%').padding(18).backgroundColor($r('app.color.surface')).borderRadius(20)

            this.SectionTitle($r('app.string.account_bindings'))
            Column() {
              this.BindingAction($r('app.string.account_email'), this.account.login.email, 'email')
              Divider().color($r('app.color.separator'))
              this.BindingAction($r('app.string.account_mobile'), this.account.login.phone, 'phone')
              if (this.bindType.length > 0) {
                Column({ space: 10 }) {
                  Text(this.bindType === 'email' ? $r('app.string.account_bind_email') : $r('app.string.account_bind_phone'))
                    .fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).width('100%')
                  TextInput({ text: this.bindAccount,
                    placeholder: this.bindType === 'email' ? $r('app.string.account_email') : $r('app.string.account_phone') })
                    .height(48).width('100%').backgroundColor($r('app.color.canvas')).borderRadius(12)
                    .onChange((value: string): void => { this.bindAccount = value; })
                  Row({ space: 10 }) {
                    TextInput({ text: this.bindCode, placeholder: $r('app.string.code') }).type(InputType.Number)
                      .height(48).layoutWeight(1).backgroundColor($r('app.color.canvas')).borderRadius(12)
                      .onChange((value: string): void => { this.bindCode = value; })
                    Button(this.sendingCode ? $r('app.string.loading') : $r('app.string.send_code')).height(44)
                      .backgroundColor($r('app.color.accent_soft')).fontColor($r('app.color.accent'))
                      .enabled(!this.sendingCode).onClick((): void => { this.sendCode(); })
                  }.width('100%')
                  Button(this.binding ? $r('app.string.loading') : $r('app.string.account_confirm_bind')).height(44).width('100%')
                    .backgroundColor($r('app.color.accent')).enabled(!this.binding).onClick((): void => { this.bind(); })
                }.width('100%').padding({ top: 14, bottom: 4 })
              }
            }.width('100%').padding({ left: 18, right: 18 }).backgroundColor($r('app.color.surface')).borderRadius(20)

            this.SectionTitle($r('app.string.account_third_party'))
            Column() {
              this.OAuthAction($r('app.string.account_wechat'), this.account.oauth?.wect?.nickname ?? '', 'wechat')
              Divider().color($r('app.color.separator'))
              this.OAuthAction($r('app.string.account_qq'), this.account.oauth?.qq?.nickname ?? '', 'qq')
              Divider().color($r('app.color.separator'))
              this.OAuthAction($r('app.string.account_google'), this.account.oauth?.google?.nickname ?? '', 'google')
            }.width('100%').padding({ left: 18, right: 18 }).backgroundColor($r('app.color.surface')).borderRadius(20)

            this.SectionTitle($r('app.string.account_security'))
            Column({ space: 12 }) {
              this.Field($r('app.string.account_old_password'), this.oldPassword, true, (value: string): void => { this.oldPassword = value; })
              this.Field($r('app.string.account_new_password'), this.newPassword, true, (value: string): void => { this.newPassword = value; })
              this.Field($r('app.string.account_confirm_password'), this.confirmPassword, true, (value: string): void => { this.confirmPassword = value; })
              Button(this.changingPassword ? $r('app.string.saving') : $r('app.string.account_change_password'))
                .height(46).width('100%').backgroundColor($r('app.color.accent'))
                .enabled(!this.changingPassword).onClick((): void => { this.changePassword(); })
            }.width('100%').padding(18).backgroundColor($r('app.color.surface')).borderRadius(20)

            Button($r('app.string.logout')).height(46).width('100%').backgroundColor($r('app.color.surface'))
              .fontColor($r('app.color.danger')).onClick((): void => this.logout())
          }.width('100%').constraintSize({ maxWidth: 760 }).padding({ left: 16, right: 16,
            top: this.topInset + 64, bottom: this.bottomInset + 28 })
        }.width('100%').height('100%').scrollBar(BarState.Off).backgroundColor($r('app.color.canvas'))
      }
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: $r('app.string.account_settings') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }

  private text(resource: Resource): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? '';
  }
}
