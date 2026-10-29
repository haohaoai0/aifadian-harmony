import { afdianApi } from '../services/AfdianApi';
import { appStore } from '../services/AppStore';
import { Post, RouteParam } from '../models/Models';
import { PostCard, StateView } from '../components/Common';
import { Platform } from '../utils/Platform';
import { rootScrollers } from '../utils/RootScrollers';

@Component
export struct FeedPage {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.width') widthVp: number = 400;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.sessionRevision') @Watch('sessionChanged') revision: number = 0;
  @StorageProp('afd.feedRevision') @Watch('feedChanged') feedRevision: number = 0;
  @State posts: Post[] = [];
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State refreshing: boolean = false;
  @Prop @Watch('filterChanged') following: boolean = false;
  @Prop endOffset: number = 104;
  @State hasMore: boolean = true;
  private generation: number = 0;
  private busy: boolean = false;
  aboutToAppear(): void { this.load(true); }
  aboutToDisappear(): void { this.generation++; }
  sessionChanged(): void { this.load(true); }
  feedChanged(): void { this.posts = []; this.hasMore = true; this.load(true); rootScrollers.feed.scrollTo({ xOffset: 0, yOffset: 0 }); }
  filterChanged(): void { this.posts = []; this.hasMore = true; this.load(true); rootScrollers.feed.scrollTo({ xOffset: 0, yOffset: 0 }); }
  private async load(reset: boolean): Promise<void> {
    if (this.busy && !reset) { return; }
    const generation: number = reset ? ++this.generation : this.generation;
    this.busy = true; this.failed = false;
    if (reset && this.posts.length === 0) { this.loading = true; }
    try {
      if (this.following && !appStore.isLoggedIn()) { this.posts = []; this.hasMore = false; return; }
      const cursor: string = reset || this.posts.length === 0 ? '' : this.posts[this.posts.length - 1].publish_sn;
      const data = await afdianApi.feed(cursor, this.following);
      if (generation !== this.generation) { return; }
      const incoming: Post[] = data.list ?? [];
      this.posts = reset ? incoming : this.posts.concat(incoming.filter((item: Post): boolean => !this.posts.some((old: Post): boolean => old.post_id === item.post_id)));
      this.hasMore = data.has_more === 1 && incoming.length > 0;
    } catch (error) { if (generation === this.generation) { this.failed = true; } }
    finally { if (generation === this.generation) { this.loading = false; this.refreshing = false; this.busy = false; } }
  }
  private openPost(post: Post): void { const param: RouteParam = new RouteParam(); param.postId = post.post_id; this.stack.pushPath({ name: 'Post', param: param }); }
  private openUser(id: string): void { const param: RouteParam = new RouteParam(); param.userId = id; this.stack.pushPath({ name: 'Creator', param: param }); }
  build() {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 12, scroller: rootScrollers.feed }) {
            if (this.following && !appStore.isLoggedIn()) {
              ListItem() { Column({ space: 16 }) {
                StateView({ title: $r('app.string.login_hint') })
                Button($r('app.string.login')).backgroundColor($r('app.color.accent')).onClick((): void => this.stack.pushPath({ name: 'Login' }))
              }.width('100%') }
            } else {
            if (this.posts.length === 0) { ListItem() { StateView({ loading: this.loading, error: this.failed, onAction: (): void => { this.load(true); } }) } }
            ForEach(this.posts, (post: Post) => {
              ListItem() { PostCard({ post: post, onOpen: (value: Post): void => this.openPost(value), onUser: (id: string): void => this.openUser(id) }) }
            }, (post: Post): string => post.post_id)
            if (this.posts.length > 0 && this.hasMore) {
              ListItem() { Button(this.failed ? $r('app.string.retry') : $r('app.string.load_more')).fontColor($r('app.color.accent'))
                .backgroundColor(Color.Transparent).onClick((): void => { this.load(false); }) }
            }
            }
          }.width('100%').height('100%').lanes(Platform.columns(this.widthVp), 12)
            .padding({ left: 16, right: 16 }).contentStartOffset(this.topInset + 64).contentEndOffset(this.endOffset)
            .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
        }.onRefreshing((): void => { this.load(true); }).width('100%').height('100%').backgroundColor($r('app.color.canvas'))
  }
}
