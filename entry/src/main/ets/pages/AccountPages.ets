import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { appStore } from '../services/AppStore';
import { afdianApi } from '../services/AfdianApi';
import { MessageItem, RouteParam, User, plainText } from '../models/Models';
import { NoticeItem, NoticePage } from '../models/NoticeModels';
import { Avatar, StateView } from '../components/Common';
import { rootScrollers } from '../utils/RootScrollers';
import { navigationStyle } from '../utils/NavigationStyle';
import { messageApi } from '../services/MessageApi';
import { formatDate } from '../utils/DisplayTime';
import { noticeApi } from '../services/NoticeApi';
import { afdianPreferredOrigin } from '../common/UrlPolicy';

@Component
export struct MessagesPage {
  @Prop endOffset: number = 104;
  @Prop @Watch('activityChanged') active: boolean = false;
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @StorageProp('afd.sessionRevision') @Watch('reload') revision: number = 0;
  @StorageProp('afd.messagesRevision') @Watch('reload') messagesRevision: number = 0;
  @StorageProp('afd.foreground') @Watch('activityChanged') foreground: boolean = true;
  @State messages: MessageItem[] = [];
  @State comments: NoticeItem[] = [];
  @State likes: NoticeItem[] = [];
  @State section: number = 0;
  @State loading: boolean = false;
  @State failed: boolean = false;
  @State hasMore: boolean = false;
  @State refreshing: boolean = false;
  @State noticeLoading: boolean = false;
  @State noticeFailed: boolean = false;
  @State noticeHasMore: boolean = false;
  @State markingAllRead: boolean = false;
  @State deletingDialog: string = '';
  private generation: number = 0;
  private noticeGeneration: number = 0;
  private page: number = 1;
  private noticeCursor: string = '';
  private busy: boolean = false;
  private timer: number = -1;
  aboutToAppear(): void { this.reload(); }
  aboutToDisappear(): void { this.generation++; this.clearTimer(); }
  private clearTimer(): void { if (this.timer !== -1) { clearTimeout(this.timer); this.timer = -1; } }
  activityChanged(): void {
    this.clearTimer();
    if (this.active && this.foreground && this.loggedIn) {
      if (this.section === 0) { this.load(true); } else { this.loadNotices(true); }
    }
  }
  reload(): void {
    this.messages = []; this.comments = []; this.likes = [];
    this.generation++; this.noticeGeneration++; this.busy = false;
    if (this.section === 0) { this.load(true); } else { this.loadNotices(true); }
  }
  private schedule(): void {
    this.clearTimer();
    if (this.active && this.foreground && this.loggedIn) { this.timer = setTimeout((): void => { this.timer = -1; this.load(true); }, 15000); }
  }
  private openConversation(item: MessageItem): void {
    this.messages = this.messages.map((message: MessageItem): MessageItem => {
      if (message.user.user_id !== item.user.user_id) { return message; }
      const cleared: MessageItem = new MessageItem();
      cleared.desc = message.desc;
      cleared.send_time = message.send_time;
      cleared.unread_count = 0;
      cleared.user = message.user;
      return cleared;
    });
    this.updateUnreadBadge();
    const param: RouteParam = new RouteParam(); param.userId = item.user.user_id; param.title = item.user.name; param.avatar = item.user.avatar;
    this.stack.pushPath({ name: 'Message', param: param });
  }
  private updateUnreadBadge(): void {
    let total: number = 0;
    for (let i: number = 0; i < this.messages.length; i++) {
      total += Math.max(0, this.messages[i].unread_count);
    }
    AppStorage.setOrCreate<number>('afd.unreadPrivate', total);
  }
  private markAllRead(): void {
    if (this.markingAllRead || this.messages.length === 0) { return; }
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.messages_mark_all_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.confirm'), color: $r('app.color.accent') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1 || this.markingAllRead) { return; }
      this.markingAllRead = true;
      try {
        const page = await messageApi.unreadDialogs();
        const unread: MessageItem[] = (page.list ?? []).filter((item: MessageItem): boolean => item.unread_count > 0);
        for (let i: number = 0; i < unread.length; i++) { await messageApi.markRead(unread[i].user.user_id); }
        this.messages = this.messages.map((message: MessageItem): MessageItem => {
          const cleared: MessageItem = new MessageItem();
          cleared.desc = message.desc;
          cleared.send_time = message.send_time;
          cleared.unread_count = 0;
          cleared.user = message.user;
          return cleared;
        });
        this.updateUnreadBadge();
      } catch (error) {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.messages_mark_all_failed') });
      } finally {
        this.markingAllRead = false;
      }
    });
  }
  private deleteDialog(item: MessageItem): void {
    if (this.deletingDialog.length > 0) { return; }
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.messages_delete_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.confirm'), color: $r('app.color.danger') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1) { return; }
      this.deletingDialog = item.user.user_id;
      try {
        await messageApi.deleteDialog(item.user.user_id);
        this.messages = this.messages.filter((message: MessageItem): boolean =>
          message.user.user_id !== item.user.user_id);
        this.updateUnreadBadge();
      } catch (error) {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.report_error') });
      } finally {
        this.deletingDialog = '';
      }
    });
  }
  private selectSection(section: number): void {
    if (section === this.section) { return; }
    this.section = section;
    rootScrollers.messages.scrollEdge(Edge.Top);
    this.noticeGeneration++;
    this.noticeCursor = '';
    this.noticeHasMore = false;
    if (section === 0) { this.load(true); }
    else if ((section === 1 ? this.comments.length : this.likes.length) === 0) { this.loadNotices(true); }
  }
  private noticeAction(): string { return this.section === 1 ? 'comment' : 'like'; }
  private async loadNotices(reset: boolean): Promise<void> {
    if (!this.loggedIn || this.section === 0) { return; }
    if (!reset && (this.noticeLoading || !this.noticeHasMore)) { return; }
    const section: number = this.section;
    const generation: number = reset ? ++this.noticeGeneration : this.noticeGeneration;
    if (reset) { this.noticeCursor = ''; this.noticeLoading = true; }
    this.noticeFailed = false;
    try {
      const page: NoticePage = await noticeApi.list(section === 1 ? 'comment' : 'like', this.noticeCursor);
      if (generation !== this.noticeGeneration || section !== this.section) { return; }
      const existing: NoticeItem[] = section === 1 ? this.comments : this.likes;
      const incoming: NoticeItem[] = (page.list ?? []).filter((item: NoticeItem): boolean => {
        const id: string = item.notice_id || item.id || item.publish_sn;
        return id.length > 0 && !existing.some((old: NoticeItem): boolean =>
          (old.notice_id || old.id || old.publish_sn) === id);
      });
      if (section === 1) { this.comments = reset ? (page.list ?? []) : this.comments.concat(incoming); }
      else { this.likes = reset ? (page.list ?? []) : this.likes.concat(incoming); }
      const all: NoticeItem[] = section === 1 ? this.comments : this.likes;
      const last: NoticeItem | undefined = all.length > 0 ? all[all.length - 1] : undefined;
      this.noticeCursor = last === undefined ? '' : (last.publish_sn || last.notice_id || last.id);
      this.noticeHasMore = page.hasMore && this.noticeCursor.length > 0 && incoming.length > 0;
    } catch (error) {
      if (generation === this.noticeGeneration) { this.noticeFailed = true; }
    } finally {
      if (generation === this.noticeGeneration) { this.noticeLoading = false; this.refreshing = false; }
    }
  }
  private openNotice(item: NoticeItem): void {
    const postId: string = item.post.post_id || item.post_id;
    if (postId.length === 0) { return; }
    const param: RouteParam = new RouteParam();
    param.postId = postId;
    this.stack.pushPath({ name: 'Post', param: param });
  }
  private noticeText(item: NoticeItem): string {
    if (item.comment_text.length > 0) { return plainText(item.comment_text); }
    if (item.subject.length > 0) { return item.subject; }
    if (typeof item.desc === 'string' && item.desc.length > 0) { return item.desc; }
    if (typeof item.content === 'string' && item.content.length > 0) { return plainText(item.content); }
    if (item.post.title.length > 0) { return item.post.title; }
    return this.section === 1 ? this.text($r('app.string.messages_comment_hint')) : this.text($r('app.string.messages_like_hint'));
  }
  private noticeTime(item: NoticeItem): string { return formatDate(item.time || item.create_time || item.send_time); }
  private text(resource: Resource): string { return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? ''; }
  private async load(reset: boolean): Promise<void> {
    if (!this.loggedIn) { this.messages = []; this.loading = false; this.refreshing = false; this.clearTimer(); return; }
    if (this.busy && !reset) { return; }
    this.busy = true; this.failed = false;
    const generation: number = reset ? ++this.generation : this.generation;
    if (reset) { this.page = 1; this.loading = true; }
    try {
      const data = await messageApi.dialogs(this.page);
      if (generation !== this.generation) { return; }
      const incoming: MessageItem[] = (data.list ?? []).filter((item: MessageItem): boolean => !!item.user?.user_id);
      this.messages = reset ? incoming : this.messages.concat(incoming.filter((item: MessageItem): boolean => !this.messages.some((old: MessageItem): boolean => old.user.user_id === item.user.user_id)));
      this.hasMore = data.has_more === 1; this.page++;
      this.updateUnreadBadge();
    } catch (error) { if (generation === this.generation) { this.failed = true; } }
    finally { if (generation === this.generation) { this.loading = false; this.busy = false; this.refreshing = false; this.schedule(); } }
  }
  @Builder private SectionTab(index: number, label: Resource) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        Text(label).fontSize(15).fontWeight(this.section === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.section === index ? $r('app.color.accent') : $r('app.color.secondary'))
        Row().height(3).width(28).borderRadius(2).backgroundColor(this.section === index ? $r('app.color.accent') : Color.Transparent)
      }.height(48).justifyContent(FlexAlign.Center)
    }.layoutWeight(1).backgroundColor(Color.Transparent).onClick((): void => this.selectSection(index))
      .accessibilityText(label).accessibilitySelected(this.section === index)
  }
  @Builder private NoticeRow(item: NoticeItem) {
    Row({ space: 12 }) {
      Avatar({ src: item.user?.avatar ?? '' })
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(item.user?.name || $r('app.string.creator')).fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text')).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.noticeTime(item)).fontSize(11).fontColor($r('app.color.secondary'))
        }.width('100%')
        Text(this.noticeText(item)).fontSize(14).fontColor($r('app.color.secondary')).maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (item.post.thumb.length > 0) {
        Image(item.post.thumb).width(56).height(56).objectFit(ImageFit.Cover).borderRadius(10)
      }
      if (item.unread > 0) {
        Column().width(8).height(8).borderRadius(4).backgroundColor($r('app.color.accent'))
      }
    }.padding(18).width('100%').backgroundColor($r('app.color.surface')).borderRadius(18)
      .onClick((): void => this.openNotice(item))
  }
  build() {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 8, scroller: rootScrollers.messages }) {
            ListItem() {
              Row() {
                this.SectionTab(0, $r('app.string.messages_private'))
                this.SectionTab(1, $r('app.string.messages_comments'))
                this.SectionTab(2, $r('app.string.messages_likes'))
              }.width('100%').backgroundColor($r('app.color.canvas'))
            }
            if (!this.loggedIn) { ListItem() { Column({ space: 16 }) {
              StateView({ title: $r('app.string.login_hint') })
              Button($r('app.string.login')).backgroundColor($r('app.color.accent')).onClick((): void => this.stack.pushPath({ name: 'Login' }))
            }.width('100%') } } else {
            if (this.section === 0) {
            if (this.messages.length > 0) {
              ListItem() {
                Row({ space: 10 }) {
                  Text($r('app.string.messages_unread_count', this.messages.reduce((total: number, item: MessageItem): number =>
                    total + Math.max(0, item.unread_count), 0).toString()))
                    .fontSize(13).fontColor($r('app.color.secondary')).layoutWeight(1)
                  Button(this.markingAllRead ? $r('app.string.loading') : $r('app.string.messages_mark_all_read'))
                    .height(34).borderRadius(17).backgroundColor($r('app.color.surface'))
                    .fontColor($r('app.color.accent')).enabled(!this.markingAllRead)
                    .onClick((): void => this.markAllRead())
                }.width('100%').padding({ left: 4, right: 4, top: 2, bottom: 2 })
              }
            }
            if (this.messages.length === 0) { ListItem() { StateView({ loading: this.loading, error: this.failed, onAction: (): void => this.reload() }) } }
            ForEach(this.messages, (item: MessageItem) => {
              ListItem() {
                Row({ space: 12 }) {
                  Avatar({ src: item.user.avatar })
                  Column({ space: 6 }) {
                    Row({ space: 8 }) {
                      Text(item.user.name).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(formatDate(item.send_time)).fontSize(11).fontColor($r('app.color.secondary'))
                    }.width('100%')
                    Text(item.desc).fontSize(14).fontColor($r('app.color.secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  if (item.unread_count > 0) { Text(item.unread_count.toString()).fontSize(12).fontColor(Color.White).padding(7).borderRadius(20).backgroundColor($r('app.color.accent')) }
                }.padding(18).width('100%').backgroundColor($r('app.color.surface')).borderRadius(18)
                  .gesture(GestureGroup(GestureMode.Exclusive,
                    LongPressGesture({ repeat: false, duration: 650 })
                      .onAction((): void => this.deleteDialog(item)),
                    TapGesture({ count: 1 }).onAction((): void => this.openConversation(item))))
              }
            }, (item: MessageItem): string => item.user.user_id)
            if (this.hasMore) { ListItem() { Button($r('app.string.load_more')).onClick((): void => { this.load(false); }).backgroundColor(Color.Transparent).fontColor($r('app.color.accent')) } }
            } else {
              if (this.noticeLoading || this.noticeFailed) {
                ListItem() { StateView({ loading: this.noticeLoading, error: this.noticeFailed,
                  onAction: (): void => { this.loadNotices(true); } }) }
              } else if (this.section === 1) {
                if (this.comments.length === 0) {
                  ListItem() { StateView({ title: $r('app.string.messages_no_comments') }) }
                }
                ForEach(this.comments, (item: NoticeItem) => {
                  ListItem() { this.NoticeRow(item) }
                }, (item: NoticeItem): string => item.notice_id || item.id || item.publish_sn)
                if (this.noticeHasMore) {
                  ListItem() { Button($r('app.string.load_more')).backgroundColor(Color.Transparent)
                    .fontColor($r('app.color.accent')).onClick((): void => { this.loadNotices(false); }) }
                }
              } else {
                if (this.likes.length === 0) {
                  ListItem() { StateView({ title: $r('app.string.messages_no_likes') }) }
                }
                ForEach(this.likes, (item: NoticeItem) => {
                  ListItem() { this.NoticeRow(item) }
                }, (item: NoticeItem): string => item.notice_id || item.id || item.publish_sn)
                if (this.noticeHasMore) {
                  ListItem() { Button($r('app.string.load_more')).backgroundColor(Color.Transparent)
                    .fontColor($r('app.color.accent')).onClick((): void => { this.loadNotices(false); }) }
                }
              }
            }
            }
          }.width('100%').height('100%').padding({ left: 16, right: 16 })
            .contentStartOffset(this.topInset + 64).contentEndOffset(this.endOffset).scrollBar(BarState.Off)
        }.width('100%').height('100%').onRefreshing((): void => {
          if (this.section === 0) { this.load(true); } else { this.loadNotices(true); }
        }).backgroundColor($r('app.color.canvas'))
  }
}

