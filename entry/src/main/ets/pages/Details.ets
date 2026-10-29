import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { afdianApi } from '../services/AfdianApi';
import { creatorApi } from '../services/CreatorApi';
import { appStore } from '../services/AppStore';
import { CreatorPlan, CreatorPlansPage, Post, PostPage, RouteParam, TopSponsorPage, User, UserProfile, plainText } from '../models/Models';
import { CreatorAlbum, CreatorGoal, CreatorProduct } from '../models/CreatorModels';
import { Avatar, PostCard, StateView } from '../components/Common';
import { AnchoredCover } from '../components/AnchoredCover';
import { MaterialSurfaceHost } from '../components/MaterialSurfaceHost';
import { PostImageGrid } from '../components/PostImageGrid';
import { navigationStyle } from '../utils/NavigationStyle';
import { ControlMaterial } from '../utils/ControlMaterial';
import { Platform } from '../utils/Platform';
import { afdianPreferredOrigin } from '../common/UrlPolicy';
import { commentApi } from '../services/CommentApi';
import { CommentPage, PostComment, mergeComments } from '../models/CommentModels';
import { formatDate } from '../utils/DisplayTime';
import { common } from '@kit.AbilityKit';
import { LinkShare } from '../services/LinkShare';

@Component
export struct CreatorDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.width') widthVp: number = 400;
  @StorageProp('afd.material') material: boolean = true;
  @Prop userId: string = '';
  @State user: User = new User();
  @State posts: Post[] = [];
  @State sponsors: User[] = [];
  @State plans: CreatorPlan[] = [];
  @State goals: CreatorGoal[] = [];
  @State albums: CreatorAlbum[] = [];
  @State products: CreatorProduct[] = [];
  @State albumPosts: Post[] = [];
  @State selectedAlbumId: string = '';
  @State albumLoading: boolean = false;
  @State albumFailed: boolean = false;
  @State sharing: boolean = false;
  @State selectedTab: number = 0;
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State hasMore: boolean = false;
  @State loadingMore: boolean = false;
  @State tabLoading: boolean = false;
  @State tabFailed: boolean = false;
  @State postFilter: number = 0;
  @State refreshing: boolean = false;
  @State headerPullOffset: number = 0;
  @State headerScrollOffset: number = 0;
  private generation: number = 0;
  private tabGeneration: number = 0;
  private sponsorsLoaded: boolean = false;
  private plansLoaded: boolean = false;
  private scroller: Scroller = new Scroller();
  private tabMaterials: ControlMaterial[] = [new ControlMaterial(), new ControlMaterial(),
    new ControlMaterial(), new ControlMaterial()];
  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.generation++; }
  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    this.loading = this.user.user_id.length === 0;
    this.refreshing = this.user.user_id.length > 0;
    this.failed = false;
    try {
      const profilePromise: Promise<UserProfile> = afdianApi.profile(this.userId);
      const postsPromise: Promise<PostPage> = afdianApi.posts(this.userId);
      const goalsPromise: Promise<CreatorGoal[]> = creatorApi.goals(this.userId)
        .catch((): CreatorGoal[] => []);
      const albumsPromise: Promise<CreatorAlbum[]> = creatorApi.albums(this.userId)
        .catch((): CreatorAlbum[] => []);
      const productsPromise: Promise<CreatorProduct[]> = creatorApi.products(this.userId)
        .catch((): CreatorProduct[] => []);
      const results: [UserProfile, PostPage, CreatorGoal[], CreatorAlbum[], CreatorProduct[]] =
        await Promise.all([profilePromise, postsPromise, goalsPromise, albumsPromise, productsPromise]);
      if (generation !== this.generation) { return; }
      this.user = results[0].user;
      this.posts = results[1].list ?? [];
      this.hasMore = results[1].has_more === 1;
      this.goals = results[2];
      this.albums = results[3];
      this.products = results[4];
      if (this.selectedAlbumId.length > 0 && !this.albums.some((album: CreatorAlbum): boolean =>
        album.album_id === this.selectedAlbumId)) {
        this.selectedAlbumId = '';
        this.albumPosts = [];
      }
    } catch (error) { if (generation === this.generation) { this.failed = true; } }
    finally { if (generation === this.generation) { this.loading = false; this.refreshing = false; } }
  }
  private async loadMore(): Promise<void> {
    if (this.loadingMore || this.posts.length === 0 || this.selectedAlbumId.length > 0) { return; }
    const generation: number = this.generation; this.loadingMore = true;
    try {
      const page = await afdianApi.posts(this.userId, this.posts[this.posts.length - 1].publish_sn);
      if (generation !== this.generation) { return; }
      this.posts = this.posts.concat((page.list ?? []).filter((item: Post): boolean => !this.posts.some((old: Post): boolean => old.post_id === item.post_id)));
      this.hasMore = page.has_more === 1;
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: $r('app.string.network_error') }); }
    finally { this.loadingMore = false; }
  }
  private selectTab(index: number): void {
    this.selectedTab = index;
    this.scroller.scrollEdge(Edge.Top);
    if (index === 2 && !this.sponsorsLoaded) { this.loadSponsors(); }
    if (index === 3 && !this.plansLoaded) { this.loadPlans(); }
  }
  private async loadSponsors(): Promise<void> {
    const generation: number = ++this.tabGeneration;
    this.tabLoading = true; this.tabFailed = false;
    try {
      const page: TopSponsorPage = await afdianApi.topSponsors(this.userId);
      if (generation !== this.tabGeneration) { return; }
      this.sponsors = page.list ?? []; this.sponsorsLoaded = true;
    } catch (error) {
      if (generation === this.tabGeneration) { this.tabFailed = true; }
    } finally {
      if (generation === this.tabGeneration) { this.tabLoading = false; }
    }
  }
  private async loadPlans(): Promise<void> {
    const generation: number = ++this.tabGeneration;
    this.tabLoading = true; this.tabFailed = false;
    try {
      const page: CreatorPlansPage = await afdianApi.creatorPlans(this.userId);
      if (generation !== this.tabGeneration) { return; }
      const subscriptions: CreatorPlan[] = page.list ?? [];
      const products: CreatorPlan[] = page.sale_list ?? [];
      this.plans = products.length > 0 ? products : subscriptions;
      this.plansLoaded = true;
    } catch (error) {
      if (generation === this.tabGeneration) { this.tabFailed = true; }
    } finally {
      if (generation === this.tabGeneration) { this.tabLoading = false; }
    }
  }
  private support(): void {
    const slug: string = this.user.url_slug.length > 0 ? this.user.url_slug : this.userId;
    this.stack.pushPath({ name: 'Web', param: new RouteParam(afdianPreferredOrigin(appStore.getRoute()) +
      '/a/' + encodeURIComponent(slug) + '/plan', this.user.name) });
  }
  private message(): void {
    const param: RouteParam = new RouteParam(); param.userId = this.userId; param.title = this.user.name; param.avatar = this.user.avatar;
    this.stack.pushPath({ name: 'Message', param: param });
  }
  private openPost(post: Post): void {
    const param: RouteParam = new RouteParam();
    param.postId = post.post_id;
    this.stack.pushPath({ name: 'Post', param: param });
  }
  private async selectAlbum(albumId: string): Promise<void> {
    if (this.albumLoading || this.selectedAlbumId === albumId) { return; }
    this.selectedAlbumId = albumId;
    this.albumPosts = [];
    this.albumFailed = false;
    this.postFilter = 0;
    if (albumId.length === 0) { return; }
    const generation: number = this.generation;
    this.albumLoading = true;
    try {
      const posts: Post[] = await creatorApi.albumPosts(albumId);
      if (generation !== this.generation || this.selectedAlbumId !== albumId) { return; }
      this.albumPosts = posts;
    } catch (error) {
      if (generation === this.generation && this.selectedAlbumId === albumId) { this.albumFailed = true; }
    } finally {
      if (generation === this.generation && this.selectedAlbumId === albumId) { this.albumLoading = false; }
    }
  }
  private visiblePosts(): Post[] {
    return this.selectedAlbumId.length > 0 ? this.albumPosts : this.posts;
  }
  private filteredPosts(): Post[] {
    if (this.postFilter === 1) {
      return this.visiblePosts().filter((post: Post): boolean => post.is_public === 1 || post.has_right === 1);
    }
    return this.visiblePosts();
  }
  private goalProgress(goal: CreatorGoal): number {
    const ratio: number = Number(goal.percent);
    if (Number.isFinite(ratio) && ratio >= 0) { return Math.min(100, ratio * 100); }
    const current: number = Number(this.goalCurrent(goal));
    const target: number = Number(this.goalTarget(goal));
    if (!Number.isFinite(current) || !Number.isFinite(target) || target <= 0) { return 0; }
    return Math.min(100, Math.max(0, current / target * 100));
  }
  private goalTitle(goal: CreatorGoal): string { return goal.desc || goal.title || goal.name; }
  private goalCurrent(goal: CreatorGoal): string {
    if (goal.type === 2) { return goal.sum_fans.toString(); }
    return goal.sum_income || goal.current_amount;
  }
  private goalTarget(goal: CreatorGoal): string {
    if (goal.type === 2) { return String(goal.monthly_fans); }
    return goal.monthly_income || goal.target_amount;
  }
  private albumTitle(album: CreatorAlbum): string { return album.title || album.name; }
  private text(resource: Resource): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? '';
  }
  private async shareCreator(): Promise<void> {
    if (this.sharing || this.user.user_id.length === 0) { return; }
    this.sharing = true;
    const slug: string = this.user.url_slug.length > 0 ? this.user.url_slug : this.userId;
    const link: string = afdianPreferredOrigin(appStore.getRoute()) + '/a/' + encodeURIComponent(slug);
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await LinkShare.show(context, link, this.user.name || this.text($r('app.string.creator')),
        this.text($r('app.string.share_description')));
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.share_failed') });
    } finally {
      this.sharing = false;
    }
  }
  private supportPlan(planId: string): void {
    if (planId.length === 0) { this.support(); return; }
    this.stack.pushPath({ name: 'Web', param: new RouteParam(afdianPreferredOrigin(appStore.getRoute()) +
      '/item/' + encodeURIComponent(planId), '') });
  }
  private planUnit(plan: CreatorPlan): Resource {
    return plan.product_type === 1 ? $r('app.string.explore_item_unit') : $r('app.string.explore_month_unit');
  }
  private coverHeight(): number { return this.widthVp >= 840 ? 230 : 170; }
  private stickyThreshold(): number { return this.coverHeight() + 52; }
  private stickyTabTint(index: number): ResourceColor {
    if (index === 1) { return $r('app.color.filter_blue'); }
    if (index === 2) { return $r('app.color.filter_pink'); }
    if (index === 3) { return $r('app.color.filter_green'); }
    return $r('app.color.filter_violet');
  }
  private updateHeaderScroll(): void {
    const offset: number = this.scroller.currentOffset().yOffset;
    if (Number.isFinite(offset)) { this.headerScrollOffset = offset; }
  }
  @Builder private ProfileTab(index: number, label: Resource) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        Text(label).fontSize(16).fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selectedTab === index ? $r('app.color.accent') : $r('app.color.secondary'))
        Row().height(3).width(30).borderRadius(2)
          .backgroundColor(this.selectedTab === index ? $r('app.color.accent') : Color.Transparent)
      }.height(52).justifyContent(FlexAlign.Center)
    }.layoutWeight(1).backgroundColor(Color.Transparent).onClick((): void => this.selectTab(index))
      .accessibilityText(label).accessibilitySelected(this.selectedTab === index)
  }
  @Builder private ProfileHeader() {
    Column() {
      Blank().height(this.coverHeight()).width('100%')
      Row({ space: 14 }) {
        Avatar({ src: this.user.avatar, diameter: 68 })
        Column({ space: 5 }) {
          Text(this.user.name).fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text() {
            Span($r('app.string.explore_creating')).fontColor($r('app.color.secondary'))
            Span(this.user.creator?.doing || $r('app.string.creator')).fontColor($r('app.color.text'))
          }.fontSize(14).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.user.creator?.category !== undefined) {
          Text(this.user.creator.category.name).fontSize(12).fontColor($r('app.color.accent'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(5).backgroundColor($r('app.color.accent_soft'))
        }
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 10 }).alignItems(VerticalAlign.Center)
        .margin({ top: -30 }).backgroundColor($r('app.color.surface'))
        .borderRadius({ topLeft: 22, topRight: 22 })
    }.width('100%')
  }
  @Builder private ProfileTabs() {
    Row() {
      this.ProfileTab(0, $r('app.string.profile_home_tab'))
      this.ProfileTab(1, $r('app.string.profile_posts_tab'))
      this.ProfileTab(2, $r('app.string.profile_sponsors_tab'))
      this.ProfileTab(3, $r('app.string.profile_shop_tab'))
    }.width('100%').padding({ left: 8, right: 8 }).backgroundColor($r('app.color.surface'))
  }
  @Builder private StickyTab(index: number, label: Resource) {
    Column() {
      if (this.material && Platform.materialAvailable()) {
        MaterialSurfaceHost({ surfaceHeight: 40, overflowMargin: 6,
          surfaceContent: (): void => { this.StickyTabSurface(index, label); } })
          .width('100%').height(40)
      } else {
        this.StickyTabSurface(index, label)
      }
    }.layoutWeight(1).height(40).borderRadius(20).clip(false)
  }
  @Builder private StickyTabSurface(index: number, label: Resource) {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height(40).borderRadius(20)
        .backgroundColor(this.stickyTabTint(index))
        .attributeModifier(this.tabMaterials[index].modifier(this.material && Platform.materialAvailable(), false,
          this.stickyTabTint(index)))
      Text(label).fontSize(14).fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedTab === index ? $r('app.color.accent') : $r('app.color.secondary'))
      Button({ type: ButtonType.Normal }).width('100%').height(40).backgroundColor(Color.Transparent)
        .onClick((): void => this.selectTab(index)).accessibilityText(label).accessibilitySelected(this.selectedTab === index)
    }.width('100%').height(40).borderRadius(20).clip(false)
  }
  @Builder private StickyTabs() {
    Row({ space: 8 }) {
      this.StickyTab(0, $r('app.string.profile_home_tab'))
      this.StickyTab(1, $r('app.string.profile_posts_tab'))
      this.StickyTab(2, $r('app.string.profile_sponsors_tab'))
      this.StickyTab(3, $r('app.string.profile_shop_tab'))
    }.width('100%').height(64).padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }
  @Builder private CoverBackground() {
    Stack() {
      if (this.user.cover.length > 0) {
        Image(this.user.cover).width('100%').height('100%').objectFit(ImageFit.Cover)
      } else {
        Column().width('100%').height('100%').backgroundColor($r('app.color.accent_soft'))
      }
    }.width('100%').height('100%')
  }
  @Builder private GoalCard(goal: CreatorGoal) {
    Column({ space: 9 }) {
      Text(this.goalTitle(goal) || $r('app.string.creator_goal')).fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text($r('app.string.creator_goal_amount', this.goalCurrent(goal) || '0', this.goalTarget(goal) || '--'))
        .fontSize(12).fontColor($r('app.color.secondary'))
      Progress({ value: this.goalProgress(goal), total: 100, type: ProgressType.Linear })
        .height(6).width('100%').color($r('app.color.accent')).backgroundColor($r('app.color.separator'))
    }.width(230).padding(14).alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.accent_soft')).borderRadius(16)
  }
  @Builder private HomeContent() {
    Column({ space: 18 }) {
      if (this.goals.length > 0) {
        Column({ space: 10 }) {
          Text($r('app.string.creator_goals')).fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.goals, (goal: CreatorGoal) => {
                this.GoalCard(goal)
              }, (goal: CreatorGoal, index: number): string => goal.goal_id || String(index))
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
      Text(this.user.creator?.detail || $r('app.string.profile_no_intro'))
        .fontSize(17).lineHeight(29).fontColor($r('app.color.text')).width('100%')
      Row({ space: 10 }) {
        Button($r('app.string.dm_private')).layoutWeight(1).height(44).backgroundColor($r('app.color.accent_soft'))
          .fontColor($r('app.color.accent')).onClick((): void => this.message())
        Button($r('app.string.profile_view_plans')).layoutWeight(1).height(44).backgroundColor($r('app.color.accent'))
          .onClick((): void => this.selectTab(3))
      }.width('100%')
    }.width('100%').padding(20)
  }
  @Builder private PostContent() {
    Column({ space: 12 }) {
      if (this.albums.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            Button($r('app.string.creator_albums_all')).height(34).borderRadius(17)
              .fontColor(this.selectedAlbumId.length === 0 ? $r('app.color.accent') : $r('app.color.secondary'))
              .backgroundColor(this.selectedAlbumId.length === 0 ? $r('app.color.accent_soft') : $r('app.color.surface'))
              .onClick((): void => { this.selectAlbum(''); })
            ForEach(this.albums, (album: CreatorAlbum) => {
              Button(this.albumTitle(album) || $r('app.string.creator_album')).height(34).borderRadius(17)
                .fontColor(this.selectedAlbumId === album.album_id ? $r('app.color.accent') : $r('app.color.secondary'))
                .backgroundColor(this.selectedAlbumId === album.album_id ? $r('app.color.accent_soft') : $r('app.color.surface'))
                .onClick((): void => { this.selectAlbum(album.album_id); })
            }, (album: CreatorAlbum): string => album.album_id)
          }
        }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      }
      Row({ space: 8 }) {
        Button($r('app.string.profile_all_filter')).height(34).fontColor(this.postFilter === 0 ? $r('app.color.accent') : $r('app.color.secondary'))
          .backgroundColor(this.postFilter === 0 ? $r('app.color.accent_soft') : $r('app.color.surface'))
          .borderRadius(17).onClick((): void => { this.postFilter = 0; })
        Button($r('app.string.profile_public_filter')).height(34).fontColor(this.postFilter === 1 ? $r('app.color.accent') : $r('app.color.secondary'))
          .backgroundColor(this.postFilter === 1 ? $r('app.color.accent_soft') : $r('app.color.surface'))
          .borderRadius(17).onClick((): void => { this.postFilter = 1; })
        Blank()
      }.width('100%')
      if (this.albumLoading || this.albumFailed) {
        StateView({ loading: this.albumLoading, error: this.albumFailed,
          onAction: (): void => { this.selectAlbum(this.selectedAlbumId); } })
      } else if (this.filteredPosts().length === 0) {
        StateView({ title: $r('app.string.profile_no_posts') })
      }
      if (!this.albumLoading && !this.albumFailed) {
        ForEach(this.filteredPosts(), (post: Post) => {
          PostCard({ post: post, onOpen: (value: Post): void => this.openPost(value),
            onUser: (id: string): void => {} })
        }, (post: Post): string => post.post_id)
      }
      if (this.hasMore && this.selectedAlbumId.length === 0) {
        Button(this.loadingMore ? $r('app.string.loading') : $r('app.string.load_more'))
          .backgroundColor(Color.Transparent).fontColor($r('app.color.accent'))
          .enabled(!this.loadingMore).onClick((): void => { this.loadMore(); })
      }
    }.width('100%').padding(16)
  }
  @Builder private SponsorContent() {
    if (this.tabLoading || this.tabFailed) {
      StateView({ loading: this.tabLoading, error: this.tabFailed, onAction: (): void => { this.loadSponsors(); } })
    } else {
      Column({ space: 12 }) {
        if (this.sponsors.length === 0) { StateView({ title: $r('app.string.profile_no_sponsors') }) }
        ForEach(this.sponsors, (sponsor: User, index: number) => {
          Row({ space: 12 }) {
            Text((index + 1).toString()).fontSize(13).fontColor($r('app.color.secondary')).width(24)
            Avatar({ src: sponsor.avatar, diameter: 42 })
            Text(sponsor.name).fontSize(16).fontColor($r('app.color.text')).layoutWeight(1)
          }.width('100%').padding(14).backgroundColor($r('app.color.surface')).borderRadius(14)
        }, (sponsor: User): string => sponsor.user_id)
      }.width('100%').padding(16)
    }
  }
  @Builder private PlanCard(plan: CreatorPlan) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 10 }) {
        if (plan.pic.length > 0) {
          Image(plan.pic).width('100%').height(118).objectFit(ImageFit.Cover).borderRadius(12)
        } else {
          Column().width('100%').height(118).backgroundColor($r('app.color.accent_soft')).borderRadius(12)
        }
        Text(plan.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').textAlign(TextAlign.Start)
        Row({ space: 4 }) {
          Text('¥' + (plan.show_price || plan.price || plan.floor_price)).fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text'))
          Text('/').fontSize(12).fontColor($r('app.color.secondary'))
          Text(this.planUnit(plan)).fontSize(12).fontColor($r('app.color.secondary'))
        }.width('100%')
      }.padding(12).width('100%').backgroundColor($r('app.color.surface')).borderRadius(16)
    }.width('100%').padding(0).backgroundColor(Color.Transparent).onClick((): void => this.support())
  }
  @Builder private ProductCard(product: CreatorProduct) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 10 }) {
        if (product.pic.length > 0) {
          Image(product.pic).width('100%').height(118).objectFit(ImageFit.Cover).borderRadius(12)
        } else {
          Column().width('100%').height(118).backgroundColor($r('app.color.accent_soft')).borderRadius(12)
        }
        Text(product.name || $r('app.string.creator_product')).fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%').textAlign(TextAlign.Start)
        Text('¥' + (product.show_price || product.floor_price || product.price)).fontSize(18)
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
      }.padding(12).width('100%').backgroundColor($r('app.color.surface')).borderRadius(16)
    }.width('100%').padding(0).backgroundColor(Color.Transparent)
      .onClick((): void => this.supportPlan(product.plan_id))
  }
  @Builder private ShopContent() {
    if (this.tabLoading || this.tabFailed) {
      StateView({ loading: this.tabLoading, error: this.tabFailed, onAction: (): void => { this.loadPlans(); } })
    } else if (this.products.length === 0 && this.plans.length === 0) {
      StateView({ title: $r('app.string.profile_no_plans') })
    } else {
      GridRow({ columns: 2, gutter: { x: 12, y: 12 } }) {
        if (this.products.length > 0) {
          ForEach(this.products, (product: CreatorProduct) => {
            GridCol() { this.ProductCard(product) }
          }, (product: CreatorProduct): string => product.plan_id)
        } else {
          ForEach(this.plans, (plan: CreatorPlan) => {
            GridCol() { this.PlanCard(plan) }
          }, (plan: CreatorPlan): string => plan.plan_id)
        }
      }.width('100%').padding(16)
    }
  }
  @Builder private BottomActions() {
    Row({ space: 10 }) {
      Button($r('app.string.dm_private')).height(46).layoutWeight(1).backgroundColor($r('app.color.surface'))
        .fontColor($r('app.color.text')).onClick((): void => this.message())
      Button($r('app.string.support_creator')).height(46).layoutWeight(2).backgroundColor($r('app.color.accent'))
        .onClick((): void => this.support())
    }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: this.bottomInset + 8 })
      .backgroundColor($r('app.color.surface')).border({ width: { top: 1 }, color: $r('app.color.separator') })
  }
  build() {
    HdsNavDestination() {
      if (this.loading || this.failed) { StateView({ loading: this.loading, error: this.failed, onAction: (): void => { this.load(); } }) }
      else {
        Stack({ alignContent: Alignment.TopStart }) {
          AnchoredCover({ coverHeight: this.coverHeight(), pullOffset: this.headerPullOffset,
            scrollOffset: Math.max(0, this.headerScrollOffset),
            coverBuilder: (): void => { this.CoverBackground(); } })
            .width('100%')
          Column() {
            Refresh({ refreshing: $$this.refreshing }) {
              List({ scroller: this.scroller }) {
                ListItem() { this.ProfileHeader() }
                ListItemGroup({ header: this.ProfileTabs }) {
                  if (this.selectedTab === 0) { ListItem() { this.HomeContent() } }
                  else if (this.selectedTab === 1) { ListItem() { this.PostContent() } }
                  else if (this.selectedTab === 2) { ListItem() { this.SponsorContent() } }
                  else { ListItem() { this.ShopContent() } }
                }
              }.width('100%').height('100%').contentEndOffset(8).scrollBar(BarState.Off)
                .onDidScroll((): void => this.updateHeaderScroll())
            }.layoutWeight(1).width('100%').onRefreshing((): void => { this.load(); })
              .onOffsetChange((offset: number): void => { this.headerPullOffset = offset; })
            this.BottomActions()
          }.width('100%').height('100%')
          if (this.headerScrollOffset >= this.stickyThreshold()) {
            Column() { this.StickyTabs() }.width('100%')
              .position({ x: 0, y: this.topInset + 64 }).zIndex(3)
          }
        }.width('100%').height('100%').clip(false)
      }
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: this.headerScrollOffset >= this.stickyThreshold() ? this.user.name : '',
        subTitle: this.headerScrollOffset >= this.stickyThreshold() ? (this.user.creator?.doing ?? '') : '' },
        menu: { maxCount: 1, value: [{
          content: {
            icon: $r('sys.symbol.share'),
            label: $r('app.string.share'),
            isEnabled: !this.loading && this.user.user_id.length > 0,
            action: (): void => { this.shareCreator(); }
          }
        }] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas'))
      .bindToScrollable([this.scroller])
  }
}

