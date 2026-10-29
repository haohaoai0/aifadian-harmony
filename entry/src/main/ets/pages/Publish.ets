import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { CreatorPlan } from '../models/Models';
import { PublishRequest, publishApi } from '../services/PublishApi';
import { navigationStyle } from '../utils/NavigationStyle';

@Component
export struct PublishDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.material') material: boolean = true;
  @State title: string = '';
  @State content: string = '';
  @State cover: string = '';
  @State visibilityMode: number = 1;
  @State plans: CreatorPlan[] = [];
  @State selectedPlan: number = -1;
  @State loadingPlans: boolean = false;
  @State publishing: boolean = false;
  @State errorText: string = '';
  @State showPreview: boolean = false;
  @State showCover: boolean = false;
  private generation: number = 0;

  aboutToAppear(): void { this.loadPlans(); }
  aboutToDisappear(): void { this.generation++; }

  private async loadPlans(): Promise<void> {
    const generation: number = ++this.generation;
    this.loadingPlans = true;
    try {
      const result: CreatorPlan[] = await publishApi.plans();
      if (generation === this.generation) {
        this.plans = result.filter((plan: CreatorPlan): boolean => plan.plan_id.length > 0);
      }
    } catch (error) {
    } finally {
      if (generation === this.generation) { this.loadingPlans = false; }
    }
  }

  private text(resource: Resource): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? '';
  }

  private planLabel(plan: CreatorPlan): string {
    const price: string = plan.show_price || plan.price;
    return price.length > 0 ? '¥' + price + ' 及以上 · ' + plan.name : plan.name;
  }

  private selectedPlanIds(): string[] {
    if (this.visibilityMode !== 2 || this.selectedPlan < 0 || this.selectedPlan >= this.plans.length) { return []; }
    return [this.plans[this.selectedPlan].plan_id];
  }

  private scopeText(): string {
    if (this.visibilityMode === 0) { return this.text($r('app.string.publish_visibility_public')); }
    if (this.visibilityMode === 1) { return this.text($r('app.string.publish_visibility_sponsors')); }
    if (this.selectedPlan >= 0 && this.selectedPlan < this.plans.length) {
      return this.planLabel(this.plans[this.selectedPlan]);
    }
    return this.text($r('app.string.publish_visibility_choose_plan'));
  }

  private scopeMenu(): MenuElement[] {
    const menu: MenuElement[] = [];
    const publicItem: MenuElement = { value: this.text($r('app.string.publish_visibility_public')),
      action: (): void => { this.visibilityMode = 0; } };
    const sponsorItem: MenuElement = { value: this.text($r('app.string.publish_visibility_sponsors')),
      action: (): void => { this.visibilityMode = 1; } };
    menu.push(publicItem);
    menu.push(sponsorItem);
    for (let i: number = 0; i < this.plans.length; i++) {
      const plan: CreatorPlan = this.plans[i];
      const item: MenuElement = { value: this.planLabel(plan),
        action: (): void => { this.selectedPlan = i; this.visibilityMode = 2; } };
      menu.push(item);
    }
    return menu;
  }

  private moreMenu(): MenuElement[] {
    const draft: MenuElement = { value: this.text($r('app.string.publish_save_draft')),
      action: (): void => this.unsupported() };
    const timing: MenuElement = { value: this.text($r('app.string.publish_timing')),
      action: (): void => this.unsupported() };
    return [draft, timing];
  }

  private unsupported(): void {
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.publish_feature_soon') });
  }

  private close(): void {
    if (this.title.trim().length === 0 && this.content.trim().length === 0) { this.stack.pop(); return; }
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.publish_discard_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.publish_discard'), color: $r('app.color.danger') }
    ] }).then((result): void => {
      if (result.index === 1) { this.stack.pop(); }
    });
  }

  private validate(): boolean {
    if (this.content.trim().length === 0) {
      this.errorText = this.text($r('app.string.publish_content_required')); return false;
    }
    if (this.visibilityMode === 2 && this.selectedPlanIds().length === 0) {
      this.errorText = this.text($r('app.string.publish_plan_required')); return false;
    }
    return true;
  }

  private async publish(): Promise<void> {
    if (this.publishing || !this.validate()) { return; }
    this.publishing = true; this.errorText = '';
    try {
      const request: PublishRequest = new PublishRequest();
      request.title = this.title;
      request.content = this.content;
      request.cover = this.cover;
      request.isPublic = this.visibilityMode === 0;
      request.planIds = this.selectedPlanIds();
      await publishApi.publish(request);
      AppStorage.setOrCreate<number>('afd.feedRevision', (AppStorage.get<number>('afd.feedRevision') ?? 0) + 1);
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.publish_success') });
      this.stack.pop();
    } catch (error) {
      this.errorText = (error as Error).message;
    } finally {
      this.publishing = false;
    }
  }

  @Builder private TitleBarContent() {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.xmark')).fontSize(23).fontColor([$r('app.color.text')])
      }.width(40).height(40).backgroundColor(Color.Transparent).accessibilityText($r('app.string.publish_close'))
        .onClick((): void => this.close())
      Text($r('app.string.publish_new_post')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
      Button({ type: ButtonType.Normal }) {
        Row({ space: 5 }) {
          Text(this.loadingPlans ? $r('app.string.loading') : $r('app.string.publish_choose_plan')).fontSize(14)
            .fontColor($r('app.color.secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(12).fontColor([$r('app.color.secondary')])
        }
      }.height(38).padding({ left: 8, right: 8 }).backgroundColor(Color.Transparent).bindMenu(this.scopeMenu())
      Blank()
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(22).fontColor([$r('app.color.text')])
      }.width(40).height(40).backgroundColor(Color.Transparent).bindMenu(this.moreMenu())
        .accessibilityText($r('app.string.publish_more'))
      Button(this.publishing ? $r('app.string.publishing') : $r('app.string.publish_action'))
        .height(40).padding({ left: 18, right: 18 }).backgroundColor($r('app.color.accent'))
        .enabled(!this.publishing).onClick((): void => { this.publish(); })
    }.width('100%').height('100%').padding({ left: 4, right: 4 }).id('publish-official-title')
  }

  @Builder private ToolItem(label: Resource, symbol: Resource, color: Resource) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 5 }) {
        SymbolGlyph(symbol).fontSize(20).fontColor([color])
        Text(label).fontSize(13).fontColor($r('app.color.secondary'))
      }
    }.layoutWeight(1).height(48).backgroundColor(Color.Transparent).onClick((): void => this.unsupported())
  }

  @Builder private BottomToolbar() {
    Row({ space: 2 }) {
      this.ToolItem($r('app.string.publish_tool_image'), $r('sys.symbol.ohos_photo'), $r('app.color.tool_green'))
      this.ToolItem($r('app.string.publish_tool_audio'), $r('sys.symbol.waveform'), $r('app.color.tool_blue'))
      this.ToolItem($r('app.string.publish_tool_video'), $r('sys.symbol.video'), $r('app.color.tool_pink'))
      this.ToolItem($r('app.string.publish_tool_article'), $r('sys.symbol.doc_text'), $r('app.color.tool_orange'))
      this.ToolItem($r('app.string.publish_tool_poll'), $r('sys.symbol.list_bullet'), $r('app.color.tool_blue'))
    }.width('100%').height(60).padding({ left: 6, right: 6 }).backgroundColor($r('app.color.surface'))
      .border({ width: { top: 1 }, color: $r('app.color.separator') })
  }

  build() {
    HdsNavDestination() {
      Column() {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text(this.scopeText()).fontSize(15).fontColor($r('app.color.text')).layoutWeight(1).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor([$r('app.color.secondary')])
            }.width(32).height(32).backgroundColor(Color.Transparent).onClick((): void => { this.visibilityMode = 1; })
          }.width('100%').padding({ top: 8, bottom: 8 })
          TextInput({ text: this.title, placeholder: $r('app.string.publish_title') })
            .height(52).width('100%').backgroundColor(Color.Transparent).fontSize(20)
            .fontColor($r('app.color.text')).placeholderColor($r('app.color.secondary'))
            .onChange((value: string): void => { this.title = value; })
          TextArea({ text: this.content, placeholder: $r('app.string.publish_content_official') })
            .layoutWeight(1).width('100%').backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text')).placeholderColor($r('app.color.secondary'))
            .onChange((value: string): void => { this.content = value; })
          if (this.errorText.length > 0) {
            Text(this.errorText).fontSize(13).fontColor($r('app.color.danger')).width('100%')
          }
        }.layoutWeight(1).width('100%').padding({ left: 18, right: 18 })

        Column() {
          Row({ space: 12 }) {
            Text($r('app.string.publish_add_album')).fontSize(15).fontColor($r('app.color.secondary')).layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.secondary')])
          }.height(52).width('100%').padding({ left: 18, right: 18 })
            .onClick((): void => this.unsupported())
          Divider().color($r('app.color.separator'))
          Row({ space: 12 }) {
            Text($r('app.string.publish_preview')).fontSize(15).fontColor($r('app.color.secondary')).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.showPreview }).selectedColor($r('app.color.accent'))
              .onChange((value: boolean): void => { this.showPreview = value; })
          }.height(52).width('100%').padding({ left: 18, right: 18 })
          Divider().color($r('app.color.separator'))
          Row({ space: 12 }) {
            Text($r('app.string.publish_cover_switch')).fontSize(15).fontColor($r('app.color.secondary')).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.showCover }).selectedColor($r('app.color.accent'))
              .onChange((value: boolean): void => { this.showCover = value; })
          }.height(52).width('100%').padding({ left: 18, right: 18 })
          if (this.showCover) {
            TextInput({ text: this.cover, placeholder: $r('app.string.publish_cover') })
              .height(46).margin({ left: 18, right: 18, bottom: 10 }).backgroundColor($r('app.color.canvas')).borderRadius(10)
              .onChange((value: string): void => { this.cover = value; })
          }
        }.width('100%').backgroundColor($r('app.color.surface'))
        this.BottomToolbar()
      }.width('100%').height('100%').padding({ top: this.topInset + 64, bottom: this.bottomInset })
        .backgroundColor($r('app.color.surface'))
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { stackBuilder: (): void => { this.TitleBarContent(); } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).hideBackButton(true).backgroundColor($r('app.color.surface'))
  }
}