@Component
export struct ProfilePage {
  @Prop endOffset: number = 104;
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @StorageProp('afd.sessionRevision') @Watch('load') revision: number = 0;
  @State user: User = new User();
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    this.user = appStore.getUser();
    if (!this.loggedIn) { return; }
    try {
      const revision: number = this.revision;
      const data = await afdianApi.myProfile();
      if (revision === this.revision) {
        this.user = data.user;
        appStore.saveUser(data.user, false);
      }
    } catch (error) {}
  }
  @Builder private RowItem(title: Resource, symbol: Resource, path: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        SymbolGlyph(symbol).fontSize(22).fontColor([$r('app.color.accent')])
        Text(title).fontSize(16).fontColor($r('app.color.text')).layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.secondary')])
      }.padding(20).width('100%')
    }.backgroundColor($r('app.color.surface')).borderRadius(18)
      .onClick((): void => {
        if (path === 'Settings' || path === 'Income' || path === 'Sponsoring' ||
          path === 'AccountManagement' || path === 'Favorites' || path === 'CreatorSettings') {
          this.stack.pushPath({ name: path });
        }
        else if (!this.loggedIn) { this.stack.pushPath({ name: 'Login' }); }
        else { this.stack.pushPath({ name: 'Web', param: new RouteParam(afdianPreferredOrigin(appStore.getRoute()) + '/' + path, '') }); }
      })
  }
  build() {
    Scroll(rootScrollers.profile) {
      Column({ space: 12 }) {
        Column({ space: 14 }) {
          Avatar({ src: this.loggedIn ? this.user.avatar ?? '' : '', diameter: 82 })
          Text(this.loggedIn ? this.user.name || $r('app.string.profile') : $r('app.string.login_title')).fontSize(25).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
          Text($r('app.string.native_note')).fontSize(14).fontColor($r('app.color.secondary')).textAlign(TextAlign.Center)
          if (!this.loggedIn) { Button($r('app.string.login')).backgroundColor($r('app.color.accent')).width(160).onClick((): void => this.stack.pushPath({ name: 'Login' })) }
        }.padding(28).width('100%').backgroundColor($r('app.color.surface')).borderRadius(24).margin({ bottom: 10 })
        this.RowItem($r('app.string.sponsoring'), $r('sys.symbol.heart'), 'Sponsoring')
        this.RowItem($r('app.string.bookmarks'), $r('sys.symbol.bookmark'), 'Favorites')
        if (this.user.creator !== undefined) {
          this.RowItem($r('app.string.income'), $r('sys.symbol.creditcard'), 'Income')
          this.RowItem($r('app.string.creator_settings'), $r('sys.symbol.paintpalette'), 'CreatorSettings')
        }
        this.RowItem($r('app.string.account_settings'), $r('sys.symbol.person_fill'), 'AccountManagement')
        this.RowItem($r('app.string.settings'), $r('sys.symbol.gearshape'), 'Settings')
      }.padding({ left: 16, right: 16, top: this.topInset + 64, bottom: this.endOffset }).width('100%').constraintSize({ maxWidth: 760 })
    }.width('100%').height('100%').scrollBar(BarState.Off).backgroundColor($r('app.color.canvas'))
  }
}

