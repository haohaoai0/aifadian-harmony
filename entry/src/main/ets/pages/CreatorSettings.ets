import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { User } from '../models/Models';
import { afdianApi } from '../services/AfdianApi';
import { accountApi } from '../services/AccountApi';
import { appStore } from '../services/AppStore';
import { navigationStyle } from '../utils/NavigationStyle';

@Component
export struct CreatorSettingsDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @State user: User = new User();
  @State doing: string = '';
  @State detail: string = '';
  @State cover: string = '';
  @State publicIncome: boolean = false;
  @State publicSponsor: boolean = true;
  @State loading: boolean = true;
  @State saving: boolean = false;
  @State privacySaving: string = '';
  @State errorText: string = '';
  private generation: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.generation++; }
  private toast(resource: Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: resource });
  }
  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    this.loading = true;
    this.errorText = '';
    try {
      const profile = await afdianApi.myProfile();
      if (generation !== this.generation) { return; }
      this.user = profile.user;
      this.doing = profile.user.creator?.doing ?? '';
      this.detail = profile.user.creator?.detail ?? '';
      this.cover = profile.user.cover ?? '';
      this.publicIncome = profile.user.creator?.privacy_public_income === 1;
      this.publicSponsor = profile.user.creator?.privacy_public_sponsor === 1;
    } catch (error) {
      if (generation === this.generation) {
        this.errorText = (error as Error).message;
        this.toast($r('app.string.network_error'));
      }
    } finally {
      if (generation === this.generation) { this.loading = false; }
    }
  }
  private async saveBasic(): Promise<void> {
    if (this.saving) { return; }
    this.saving = true;
    try {
      await accountApi.saveCreatorBasic(this.user, this.doing.trim(), this.detail.trim(), this.cover.trim());
      const profile = await afdianApi.myProfile();
      this.user = profile.user;
      appStore.saveUser(profile.user);
      this.toast($r('app.string.account_save_success'));
    } catch (error) {
      this.toast($r('app.string.account_save_failed'));
    } finally {
      this.saving = false;
    }
  }
  private async savePrivacy(kind: string, enabled: boolean): Promise<void> {
    if (this.privacySaving.length > 0) { return; }
    this.privacySaving = kind;
    const previousIncome: boolean = this.publicIncome;
    const previousSponsor: boolean = this.publicSponsor;
    if (kind === 'income') { this.publicIncome = enabled; } else { this.publicSponsor = enabled; }
    try {
      await accountApi.saveCreatorPrivacy(kind, enabled);
    } catch (error) {
      this.publicIncome = previousIncome;
      this.publicSponsor = previousSponsor;
      this.toast($r('app.string.creator_privacy_failed'));
    } finally {
      this.privacySaving = '';
    }
  }
  @Builder private Field(label: Resource, value: string, multiline: boolean, change: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
      if (multiline) {
        TextArea({ text: value, placeholder: label }).height(140).width('100%')
          .backgroundColor($r('app.color.canvas')).borderRadius(12)
          .onChange((text: string): void => change(text))
      } else {
        TextInput({ text: value, placeholder: label }).height(50).width('100%')
          .backgroundColor($r('app.color.canvas')).borderRadius(12)
          .onChange((text: string): void => change(text))
      }
    }.width('100%')
  }
  build() {
    HdsNavDestination() {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color($r('app.color.accent'))
      } else if (!this.loggedIn) {
        Column({ space: 12 }) {
          Text($r('app.string.login_hint')).fontColor($r('app.color.secondary'))
          Button($r('app.string.login')).backgroundColor($r('app.color.accent'))
            .onClick((): void => this.stack.pushPath({ name: 'Login' }))
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else if (this.user.creator === undefined) {
        Column({ space: 12 }) {
          if (this.errorText.length > 0) {
            Text(this.errorText).fontSize(12).fontColor($r('app.color.danger')).textAlign(TextAlign.Center)
              .padding({ left: 24, right: 24 })
            Button($r('app.string.retry')).backgroundColor($r('app.color.accent'))
              .onClick((): void => { this.load(); })
          } else {
            Text($r('app.string.creator_settings_unavailable')).fontColor($r('app.color.secondary'))
          }
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.scroller) {
          Column({ space: 16 }) {
            Button($r('app.string.faq_title')).height(46).width('100%').backgroundColor($r('app.color.accent_soft'))
              .fontColor($r('app.color.accent')).onClick((): void => this.stack.pushPath({ name: 'FaqSettings' }))
            Text($r('app.string.creator_profile')).fontSize(14).fontColor($r('app.color.secondary')).width('100%')
            Column({ space: 14 }) {
              this.Field($r('app.string.creator_doing'), this.doing, false, (value: string): void => { this.doing = value; })
              this.Field($r('app.string.creator_detail'), this.detail, true, (value: string): void => { this.detail = value; })
              this.Field($r('app.string.creator_cover_url'), this.cover, false, (value: string): void => { this.cover = value; })
              Button(this.saving ? $r('app.string.saving') : $r('app.string.account_save'))
                .height(46).width('100%').backgroundColor($r('app.color.accent')).enabled(!this.saving)
                .onClick((): void => { this.saveBasic(); })
            }.width('100%').padding(18).backgroundColor($r('app.color.surface')).borderRadius(20)
            Text($r('app.string.creator_privacy')).fontSize(14).fontColor($r('app.color.secondary')).width('100%')
            Column() {
              Row({ space: 12 }) {
                Column({ space: 5 }) {
                  Text($r('app.string.creator_public_income')).fontSize(16).fontColor($r('app.color.text'))
                  Text($r('app.string.creator_public_income_hint')).fontSize(12).fontColor($r('app.color.secondary'))
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: this.publicIncome }).selectedColor($r('app.color.accent'))
                  .enabled(this.privacySaving.length === 0)
                  .onChange((value: boolean): void => { this.savePrivacy('income', value); })
              }.padding(18).width('100%')
              Divider().color($r('app.color.separator'))
              Row({ space: 12 }) {
                Column({ space: 5 }) {
                  Text($r('app.string.creator_public_sponsor')).fontSize(16).fontColor($r('app.color.text'))
                  Text($r('app.string.creator_public_sponsor_hint')).fontSize(12).fontColor($r('app.color.secondary'))
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: this.publicSponsor }).selectedColor($r('app.color.accent'))
                  .enabled(this.privacySaving.length === 0)
                  .onChange((value: boolean): void => { this.savePrivacy('sponsor', value); })
              }.padding(18).width('100%')
            }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          }.width('100%').constraintSize({ maxWidth: 760 }).padding({ left: 16, right: 16,
            top: this.topInset + 64, bottom: this.bottomInset + 24 })
        }.width('100%').height('100%').scrollBar(BarState.Off)
      }
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: $r('app.string.creator_settings') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
