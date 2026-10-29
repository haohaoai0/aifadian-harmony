import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { Avatar, PostCard, StateView } from '../components/Common';
import { Post, RouteParam, User } from '../models/Models';
import { FavoriteCrowdfunding } from '../models/FavoriteModels';
import { favoriteApi, FavoritePostPage } from '../services/FavoriteApi';
import { navigationStyle } from '../utils/NavigationStyle';
import { afdianPreferredOrigin } from '../common/UrlPolicy';
import { appStore } from '../services/AppStore';

@Component
export struct FavoritesDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @StorageProp('afd.sessionRevision') @Watch('reload') revision: number = 0;
  @State selectedTab: number = 0;
  @State creators: User[] = [];
  @State posts: Post[] = [];
  @State projects: FavoriteCrowdfunding[] = [];
  @State creatorsLoading: boolean = true;
  @State postsLoading: boolean = true;
  @State creatorsFailed: boolean = false;
  @State postsFailed: boolean = false;
  @State projectsLoading: boolean = true;
  @State projectsFailed: boolean = false;
  @State postsError: string = '';
  @State loadingMore: boolean = false;
  @State hasMore: boolean = false;
  @State removing: string = '';
  private creatorGeneration: number = 0;
  private postGeneration: number = 0;
  private projectGeneration: number = 0;
  private postPage: number = 1;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.loadAll(); }
  aboutToDisappear(): void { this.creatorGeneration++; this.postGeneration++; this.projectGeneration++; }

  reload(): void {
    this.creators = [];
    this.posts = [];
    this.projects = [];
    this.postPage = 1;
    this.loadAll();
  }

  private loadAll(): void {
    if (!this.loggedIn) {
      this.creatorsLoading = false;
      this.postsLoading = false;
      this.projectsLoading = false;
      return;
    }
    this.loadCreators();
    this.loadPosts(true);
    this.loadProjects();
  }
  private async loadProjects(): Promise<void> {
    const generation: number = ++this.projectGeneration;
    this.projectsLoading = true;
    this.projectsFailed = false;
    try {
      const projects: FavoriteCrowdfunding[] = await favoriteApi.crowdfundings();
      if (generation === this.projectGeneration) { this.projects = projects; }
    } catch (error) {
      if (generation === this.projectGeneration) { this.projectsFailed = true; }
    } finally {
      if (generation === this.projectGeneration) { this.projectsLoading = false; }
    }
  }

  private async loadCreators(): Promise<void> {
    const generation: number = ++this.creatorGeneration;
    this.creatorsLoading = true; this.creatorsFailed = false;
    try {
      const data: User[] = await favoriteApi.creators();
      if (generation === this.creatorGeneration) {
        this.creators = data.filter((item: User): boolean => item.user_id.length > 0);
      }
    } catch (error) {
      if (generation === this.creatorGeneration) { this.creatorsFailed = true; }
    } finally {
      if (generation === this.creatorGeneration) { this.creatorsLoading = false; }
    }
  }

  private async loadPosts(reset: boolean): Promise<void> {
    if (!reset && (this.loadingMore || !this.hasMore)) { return; }
    const generation: number = reset ? ++this.postGeneration : this.postGeneration;
    if (reset) { this.postPage = 1; this.postsLoading = this.posts.length === 0; }
    else { this.loadingMore = true; }
    this.postsFailed = false;
    this.postsError = '';
    try {
      const page: FavoritePostPage = await favoriteApi.posts(this.postPage);
      if (generation !== this.postGeneration) { return; }
      const incoming: Post[] = page.list.filter((item: Post): boolean => item.post_id.length > 0);
      this.posts = reset ? incoming : this.posts.concat(incoming.filter((item: Post): boolean =>
        !this.posts.some((old: Post): boolean => old.post_id === item.post_id)));
      this.hasMore = page.hasMore; this.postPage++;
    } catch (error) {
      if (generation === this.postGeneration) {
        this.postsFailed = true;
        this.postsError = (error as Error).message;
      }
    } finally {
      if (generation === this.postGeneration) { this.postsLoading = false; this.loadingMore = false; }
    }
  }

  private openCreator(user: User): void {
    const param: RouteParam = new RouteParam();
    param.userId = user.user_id;
    this.stack.pushPath({ name: 'Creator', param: param });
  }

  private openPost(post: Post): void {
    const param: RouteParam = new RouteParam();
    param.postId = post.post_id;
    this.stack.pushPath({ name: 'Post', param: param });
  }

  private removeCreator(user: User): void {
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.favorites_remove_creator_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.favorites_remove'), color: $r('app.color.danger') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1 || this.removing.length > 0) { return; }
      this.removing = 'creator:' + user.user_id;
      try {
        await favoriteApi.unmarkCreator(user.user_id);
        this.creators = this.creators.filter((item: User): boolean => item.user_id !== user.user_id);
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.favorites_removed') });
      } catch (error) {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.network_error') });
      } finally {
        this.removing = '';
      }
    });
  }

  private removePost(post: Post): void {
    this.getUIContext().getPromptAction().showDialog({ title: $r('app.string.favorites_remove_post_confirm'), buttons: [
      { text: $r('app.string.cancel'), color: $r('app.color.secondary') },
      { text: $r('app.string.favorites_remove'), color: $r('app.color.danger') }
    ] }).then(async (result): Promise<void> => {
      if (result.index !== 1 || this.removing.length > 0) { return; }
      this.removing = 'post:' + post.post_id;
      try {
        await favoriteApi.unmarkPost(post.post_id);
        this.posts = this.posts.filter((item: Post): boolean => item.post_id !== post.post_id);
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.favorites_removed') });
      } catch (error) {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.network_error') });
      } finally {
        this.removing = '';
      }
    });
  }

  private selectTab(index: number): void {
    this.selectedTab = index;
    this.scroller.scrollEdge(Edge.Top);
    if (index === 0 && this.creators.length === 0 && !this.creatorsLoading) { this.loadCreators(); }
    if (index === 1 && this.posts.length === 0 && !this.postsLoading) { this.loadPosts(true); }
    if (index === 2 && this.projects.length === 0 && !this.projectsLoading) { this.loadProjects(); }
  }
  private openProject(project: FavoriteCrowdfunding): void {
    this.stack.pushPath({ name: 'Web', param: new RouteParam(afdianPreferredOrigin(appStore.getRoute()) +
      '/project/' + encodeURIComponent(project.crowdfunding_id), project.title || project.name) });
  }
  private projectProgress(project: FavoriteCrowdfunding): number {
    if (project.goal_list.length === 0) { return 0; }
    const percent: number = Number(project.goal_list[0].percent);
    return Number.isFinite(percent) ? Math.min(100, Math.max(0, percent)) : 0;
  }

  @Builder private TabButton(index: number, label: Resource) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        Text(label).fontSize(15).fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selectedTab === index ? $r('app.color.accent') : $r('app.color.secondary'))
        Row().height(3).width(26).borderRadius(2)
          .backgroundColor(this.selectedTab === index ? $r('app.color.accent') : Color.Transparent)
      }.height(48).justifyContent(FlexAlign.Center)
    }.layoutWeight(1).backgroundColor(Color.Transparent).onClick((): void => this.selectTab(index))
      .accessibilityText(label).accessibilitySelected(this.selectedTab === index)
  }

  @Builder private CreatorRow(user: User) {
    Column({ space: 12 }) {
      Row({ space: 14 }) {
        Avatar({ src: user.avatar, diameter: 54 })
        Column({ space: 5 }) {
          Text(user.name).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(user.creator?.doing || $r('app.string.favorites_creator'))
            .fontSize(13).fontColor($r('app.color.secondary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.secondary')])
      }.width('100%').onClick((): void => this.openCreator(user))
      Button(this.removing === 'creator:' + user.user_id ? $r('app.string.loading') : $r('app.string.favorites_remove'))
        .height(36).fontSize(13).fontColor($r('app.color.danger')).backgroundColor(Color.Transparent)
        .enabled(this.removing.length === 0).alignSelf(ItemAlign.End).onClick((): void => this.removeCreator(user))
    }.width('100%').padding(18).backgroundColor($r('app.color.surface')).borderRadius(18)
  }
  @Builder private ProjectRow(project: FavoriteCrowdfunding) {
    Column({ space: 12 }) {
      Row({ space: 14 }) {
        if (project.pic.length > 0) {
          Image(project.pic).width(92).height(72).objectFit(ImageFit.Cover).borderRadius(12)
        } else {
          Column().width(92).height(72).borderRadius(12).backgroundColor($r('app.color.accent_soft'))
        }
        Column({ space: 7 }) {
          Text(project.title || project.name || $r('app.string.favorites_crowdfunding'))
            .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text($r('app.string.favorites_crowdfunding_count', project.sponsor_count.toString()))
            .fontSize(12).fontColor($r('app.color.secondary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.secondary')])
      }.width('100%')
      Progress({ value: this.projectProgress(project), total: 100, type: ProgressType.Linear })
        .width('100%').height(6).color($r('app.color.accent')).backgroundColor($r('app.color.separator'))
      if (project.goal_list.length > 0) {
        Row() {
          Text($r('app.string.favorites_crowdfunding_income', project.goal_list[0].sum_income))
            .fontSize(12).fontColor($r('app.color.accent')).layoutWeight(1)
          Text($r('app.string.favorites_crowdfunding_goal', project.goal_list[0].amount))
            .fontSize(12).fontColor($r('app.color.secondary'))
        }.width('100%')
      }
    }.width('100%').padding(16).backgroundColor($r('app.color.surface')).borderRadius(18)
      .onClick((): void => this.openProject(project))
  }

  build() {
    HdsNavDestination() {
      List({ space: 12, scroller: this.scroller }) {
        ListItem() {
          Row() {
            this.TabButton(0, $r('app.string.favorites_creators'))
            this.TabButton(1, $r('app.string.favorites_content'))
            this.TabButton(2, $r('app.string.favorites_crowdfunding'))
          }.width('100%').padding({ left: 16, right: 16 }).backgroundColor($r('app.color.canvas'))
        }
        if (!this.loggedIn) {
          ListItem() { StateView({ title: $r('app.string.favorites_login') }) }
        } else if (this.selectedTab === 0) {
          if (this.creatorsLoading || this.creatorsFailed) {
            ListItem() { StateView({ loading: this.creatorsLoading, error: this.creatorsFailed,
              onAction: (): void => { this.loadCreators(); } }) }
          } else if (this.creators.length === 0) {
            ListItem() { StateView({ title: $r('app.string.favorites_no_creators') }) }
          } else {
            ForEach(this.creators, (user: User) => {
              ListItem() { this.CreatorRow(user) }.padding({ left: 16, right: 16 })
            }, (user: User): string => user.user_id)
          }
        } else if (this.selectedTab === 1) {
          if (this.postsLoading || this.postsFailed) {
            ListItem() {
              Column({ space: 10 }) {
                StateView({ loading: this.postsLoading, error: this.postsFailed,
                  onAction: (): void => { this.loadPosts(true); } })
                if (this.postsError.length > 0) {
                  Text(this.postsError).fontSize(12).fontColor($r('app.color.secondary'))
                    .textAlign(TextAlign.Center).width('100%')
                }
              }.width('100%')
            }
          } else if (this.posts.length === 0) {
            ListItem() { StateView({ title: $r('app.string.favorites_no_content') }) }
          } else {
            ForEach(this.posts, (post: Post) => {
              ListItem() {
                Column({ space: 8 }) {
                  PostCard({ post: post, onOpen: (value: Post): void => this.openPost(value),
                    onUser: (id: string): void => {
                      const param: RouteParam = new RouteParam(); param.userId = id;
                      this.stack.pushPath({ name: 'Creator', param: param });
                    } })
                  Button(this.removing === 'post:' + post.post_id ? $r('app.string.loading') : $r('app.string.favorites_remove'))
                    .height(36).fontSize(13).fontColor($r('app.color.danger')).backgroundColor(Color.Transparent)
                    .enabled(this.removing.length === 0).onClick((): void => this.removePost(post))
                }.width('100%')
              }.padding({ left: 16, right: 16 })
            }, (post: Post): string => post.post_id)
            if (this.hasMore) {
              ListItem() {
                Button(this.loadingMore ? $r('app.string.loading') : $r('app.string.load_more'))
                  .backgroundColor(Color.Transparent).fontColor($r('app.color.accent'))
                  .enabled(!this.loadingMore).onClick((): void => { this.loadPosts(false); })
              }
            }
          }
        } else {
          if (this.projectsLoading || this.projectsFailed) {
            ListItem() {
              StateView({ loading: this.projectsLoading, error: this.projectsFailed,
                onAction: (): void => { this.loadProjects(); } })
            }
          } else if (this.projects.length === 0) {
            ListItem() { StateView({ title: $r('app.string.favorites_no_crowdfunding') }) }
          } else {
            ForEach(this.projects, (project: FavoriteCrowdfunding) => {
              ListItem() { this.ProjectRow(project) }.padding({ left: 16, right: 16 })
            }, (project: FavoriteCrowdfunding): string => project.crowdfunding_id)
          }
        }
      }.width('100%').height('100%').contentStartOffset(this.topInset + 64)
        .contentEndOffset(this.bottomInset + 24).scrollBar(BarState.Off).backgroundColor($r('app.color.canvas'))
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: $r('app.string.favorites_title') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