@Component
export struct SettingsDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.theme') theme: string = 'system';
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @StorageProp('afd.route') route: string = 'ifdian';
  private scroller: Scroller = new Scroller();
  private text(resource: Resource): string { return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? ''; }
  private logout(): void {
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.logout_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') }, { text: $r('app.string.confirm'), color: $r('app.color.danger') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1) { return; }
      try { await afdianApi.request<Object>('/api/passport/logout'); } catch (error) {}
      await appStore.clearSession();
    });
  }
  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          Text($r('app.string.appearance')).fontSize(14).fontColor($r('app.color.secondary')).width('100%')
          Column() {
            Row({ space: 12 }) {
              Text($r('app.string.theme')).fontSize(16).fontColor($r('app.color.text')).layoutWeight(1)
              Select([{ value: this.text($r('app.string.system')) }, { value: this.text($r('app.string.light')) }, { value: this.text($r('app.string.dark')) }])
                .selected(this.theme === 'light' ? 1 : this.theme === 'dark' ? 2 : 0)
                .value(this.text(this.theme === 'light' ? $r('app.string.light') : this.theme === 'dark' ? $r('app.string.dark') : $r('app.string.system')))
                .onSelect((index: number): void => appStore.setTheme(index === 1 ? 'light' : index === 2 ? 'dark' : 'system'))
            }.padding(18).width('100%')
            Divider().color($r('app.color.separator'))
            Row({ space: 12 }) {
              Column({ space: 6 }) {
                Text($r('app.string.material')).fontSize(16).fontColor($r('app.color.text'))
                Text($r('app.string.material_hint')).fontSize(13).fontColor($r('app.color.secondary'))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.material }).selectedColor($r('app.color.accent')).onChange((value: boolean): void => appStore.setMaterial(value))
            }.padding(18).width('100%')
            Divider().color($r('app.color.separator'))
            Row({ space: 12 }) {
              Column({ space: 6 }) {
                Text($r('app.string.route_title')).fontSize(16).fontColor($r('app.color.text'))
                Text($r('app.string.route_hint')).fontSize(13).fontColor($r('app.color.secondary'))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Select([
                { value: this.text($r('app.string.route_ifdian')) },
                { value: this.text($r('app.string.route_afdian')) },
                { value: this.text($r('app.string.route_www')) }
              ]).selected(this.route === 'afdian' ? 1 : this.route === 'www' ? 2 : 0)
                .value(this.text(this.route === 'afdian' ? $r('app.string.route_afdian') :
                  this.route === 'www' ? $r('app.string.route_www') : $r('app.string.route_ifdian')))
                .onSelect((index: number): void => {
                  appStore.setRoute(index === 1 ? 'afdian' : index === 2 ? 'www' : 'ifdian');
                })
            }.padding(18).width('100%')
          }.backgroundColor($r('app.color.surface')).borderRadius(20)
          Text($r('app.string.privacy')).fontSize(14).fontColor($r('app.color.secondary')).width('100%')
          Text($r('app.string.privacy_hint')).fontSize(15).lineHeight(24).fontColor($r('app.color.secondary')).padding(20).width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          Text($r('app.string.about')).fontSize(14).fontColor($r('app.color.secondary')).width('100%')
          Column({ space: 12 }) {
            Image($r('app.media.afd_icon')).width(56).height(56).borderRadius(16)
            Text($r('app.string.app_name')).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
            Text($r('app.string.version')).fontSize(13).fontColor($r('app.color.secondary'))
            Text($r('app.string.about_description')).fontSize(14).lineHeight(23).fontColor($r('app.color.secondary')).textAlign(TextAlign.Center)
          }.padding(24).width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          if (this.loggedIn) { Button($r('app.string.logout')).fontColor($r('app.color.danger')).backgroundColor($r('app.color.surface')).width('100%').height(52).onClick((): void => this.logout()) }
        }.width('100%').constraintSize({ maxWidth: 760 }).padding({ left: 20, right: 20, top: this.topInset + 76, bottom: this.bottomInset + 24 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material), content: { title: { mainTitle: $r('app.string.settings') } } }).titleMode(HdsNavDestinationTitleMode.MINI)
      .backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
