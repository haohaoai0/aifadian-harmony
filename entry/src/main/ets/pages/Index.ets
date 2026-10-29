import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationTitleBarOptions, HdsTabs, HdsTabsController, hdsMaterial, BottomBuilderShowType, DividerShowType } from '@kit.UIDesignKit';
import { Category, RouteParam } from '../models/Models';
import { afdianApi } from '../services/AfdianApi';
import { trustedSite } from '../common/UrlPolicy';
import { afdianPreferredOrigin } from '../common/UrlPolicy';
import { appStore } from '../services/AppStore';
import { FeedPage } from './Feed';
import { ExplorePage } from './Explore';
import { MessagesPage, ProfilePage, SettingsDestination } from './AccountPages';
import { CreatorDestination, PostDestination } from './Details';
import { LoginDestination } from './Login';
import { WebDestination } from './WebPage';
import { Platform } from '../utils/Platform';
import { deviceInfo } from '@kit.BasicServicesKit';
import { rootScrollers } from '../utils/RootScrollers';
import { navigationStyle } from '../utils/NavigationStyle';
import { RootTitleControls } from '../components/RootHeader';
import { MessageDestination } from './MessageThread';
import { IncomeDestination } from './Income';
import { SponsoringDestination } from './Sponsoring';
import { AccountManagementDestination } from './AccountManagement';
import { FavoritesDestination } from './Favorites';
import { PublishDestination } from './Publish';
import { FloatingComposeButton } from '../components/FloatingComposeButton';
import { ImageViewerDestination } from './ImageViewer';
import { ForgotPasswordDestination, RegisterDestination } from './AuthRecovery';
import { CreatorSettingsDestination } from './CreatorSettings';
import { FaqSettingsDestination } from './FaqSettings';
import { messageApi } from '../services/MessageApi';
import { MyCheckData } from '../models/MessageModels';

