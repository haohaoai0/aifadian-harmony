import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { messageApi } from '../services/MessageApi';
import { appStore } from '../services/AppStore';
import { RouteParam, plainText } from '../models/Models';
import { MessageEntry, MessageFAQ, MessageHistory, MessageOrderContent, mergeMessages } from '../models/MessageModels';
import { Avatar, StateView } from '../components/Common';
import { navigationStyle } from '../utils/NavigationStyle';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { formatDateTime } from '../utils/DisplayTime';
import { afdianPreferredOrigin } from '../common/UrlPolicy';

@Component
export struct MessageDestination {
  @Consume('pageStack') stack: NavPathStack;
  @Prop userId: string = '';
  @Prop userName: string = '';
  @Prop avatar: string = '';
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 0;
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @StorageProp('afd.foreground') @Watch('foregroundChanged') foreground: boolean = true;
  @StorageProp('afd.sessionRevision') @Watch('sessionChanged') revision: number = 0;
  @State entries: MessageEntry[] = [];
  @State loading: boolean = false;
  @State loadingHistory: boolean = false;
  @State failed: boolean = false;
  @State hasMore: boolean = false;
  @State sending: boolean = false;
  @State draft: string = '';
  @State errorText: string = '';
  @State composerHeight: number = 100;
  @State faqs: MessageFAQ[] = [];
  @State showFaqs: boolean = false;
  @State loadingFaqs: boolean = false;
  private scroller: Scroller = new Scroller();
  private active: boolean = false;
  private generation: number = 0;
  private timer: number = -1;
  private firstVisible: number = 0;
  private polling: boolean = false;
  private keyboardMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  aboutToDisappear(): void { this.stop(); this.draft = ''; }
  sessionChanged(): void { this.stop(); this.entries = []; this.draft = ''; this.sending = false; this.errorText = ''; }
  foregroundChanged(): void {
    this.clearTimer();
    if (this.foreground && this.active && this.loggedIn) { this.poll(); }
  }
  private clearTimer(): void { if (this.timer !== -1) { clearTimeout(this.timer); this.timer = -1; } }
  private stop(): void { this.active = false; this.generation++; this.clearTimer(); this.polling = false; this.loadingHistory = false; }
  private valid(generation: number): boolean { return this.active && this.loggedIn && generation === this.generation; }
  private refreshDialogs(): void { AppStorage.setOrCreate<number>('afd.messagesRevision', (AppStorage.get<number>('afd.messagesRevision') ?? 0) + 1); }
  private bottom(): void {
    const generation: number = this.generation;
    setTimeout((): void => { if (this.valid(generation)) { this.scroller.scrollEdge(Edge.Bottom); } }, 50);
  }
  private async open(): Promise<void> {
    this.active = true;
    const generation: number = ++this.generation;
    this.clearTimer(); this.loading = this.entries.length === 0; this.failed = false;
    if (!this.loggedIn || this.userId.length === 0) { this.loading = false; return; }
    try {
      const historyPromise: Promise<MessageHistory> = messageApi.history(this.userId);
      const faqPromise: Promise<MessageFAQ[]> = messageApi.faqs(this.userId).catch((): MessageFAQ[] => []);
      this.loadingFaqs = true;
      const results: [MessageHistory, MessageFAQ[]] = await Promise.all([historyPromise, faqPromise]);
      if (!this.valid(generation)) { return; }
      this.entries = mergeMessages([], results[0].list ?? []); this.hasMore = results[0].has_more === 1;
      this.faqs = results[1];
      this.refreshDialogs(); this.bottom();
    } catch (error) { if (this.valid(generation)) { this.failed = true; } }
    finally { if (this.valid(generation)) { this.loading = false; this.loadingFaqs = false; this.schedule(); } }
  }
  private schedule(): void {
    this.clearTimer();
    if (this.active && this.foreground && this.loggedIn) { this.timer = setTimeout((): void => { this.timer = -1; this.poll(); }, 5000); }
  }
  private async poll(): Promise<void> {
    if (this.polling || this.loading || !this.active || !this.foreground || !this.loggedIn) { this.schedule(); return; }
    if (this.entries.length === 0) { this.open(); return; }
    const generation: number = this.generation;
    const cursor: string = this.entries[this.entries.length - 1].message.msg_id;
    this.polling = true;
    try {
      const page: MessageHistory = await messageApi.history(this.userId, cursor, true);
      if (!this.valid(generation)) { return; }
      const atBottom: boolean = this.scroller.isAtEnd();
      const oldCount: number = this.entries.length;
      this.entries = mergeMessages(this.entries, page.list ?? []);
      if (this.entries.length > oldCount) { this.refreshDialogs(); if (atBottom) { this.bottom(); } }
    } catch (error) {}
    finally { if (this.valid(generation)) { this.polling = false; this.schedule(); } }
  }
  private async older(): Promise<void> {
    if (this.loadingHistory || this.entries.length === 0 || !this.hasMore) { return; }
    const generation: number = this.generation;
    const cursor: string = this.entries[0].message.msg_id;
    this.loadingHistory = true;
    try {
      const page: MessageHistory = await messageApi.history(this.userId, cursor);
      if (!this.valid(generation)) { return; }
      const previousCount: number = this.entries.length;
      const hadHeader: boolean = this.hasMore;
      const first: number = this.firstVisible;
      this.entries = mergeMessages(this.entries, page.list ?? [], true); this.hasMore = page.has_more === 1;
      const inserted: number = this.entries.length - previousCount;
      if (inserted > 0) {
        const index: number = Math.max(0, first + inserted + (this.hasMore ? 1 : 0) - (hadHeader ? 1 : 0));
        setTimeout((): void => { if (this.valid(generation)) { this.scroller.scrollToIndex(index, false, ScrollAlign.START); } }, 50);
      }
    } catch (error) { if (this.valid(generation)) { this.errorText = (error as Error).message; } }
    finally { if (this.valid(generation)) { this.loadingHistory = false; } }
  }
  private async send(): Promise<void> {
    const content: string = this.draft.trim();
    if (this.sending || content.length === 0 || !this.loggedIn) { return; }
    const generation: number = this.generation;
    this.sending = true; this.errorText = '';
    try {
      const entry: MessageEntry = await messageApi.sendText(this.userId, content);
      if (!this.valid(generation)) { return; }
      if (!entry.message?.msg_id) { throw new Error(this.text($r('app.string.dm_send_unknown'))); }
      this.entries = mergeMessages(this.entries, [entry]);
      if (this.draft.trim() === content) { this.draft = ''; }
      this.refreshDialogs(); this.bottom();
    } catch (error) {
      if (this.valid(generation)) { this.errorText = (error as Error).message + '\n' + this.text($r('app.string.dm_send_check')); }
    } finally { this.sending = false; }
  }
  private async askFaq(faq: MessageFAQ): Promise<void> {
    if (this.sending || !this.loggedIn) { return; }
    const generation: number = this.generation;
    this.sending = true;
    this.errorText = '';
    try {
      const entry: MessageEntry = await messageApi.askFaq(this.userId, faq.id);
      if (!this.valid(generation)) { return; }
      if (!entry.message?.msg_id) { throw new Error(this.text($r('app.string.dm_send_unknown'))); }
      this.entries = mergeMessages(this.entries, [entry]);
      this.showFaqs = false;
      this.refreshDialogs();
      this.bottom();
    } catch (error) {
      if (this.valid(generation)) { this.errorText = this.text($r('app.string.dm_faq_send_failed')); }
    } finally {
      if (this.valid(generation)) { this.sending = false; }
    }
  }
  private text(resource: Resource): string { return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? ''; }
  private displayTime(value: number): string { return formatDateTime(value); }
  private orderText(entry: MessageEntry): string {
    const value: MessageOrderContent = entry.message.content as MessageOrderContent;
    return (value.plan?.name ?? '') + (value.total_amount ? '\n¥' + value.total_amount : '') + (value.remark ? '\n' + value.remark : '');
  }
  private web(): void { this.stack.pushPath({ name: 'Web', param: new RouteParam(
    afdianPreferredOrigin(appStore.getRoute()) + '/message/' + encodeURIComponent(this.userId), this.userName) }); }
  @Builder private Bubble(entry: MessageEntry) {
    Column({ space: 6 }) {
      Text(this.displayTime(entry.message.send_time)).fontSize(11).fontColor($r('app.color.secondary')).width('100%').textAlign(TextAlign.Center)
      Row({ space: 8 }) {
        if (entry.type === 'send') { Blank().width(32) }
        else { Avatar({ src: this.avatar, diameter: 32 }) }
        Column({ space: 8 }) {
          if (String(entry.message.type) === '3' && typeof entry.message.content === 'string') {
            Image(entry.message.content || entry.message.url).width('100%').constraintSize({ maxWidth: 280, maxHeight: 320 })
              .objectFit(ImageFit.Contain).borderRadius(12).onClick((): void => this.web())
          } else if (typeof entry.message.content === 'string') {
            Text(plainText(entry.message.content)).fontSize(16).lineHeight(24).fontColor($r('app.color.text')).copyOption(CopyOptions.LocalDevice)
          } else {
            Text($r('app.string.dm_order_message')).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
            Text(this.orderText(entry)).fontSize(15).fontColor($r('app.color.text'))
            Button($r('app.string.dm_view_detail')).fontColor($r('app.color.accent')).backgroundColor(Color.Transparent).onClick((): void => this.web())
          }
        }.padding(14).constraintSize({ maxWidth: '80%' }).alignItems(HorizontalAlign.Start)
          .backgroundColor(entry.type === 'send' ? $r('app.color.message_sent') : $r('app.color.surface')).borderRadius(18)
        if (entry.type === 'send') { Avatar({ src: appStore.getUser().avatar, diameter: 32 }) } else { Blank().width(32) }
      }.width('100%').justifyContent(entry.type === 'send' ? FlexAlign.End : FlexAlign.Start).alignItems(VerticalAlign.Top)
    }.width('100%')
  }
  @Builder private Composer() {
    Column({ space: 8 }) {
      if (this.errorText.length > 0) { Text(this.errorText).fontSize(13).fontColor($r('app.color.danger')).width('100%') }
      if (this.showFaqs) {
        if (this.loadingFaqs) {
          LoadingProgress().width(24).height(24).color($r('app.color.accent'))
        } else if (this.faqs.length > 0) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.faqs, (faq: MessageFAQ) => {
                Button(faq.title).height(34).borderRadius(17).backgroundColor($r('app.color.accent_soft'))
                  .fontColor($r('app.color.accent')).enabled(!this.sending)
                  .onClick((): void => { this.askFaq(faq); })
              }, (faq: MessageFAQ): string => faq.id.toString())
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        }
      }
      Row({ space: 10 }) {
        TextArea({ text: this.draft, placeholder: $r('app.string.dm_input') }).layoutWeight(1).height(56)
          .backgroundColor($r('app.color.canvas')).fontColor($r('app.color.text')).borderRadius(16)
          .onChange((value: string): void => { this.draft = value; })
        Button($r('app.string.dm_faq_short')).height(48).width(48).borderRadius(16)
          .backgroundColor(this.showFaqs ? $r('app.color.accent_soft') : $r('app.color.canvas'))
          .fontColor($r('app.color.accent')).enabled(this.faqs.length > 0 || this.loadingFaqs)
          .onClick((): void => { this.showFaqs = !this.showFaqs; })
        Button(this.sending ? $r('app.string.dm_sending') : $r('app.string.dm_send')).height(48)
          .enabled(!this.sending && this.draft.trim().length > 0).backgroundColor($r('app.color.accent'))
          .onClick((): void => { this.send(); })
      }.width('100%')
    }.padding({ left: 16, right: 16, top: 10, bottom: this.bottomInset + 8 }).width('100%').backgroundColor($r('app.color.surface'))
      .onAreaChange((oldArea: Area, area: Area): void => { this.composerHeight = Number(area.height); })
  }
  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.BottomStart }) {
        List({ space: 16, scroller: this.scroller }) {
          if (!this.loggedIn) { ListItem() { Column({ space: 16 }) {
            StateView({ title: $r('app.string.login_hint') })
            Button($r('app.string.login')).onClick((): void => this.stack.pushPath({ name: 'Login' }))
          }.width('100%') } }
          else {
            if (this.hasMore) { ListItem() { Button(this.loadingHistory ? $r('app.string.dm_loading_history') : $r('app.string.dm_history'))
              .enabled(!this.loadingHistory).backgroundColor(Color.Transparent).fontColor($r('app.color.accent')).onClick((): void => { this.older(); }) } }
            if (this.entries.length === 0) { ListItem() { StateView({ loading: this.loading, error: this.failed,
              title: this.failed ? '' : $r('app.string.dm_empty'), onAction: (): void => { this.open(); } }) } }
            ForEach(this.entries, (entry: MessageEntry) => { ListItem() { this.Bubble(entry) } }, (entry: MessageEntry): string => entry.message.msg_id)
          }
        }.width('100%').height('100%').padding({ left: 16, right: 16 })
          .contentStartOffset(this.topInset + 64).contentEndOffset(this.composerHeight + 16).scrollBar(BarState.Off)
          .onScrollIndex((start: number): void => { this.firstVisible = start; })
        if (this.loggedIn) { this.Composer() }
      }.width('100%').height('100%')
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: this.userName || $r('app.string.messages') } } }).titleMode(HdsNavDestinationTitleMode.MINI)
      .backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
      .onShown((): void => {
        this.keyboardMode = this.getUIContext().getKeyboardAvoidMode();
        this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE); this.open();
      }).onHidden((): void => { this.stop(); this.getUIContext().setKeyboardAvoidMode(this.keyboardMode); })
  }
}