@Component
export struct PostDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @Prop postId: string = '';
  @StorageProp('afd.height') heightVp: number = 800;
  @State post: Post = new Post();
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State liking: boolean = false;
  @State liked: boolean = false;
  @State likeCount: number = 0;
  @State comments: PostComment[] = [];
  @State commentsLoading: boolean = false;
  @State commentsFailed: boolean = false;
  @State commentsHasMore: boolean = false;
  @State loadingMoreComments: boolean = false;
  @State commentDraft: string = '';
  @State publishingComment: boolean = false;
  @State replyCommentId: string = '';
  @State replyCommentName: string = '';
  @State likingComments: string[] = [];
  @State sharing: boolean = false;
  private generation: number = 0;
  private commentGeneration: number = 0;
  private commentCursor: string = '';
  private scroller: Scroller = new Scroller();
  private video: VideoController = new VideoController();
  aboutToAppear(): void { this.load(); this.loadComments(true); }
  aboutToDisappear(): void {
    this.generation++;
    this.commentGeneration++;
    try { this.video.stop(); } catch (error) {}
  }
  private async load(): Promise<void> {
    const generation: number = ++this.generation; this.loading = true; this.failed = false;
    try {
      const data = await afdianApi.detail(this.postId);
      if (generation !== this.generation) { return; }
      this.post = data.post; this.liked = this.post.has_like === 1; this.likeCount = this.post.like_count;
    } catch (error) { if (generation === this.generation) { this.failed = true; } }
    finally { if (generation === this.generation) { this.loading = false; } }
  }
  private openWeb(): void { this.stack.pushPath({ name: 'Web', param: new RouteParam(
    afdianPreferredOrigin(appStore.getRoute()) + '/p/' + encodeURIComponent(this.postId), this.post.title) }); }
  private async sharePost(): Promise<void> {
    if (this.sharing || this.postId.length === 0) { return; }
    this.sharing = true;
    const link: string = afdianPreferredOrigin(appStore.getRoute()) + '/p/' + encodeURIComponent(this.postId);
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await LinkShare.show(context, link, this.post.title || this.text($r('app.string.post_detail')),
        this.text($r('app.string.share_description')));
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.share_failed') });
    } finally {
      this.sharing = false;
    }
  }
  private openImage(url: string): void {
    this.stack.pushPath({ name: 'ImageViewer',
      param: new RouteParam(url, this.post.title || this.text($r('app.string.image_viewer'))) });
  }
  private text(resource: Resource): string {
    return this.getUIContext().getHostContext()?.resourceManager.getStringSync(resource.id) ?? '';
  }
  private mediaPreviewHeight(): number { return Math.min(420, Math.max(240, this.heightVp * 0.52)); }
  private async like(): Promise<void> {
    if (!appStore.isLoggedIn()) { this.stack.pushPath({ name: 'Login' }); return; }
    if (this.liking) { return; } this.liking = true;
    const generation: number = this.generation;
    try { await afdianApi.like(this.postId, this.liked); if (generation !== this.generation) { return; }
      this.liked = !this.liked; this.likeCount = Math.max(0, this.likeCount + (this.liked ? 1 : -1));
    } catch (error) { this.getUIContext().getPromptAction().showToast({ message: $r('app.string.report_error') }); }
    finally { this.liking = false; }
  }
  private async loadComments(reset: boolean): Promise<void> {
    if (!reset && (this.loadingMoreComments || !this.commentsHasMore)) { return; }
    const generation: number = reset ? ++this.commentGeneration : this.commentGeneration;
    if (reset) {
      this.commentCursor = '';
      this.commentsLoading = true;
    } else {
      this.loadingMoreComments = true;
    }
    this.commentsFailed = false;
    try {
      const page: CommentPage = await commentApi.list(this.postId, this.commentCursor);
      if (generation !== this.commentGeneration) { return; }
      this.comments = reset ? page.comments : mergeComments(this.comments, page.comments);
      this.commentCursor = page.nextCursor;
      this.commentsHasMore = page.hasMore;
    } catch (error) {
      if (generation === this.commentGeneration) { this.commentsFailed = true; }
    } finally {
      if (generation === this.commentGeneration) {
        this.commentsLoading = false;
        this.loadingMoreComments = false;
      }
    }
  }
  private beginReply(comment: PostComment): void {
    this.replyCommentId = comment.comment_id;
    this.replyCommentName = comment.user?.name ?? '';
  }
  private async publishComment(): Promise<void> {
    if (!appStore.isLoggedIn()) { this.stack.pushPath({ name: 'Login' }); return; }
    const content: string = this.commentDraft.trim();
    if (this.publishingComment || content.length === 0) { return; }
    const generation: number = this.commentGeneration;
    this.publishingComment = true;
    try {
      await commentApi.publish(this.postId, content, this.replyCommentId);
      if (generation !== this.commentGeneration) { return; }
      this.commentDraft = '';
      this.replyCommentId = '';
      this.replyCommentName = '';
      this.post.comment_count++;
      await this.loadComments(true);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.comments_publish_failed') });
    } finally {
      this.publishingComment = false;
    }
  }
  private async toggleCommentLike(comment: PostComment): Promise<void> {
    if (!appStore.isLoggedIn()) { this.stack.pushPath({ name: 'Login' }); return; }
    if (this.likingComments.includes(comment.comment_id)) { return; }
    const liked: boolean = comment.has_like === 1;
    this.likingComments = this.likingComments.concat([comment.comment_id]);
    try {
      await commentApi.like(comment.comment_id, liked);
      for (let i: number = 0; i < this.comments.length; i++) {
        if (this.comments[i].comment_id === comment.comment_id) {
          this.comments[i].has_like = liked ? 0 : 1;
          this.comments[i].like_count = Math.max(0, this.comments[i].like_count + (liked ? -1 : 1));
        }
        for (let j: number = 0; j < this.comments[i].sub_comments.length; j++) {
          if (this.comments[i].sub_comments[j].comment_id === comment.comment_id) {
            this.comments[i].sub_comments[j].has_like = liked ? 0 : 1;
            this.comments[i].sub_comments[j].like_count =
              Math.max(0, this.comments[i].sub_comments[j].like_count + (liked ? -1 : 1));
          }
        }
      }
      this.comments = this.comments.slice();
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.report_error') });
    } finally {
      this.likingComments = this.likingComments.filter((id: string): boolean => id !== comment.comment_id);
    }
  }
  private removeComment(comment: PostComment): void {
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.comments_delete_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.confirm'), color: $r('app.color.danger') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1) { return; }
      try {
        await commentApi.remove(comment.comment_id);
        this.comments = this.comments.filter((item: PostComment): boolean => item.comment_id !== comment.comment_id);
        this.post.comment_count = Math.max(0, this.post.comment_count - 1);
      } catch (error) {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.report_error') });
      }
    });
  }
  @Builder private CommentRow(comment: PostComment, nested: boolean = false) {
    Row({ space: 10 }) {
      Avatar({ src: comment.user?.avatar ?? '', diameter: nested ? 28 : 36 })
      Column({ space: 7 }) {
        Row({ space: 8 }) {
          Text(comment.user?.name || $r('app.string.anonymous')).fontSize(nested ? 13 : 14)
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
          if (comment.user?.user_id === this.post.user_id && this.post.user_id.length > 0) {
            Text($r('app.string.comments_author')).fontSize(10).fontColor($r('app.color.accent'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(8)
              .backgroundColor($r('app.color.accent_soft'))
          }
          if (comment.publish_time > 0) {
            Text(formatDate(comment.publish_time)).fontSize(11).fontColor($r('app.color.secondary'))
          }
        }.width('100%')
        Text(comment.content).fontSize(nested ? 14 : 15).lineHeight(nested ? 21 : 23)
          .fontColor($r('app.color.text')).copyOption(CopyOptions.LocalDevice).width('100%')
        Row({ space: 14 }) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.heart')).fontSize(13)
                .fontColor([comment.has_like === 1 ? $r('app.color.accent') : $r('app.color.secondary')])
              if (comment.like_count > 0) {
                Text(comment.like_count.toString()).fontSize(12).fontColor($r('app.color.secondary'))
              }
            }
          }.height(28).backgroundColor(Color.Transparent).enabled(!this.likingComments.includes(comment.comment_id))
            .onClick((): void => { this.toggleCommentLike(comment); })
          Button($r('app.string.comments_reply')).height(28).fontSize(12)
            .fontColor($r('app.color.secondary')).backgroundColor(Color.Transparent)
            .onClick((): void => this.beginReply(comment))
          if (comment.can_edit === 1) {
            Button($r('app.string.comments_delete')).height(28).fontSize(12)
              .fontColor($r('app.color.danger')).backgroundColor(Color.Transparent)
              .onClick((): void => this.removeComment(comment))
          }
          Blank()
        }.width('100%')
        if (!nested && comment.sub_comments.length > 0) {
          Column({ space: 10 }) {
            ForEach(comment.sub_comments, (reply: PostComment) => {
              this.CommentRow(reply, true)
            }, (reply: PostComment): string => reply.comment_id)
          }.width('100%').padding(10).backgroundColor($r('app.color.canvas')).borderRadius(12)
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(nested ? 4 : 12).backgroundColor(nested ? Color.Transparent : $r('app.color.surface'))
      .borderRadius(nested ? 0 : 14)
  }
  @Builder private CommentsSection() {
    Column({ space: 12 }) {
      Row() {
        Text($r('app.string.comments_count', this.post.comment_count.toString())).fontSize(18)
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text')).layoutWeight(1)
        if (this.commentsLoading) { LoadingProgress().width(22).height(22).color($r('app.color.accent')) }
      }.width('100%')
      if (this.commentsFailed && this.comments.length === 0) {
        Button($r('app.string.retry')).backgroundColor($r('app.color.surface'))
          .fontColor($r('app.color.accent')).onClick((): void => { this.loadComments(true); })
      } else if (!this.commentsLoading && this.comments.length === 0) {
        Text($r('app.string.comments_empty')).fontSize(14).fontColor($r('app.color.secondary'))
          .width('100%').padding(18)
      }
      ForEach(this.comments, (comment: PostComment) => {
        this.CommentRow(comment)
      }, (comment: PostComment): string => comment.comment_id)
      if (this.commentsHasMore) {
        Button(this.loadingMoreComments ? $r('app.string.loading') : $r('app.string.load_more'))
          .backgroundColor(Color.Transparent).fontColor($r('app.color.accent'))
          .enabled(!this.loadingMoreComments).onClick((): void => { this.loadComments(false); })
      }
      Column({ space: 8 }) {
        if (this.replyCommentName.length > 0) {
          Row({ space: 8 }) {
            Text($r('app.string.comments_replying', this.replyCommentName)).fontSize(12)
              .fontColor($r('app.color.accent')).layoutWeight(1)
            Button($r('app.string.cancel')).height(28).fontSize(12).backgroundColor(Color.Transparent)
              .fontColor($r('app.color.secondary')).onClick((): void => {
                this.replyCommentId = '';
                this.replyCommentName = '';
              })
          }.width('100%')
        }
        TextArea({ text: this.commentDraft, placeholder: $r('app.string.comments_placeholder') })
          .height(92).width('100%').backgroundColor($r('app.color.canvas')).borderRadius(14)
          .onChange((value: string): void => { this.commentDraft = value; })
        Button(this.publishingComment ? $r('app.string.comments_publishing') : $r('app.string.comments_publish'))
          .height(42).width('100%').backgroundColor($r('app.color.accent'))
          .enabled(!this.publishingComment && this.commentDraft.trim().length > 0)
          .onClick((): void => { this.publishComment(); })
      }.width('100%').padding(12).backgroundColor($r('app.color.surface')).borderRadius(14)
    }.width('100%')
  }
  build() {
    HdsNavDestination() {
      if (this.loading || this.failed) { StateView({ loading: this.loading, error: this.failed, onAction: (): void => { this.load(); } }) }
      else {
        Scroll(this.scroller) {
          Column({ space: 20 }) {
            Row({ space: 12 }) {
              Avatar({ src: this.post.user?.avatar ?? '' })
              Text(this.post.user?.name ?? '').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
            }.width('100%').onClick((): void => { const param: RouteParam = new RouteParam(); param.userId = this.post.user_id; this.stack.pushPath({ name: 'Creator', param: param }); })
            Text(this.post.title).fontSize(25).fontWeight(FontWeight.Bold).fontColor($r('app.color.text')).width('100%')
            if (this.post.cover.length > 0) {
              Image(this.post.cover).width('100%').height(this.mediaPreviewHeight())
                .objectFit(ImageFit.Cover).borderRadius(16).clip(true)
                .onClick((): void => this.openImage(this.post.cover))
            }
            if (this.post.has_right === 1) {
              Text(plainText(this.post.content)).fontSize(17).lineHeight(29).fontColor($r('app.color.text')).copyOption(CopyOptions.LocalDevice).width('100%')
              PostImageGrid({ images: this.post.pics ?? [],
                onOpen: (url: string): void => this.openImage(url) })
              if (this.post.video.length > 0) {
                Video({ src: this.post.video, controller: this.video }).width('100%').height(Math.min(260, this.heightVp * 0.5)).autoPlay(false).controls(true)
              }
              if (this.post.audio.length > 0) { Button($r('app.string.audio')).onClick((): void => this.openWeb()).backgroundColor($r('app.color.accent_soft')).fontColor($r('app.color.accent')) }
            } else { Text($r('app.string.locked')).fontColor($r('app.color.secondary')).padding(24) }
            Row({ space: 12 }) {
              Button(($r('app.string.like'))).backgroundColor(this.liked ? $r('app.color.accent') : $r('app.color.accent_soft'))
                .fontColor(this.liked ? Color.White : $r('app.color.accent')).onClick((): void => { this.like(); }).enabled(!this.liking)
              Text(this.likeCount.toString()).fontColor($r('app.color.secondary')).fontSize(14)
              Blank()
              Button($r('app.string.comments_count', this.post.comment_count.toString()))
                .onClick((): void => { this.loadComments(true); }).backgroundColor($r('app.color.surface')).fontColor($r('app.color.accent'))
            }.width('100%')
            this.CommentsSection()
            Button($r('app.string.read_full')).width('100%').height(48).backgroundColor($r('app.color.accent')).onClick((): void => this.openWeb())
          }.width('100%').constraintSize({ maxWidth: 900 })
            .padding({ left: 20, right: 20, top: this.topInset + 76, bottom: this.bottomInset + 24 }).alignItems(HorizontalAlign.Start)
        }.width('100%').height('100%').scrollBar(BarState.Off)
      }
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(),
      content: { title: { mainTitle: $r('app.string.post_detail') }, menu: { maxCount: 1, value: [{
        content: {
          icon: $r('sys.symbol.share'),
          label: $r('app.string.share'),
          isEnabled: !this.loading && this.postId.length > 0,
          action: (): void => { this.sharePost(); }
        }
      }] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
