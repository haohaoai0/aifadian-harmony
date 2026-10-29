import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { FaqItem } from '../models/FaqModels';
import { faqApi } from '../services/FaqApi';
import { navigationStyle } from '../utils/NavigationStyle';
import { StateView } from '../components/Common';

@Component
export struct FaqSettingsDestination {
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @State faqs: FaqItem[] = [];
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State editorVisible: boolean = false;
  @State editingId: number = 0;
  @State title: string = '';
  @State content: string = '';
  @State saving: boolean = false;
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
    this.failed = false;
    try {
      const faqs: FaqItem[] = await faqApi.list();
      if (generation === this.generation) { this.faqs = faqs; }
    } catch (error) {
      if (generation === this.generation) { this.failed = true; }
    } finally {
      if (generation === this.generation) { this.loading = false; }
    }
  }
  private edit(item?: FaqItem): void {
    this.editingId = item?.id ?? 0;
    this.title = item?.title ?? '';
    this.content = item?.content ?? '';
    this.editorVisible = true;
  }
  private async save(): Promise<void> {
    if (this.saving || this.title.trim().length === 0 || this.content.trim().length === 0) {
      this.toast($r('app.string.faq_fields_required'));
      return;
    }
    this.saving = true;
    try {
      await faqApi.save(this.editingId, this.title.trim(), this.content.trim());
      this.editorVisible = false;
      await this.load();
      this.toast($r('app.string.faq_saved'));
    } catch (error) {
      this.toast($r('app.string.faq_save_failed'));
    } finally {
      this.saving = false;
    }
  }
  private remove(item: FaqItem): void {
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.faq_delete_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.confirm'), color: $r('app.color.danger') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1) { return; }
      try {
        await faqApi.remove(item.id);
        this.faqs = this.faqs.filter((faq: FaqItem): boolean => faq.id !== item.id);
        this.toast($r('app.string.faq_deleted'));
      } catch (error) {
        this.toast($r('app.string.faq_delete_failed'));
      }
    });
  }
  @Builder private FaqRow(item: FaqItem) {
    Column({ space: 10 }) {
      Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).width('100%')
      Text(item.content).fontSize(14).lineHeight(22).fontColor($r('app.color.secondary')).width('100%').maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 8 }) {
        Blank()
        Button($r('app.string.faq_edit')).height(34).backgroundColor($r('app.color.accent_soft'))
          .fontColor($r('app.color.accent')).onClick((): void => this.edit(item))
        Button($r('app.string.faq_delete')).height(34).backgroundColor(Color.Transparent)
          .fontColor($r('app.color.danger')).onClick((): void => this.remove(item))
      }.width('100%')
    }.width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(16)
  }
  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          Row() {
            Text($r('app.string.faq_title')).fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text')).layoutWeight(1)
            Button($r('app.string.faq_add')).height(38).backgroundColor($r('app.color.accent'))
              .onClick((): void => this.edit())
          }.width('100%')
          if (this.editorVisible) {
            Column({ space: 12 }) {
              Text(this.editingId > 0 ? $r('app.string.faq_edit') : $r('app.string.faq_add'))
                .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).width('100%')
              TextInput({ text: this.title, placeholder: $r('app.string.faq_question') }).height(50).width('100%')
                .backgroundColor($r('app.color.canvas')).borderRadius(12)
                .onChange((value: string): void => { this.title = value; })
              TextArea({ text: this.content, placeholder: $r('app.string.faq_answer') }).height(130).width('100%')
                .backgroundColor($r('app.color.canvas')).borderRadius(12)
                .onChange((value: string): void => { this.content = value; })
              Row({ space: 10 }) {
                Button($r('app.string.cancel')).layoutWeight(1).height(42).backgroundColor($r('app.color.canvas'))
                  .fontColor($r('app.color.secondary')).onClick((): void => { this.editorVisible = false; })
                Button(this.saving ? $r('app.string.saving') : $r('app.string.account_save')).layoutWeight(1).height(42)
                  .backgroundColor($r('app.color.accent')).enabled(!this.saving).onClick((): void => { this.save(); })
              }.width('100%')
            }.width('100%').padding(16).backgroundColor($r('app.color.accent_soft')).borderRadius(16)
          }
          if (this.loading || this.failed) {
            StateView({ loading: this.loading, error: this.failed, onAction: (): void => { this.load(); } })
          } else if (this.faqs.length === 0) {
            StateView({ title: $r('app.string.faq_empty') })
          } else {
            ForEach(this.faqs, (faq: FaqItem) => {
              this.FaqRow(faq)
            }, (faq: FaqItem): string => faq.id.toString())
          }
        }.width('100%').constraintSize({ maxWidth: 760 }).padding({ left: 16, right: 16,
          top: this.topInset + 64, bottom: this.bottomInset + 24 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: $r('app.string.faq_title') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