@Entry
@Component
struct Index {
  @Provide('pageStack') stack: NavPathStack = new NavPathStack();
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.dark') dark: boolean = false;
  @StorageProp('afd.bottomInset') bottomInset: number = 0;
  @StorageProp('afd.loggedIn') @Watch('sessionChanged') loggedIn: boolean = false;
  @StorageProp('afd.foreground') @Watch('foregroundChanged') foreground: boolean = true;
  @StorageProp('afd.unreadPrivate') unreadPrivate: number = 0;
  @StorageProp('afd.unreadTotal') unreadTotal: number = 0;
  @StorageProp('afd.pendingUrl') @Watch('handleLink') pendingUrl: string = '';
  @State tab: number = 0;
  @State rootVisible: boolean = true;
  @State following: boolean = false;
  @State creatorType: string = 'rec';
  @State category: string = '';
  @State keyword: string = '';
  @State categories: Category[] = [];
  private controller: HdsTabsController = new HdsTabsController();
  private unreadTimer: number = -1;
  private unreadGeneration: number = 0;
  private titleBuilder: CustomBuilder = (): void => { this.TitleControls(); };
  private filterBuilder: CustomBuilder = (): void => { this.ExploreFilters(); };
  aboutToAppear(): void { this.handleLink(); this.loadCategories(); this.refreshUnread(); }
  aboutToDisappear(): void {
    this.unreadGeneration++;
    if (this.unreadTimer >= 0) { clearTimeout(this.unreadTimer); this.unreadTimer = -1; }
  }
  private sessionChanged(): void { this.refreshUnread(); }
  private foregroundChanged(): void {
    if (this.unreadTimer >= 0) { clearTimeout(this.unreadTimer); this.unreadTimer = -1; }
    if (this.foreground) { this.refreshUnread(); }
  }
  private scheduleUnread(): void {
    if (!this.loggedIn || !this.foreground) { return; }
    if (this.unreadTimer >= 0) { clearTimeout(this.unreadTimer); }
    this.unreadTimer = setTimeout((): void => {
      this.unreadTimer = -1;
      this.refreshUnread();
    }, 30000);
  }
  private async refreshUnread(): Promise<void> {
    const generation: number = ++this.unreadGeneration;
    if (!this.loggedIn) {
      AppStorage.setOrCreate<number>('afd.unreadPrivate', 0);
      AppStorage.setOrCreate<number>('afd.unreadTotal', 0);
      return;
    }
    try {
      const data: MyCheckData = await messageApi.check();
      if (generation !== this.unreadGeneration) { return; }
      const privateCount: number = data.unread_private_msg || data.unread_count?.message || 0;
      const commentCount: number = data.unread_comment || data.unread_count?.comment || 0;
      const likeCount: number = data.unread_like || data.unread_count?.like || 0;
      AppStorage.setOrCreate<number>('afd.unreadPrivate', privateCount);
      AppStorage.setOrCreate<number>('afd.unreadTotal', privateCount + commentCount + likeCount);
    } catch (error) {
    } finally {
      if (generation === this.unreadGeneration) { this.scheduleUnread(); }
    }
  }
  private async loadCategories(): Promise<void> {
    try { this.categories = (await afdianApi.categories()).list ?? []; } catch (error) {}
  }
  private dimension(resource: Resource): number {
    const value: number = this.getUIContext().getHostContext()?.resourceManager.getNumber(resource.id) ?? 0;
    return this.getUIContext().px2vp(value);
  }
  private floatingTabs(): boolean { return deviceInfo.apiAvailable('6.1.0(23)') && Platform.materialAvailable() && this.material; }
  private floatingBottomMargin(): number { return Math.max(0, this.bottomInset) + this.dimension($r('app.float.floating_tab_bottom_gap')); }
  private classicBarHeight(): number { return this.dimension($r('app.float.root_tab_bar_height')) + Math.max(0, this.bottomInset); }
  private contentBottomInset(): number {
    // Same geometry as HarmonyX: floating margin + 96vp, or the complete classic bar.
    return this.floatingTabs() ? this.floatingBottomMargin() + this.dimension($r('app.float.floating_tab_content_clearance')) : this.classicBarHeight();
  }
  private exploreHeaderHeight(): number { return this.dimension($r('app.float.explore_filter_height')); }
  private titleOptions(): HdsNavigationTitleBarOptions {
    const options: HdsNavigationTitleBarOptions = {
      avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { stackBuilder: this.titleBuilder,
        bottomBuilder: { builder: this.filterBuilder, height: this.tab === 1 ? this.exploreHeaderHeight() : 0,
          showType: BottomBuilderShowType.DIRECTLY_SHOW }, divider: { showType: DividerShowType.OFF } }
    };
    if (deviceInfo.apiAvailable('26.0.0') && options.content !== undefined) {
      options.content.stackBuilderContent = { builder: this.titleBuilder, updated: false };
      if (options.content.bottomBuilder !== undefined) {
        options.content.bottomBuilder.builderContent = { builder: this.filterBuilder, updated: false };
      }
    }
    return options;
  }
  @Builder private TitleControls() {
    RootTitleControls({ tab: $tab, following: $following, keyword: $keyword,
      creatorType: $creatorType, category: $category, categories: $categories,
      onCompose: (): void => this.stack.pushPath({ name: 'Web', param: new RouteParam(
        afdianPreferredOrigin(appStore.getRoute()) + '/compose', '') }) })
  }
  @Builder private ExploreFilters() {
    // HarmonyX draws controls from the upper slot, which stays above the
    // immersive material. The lower slot only reserves the matching height.
    Stack().width('100%').height('100%').hitTestBehavior(HitTestMode.None)
  }
  private bindScrollers(): void {
    if (deviceInfo.apiAvailable('6.1.0(23)')) {
      const scrollers: Scroller[] = rootScrollers.all();
      for (let i: number = 0; i < scrollers.length; i++) { this.controller.bindScroller(i, scrollers[i]); }
    }
  }
  handleLink(): void {
    if (trustedSite(this.pendingUrl)) {
      this.stack.pushPath({ name: 'Web', param: new RouteParam(this.pendingUrl, '') });
      AppStorage.setOrCreate<string>('afd.pendingUrl', '');
    }
  }
  @Builder private Destination(name: string, param: Object) {
    if (name === 'Post') { PostDestination({ postId: (param as RouteParam).postId }) }
    else if (name === 'Creator') { CreatorDestination({ userId: (param as RouteParam).userId }) }
    else if (name === 'Login') { LoginDestination() }
    else if (name === 'Register') { RegisterDestination() }
    else if (name === 'ForgotPassword') { ForgotPasswordDestination() }
    else if (name === 'CreatorSettings') { CreatorSettingsDestination() }
    else if (name === 'FaqSettings') { FaqSettingsDestination() }
    else if (name === 'Settings') { SettingsDestination() }
    else if (name === 'Message') { MessageDestination({ userId: (param as RouteParam).userId, userName: (param as RouteParam).title, avatar: (param as RouteParam).avatar }) }
    else if (name === 'Income') { IncomeDestination() }
    else if (name === 'Sponsoring') { SponsoringDestination() }
    else if (name === 'AccountManagement') { AccountManagementDestination() }
    else if (name === 'Favorites') { FavoritesDestination() }
    else if (name === 'Publish') { PublishDestination() }
    else if (name === 'ImageViewer') { ImageViewerDestination({ param: param as RouteParam }) }
    else if (name === 'Web') { WebDestination({ param: param as RouteParam }) }
  }
  @Builder private TabIcon(label: Resource, icon: Resource, index: number) {
    Column({ space: 4 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        SymbolGlyph(icon).fontSize(23).fontColor([this.tab === index ? $r('app.color.accent') : $r('app.color.secondary')])
        if (index === 2 && this.unreadTotal > 0) {
          Text(this.unreadTotal > 99 ? '99+' : this.unreadTotal.toString())
            .fontSize(9).fontColor(Color.White).padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .borderRadius(10).backgroundColor($r('app.color.accent')).offset({ x: 8, y: -5 })
        }
      }
      Text(label).fontSize(11).fontColor(this.tab === index ? $r('app.color.accent') : $r('app.color.secondary'))
    }.height($r('app.float.touch_target')).width('100%').justifyContent(FlexAlign.Center).accessibilityText(label)
  }
  @Builder private TabContents() {
    TabContent() { FeedPage({ following: this.following, endOffset: this.contentBottomInset() }) }.tabBar(this.TabIcon($r('app.string.home'), $r('sys.symbol.house'), 0))
    TabContent() { ExplorePage({ type: this.creatorType, category: this.category, keyword: this.keyword, headerHeight: this.exploreHeaderHeight(), endOffset: this.contentBottomInset() }) }.tabBar(this.TabIcon($r('app.string.explore'), $r('sys.symbol.compass'), 1))
    TabContent() { MessagesPage({ endOffset: this.contentBottomInset(), active: this.tab === 2 && this.rootVisible }) }.tabBar(this.TabIcon($r('app.string.messages'), $r('sys.symbol.message'), 2))
    TabContent() { ProfilePage({ endOffset: this.contentBottomInset() }) }.tabBar(this.TabIcon($r('app.string.profile'), $r('sys.symbol.person'), 3))
  }
  private openPublish(): void {
    if (!this.loggedIn) {
      this.stack.pushPath({ name: 'Login' });
      return;
    }
    this.stack.pushPath({ name: 'Publish' });
  }
  @Builder private RootTabs() {
    if (deviceInfo.apiAvailable('6.1.0(23)') && Platform.materialAvailable() && this.material) {
      HdsTabs({ controller: this.controller, index: this.tab }) {
        this.TabContents()
      }.width('100%').height('100%').barPosition(BarPosition.End).barOverlap(true).vertical(false)
        .barHeight($r('app.float.root_tab_bar_height')).barBackgroundColor(Color.Transparent).clip(false)
        .barFloatingStyle({ barBottomMargin: this.floatingBottomMargin(),
          systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE } })
        .onAppear((): void => this.bindScrollers())
        .onChange((value: number): void => { this.tab = value; })
    } else {
      Tabs({ barPosition: BarPosition.End, index: this.tab, controller: this.controller }) { this.TabContents() }
        .width('100%').height('100%').barOverlap(true).barHeight(this.classicBarHeight()).barBackgroundColor($r('app.color.surface'))
        .onChange((value: number): void => { this.tab = value; })
    }
  }
  build() {
    HdsNavigation(this.stack) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.RootTabs()
        if (this.tab !== 3 && this.rootVisible) {
          FloatingComposeButton({ onCompose: (): void => this.openPublish() })
        }
      }.width('100%').height('100%').clip(false)
    }
      .titleBar(this.titleOptions())
      .titleMode(HdsNavigationTitleMode.MINI).hideBackButton(true).mode(NavigationMode.Stack)
      .navDestination(this.Destination).backgroundColor($r('app.color.canvas')).width('100%').height('100%')
      .systemBarStyle(this.barStyle(), this.barStyle())
      .bindToScrollable(rootScrollers.all())
      .onNavBarStateChange((visible: boolean): void => { this.rootVisible = visible; })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
  private barStyle(): SystemBarStyle {
    const color: number = this.getUIContext().getHostContext()?.resourceManager.getColorSync($r('app.color.text').id) ?? (this.dark ? 0xFFF3F1F8 : 0xFF20202A);
    return { statusBarContentColor: '#' + color.toString(16).padStart(8, '0').substring(2) };
  }
}
