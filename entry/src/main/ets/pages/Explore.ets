import { afdianApi } from '../services/AfdianApi';
import { CreatorPage, RouteParam, User } from '../models/Models';
import { CreatorCard, StateView } from '../components/Common';
import { rootScrollers } from '../utils/RootScrollers';

@Component
export struct ExplorePage {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.width') widthVp: number = 400;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @State users: User[] = [];
  @Prop @Watch('filterChanged') type: string = 'rec';
  @Prop @Watch('filterChanged') category: string = '';
  @Prop keyword: string = '';
  @Prop headerHeight: number = 96;
  @Prop endOffset: number = 104;
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State hasMore: boolean = true;
  @State refreshing: boolean = false;
  private page: number = 1;
  private generation: number = 0;
  private busy: boolean = false;
  aboutToAppear(): void { this.load(true); }
  aboutToDisappear(): void { this.generation++; }
  filterChanged(): void { this.users = []; this.hasMore = true; this.load(true); rootScrollers.explore.scrollTo({ xOffset: 0, yOffset: 0 }); }
  private async load(reset: boolean): Promise<void> {
    if (this.busy && !reset) { return; }
    const generation: number = reset ? ++this.generation : this.generation;
    this.busy = true; this.failed = false;
    if (reset) { this.page = 1; this.loading = this.users.length === 0; }
    try {
      const requestType: string = this.type === 'new' ? 'rec' : this.type;
      const data: CreatorPage = await afdianApi.creators(this.page, requestType, this.category);
      if (generation !== this.generation) { return; }
      let incoming: User[] = data.list ?? [];
      if (this.type === 'new') {
        incoming = incoming.sort((left: User, right: User): number =>
          (right.creator?.create_time ?? 0) - (left.creator?.create_time ?? 0));
      }
      this.users = reset ? incoming : this.users.concat(incoming.filter((user: User): boolean => !this.users.some((old: User): boolean => old.user_id === user.user_id)));
      this.hasMore = this.type !== 'new' && data.has_more === 1 && incoming.length > 0; this.page++;
    } catch (error) { if (generation === this.generation) { this.failed = true; } }
    finally { if (generation === this.generation) { this.loading = false; this.busy = false; this.refreshing = false; } }
  }
  private open(user: User): void { const param: RouteParam = new RouteParam(); param.userId = user.user_id; this.stack.pushPath({ name: 'Creator', param: param }); }
  private filtered(): User[] { const key: string = this.keyword.trim().toLowerCase(); return key.length === 0 ? this.users : this.users.filter((user: User): boolean => (user.name + (user.creator?.doing ?? '')).toLowerCase().includes(key)); }
  build() {
      Refresh({ refreshing: $$this.refreshing }) {
        List({ space: 12, scroller: rootScrollers.explore }) {
          if (this.users.length === 0) { ListItem() { StateView({ loading: this.loading, error: this.failed, onAction: (): void => { this.load(true); } }) } }
          ForEach(this.filtered(), (user: User) => { ListItem() { CreatorCard({ user: user, onOpen: (value: User): void => this.open(value) }) } }, (user: User): string => user.user_id)
          if (this.users.length > 0 && this.hasMore) { ListItem() { Button($r('app.string.load_more')).backgroundColor(Color.Transparent).fontColor($r('app.color.accent')).onClick((): void => { this.load(false); }) } }
          if (this.keyword.length > 0 && this.filtered().length === 0) { ListItem() { StateView() } }
        }.width('100%').height('100%').lanes(this.widthVp >= 840 ? 3 : 2, 12).padding({ left: 16, right: 16 })
          .contentStartOffset(this.topInset + 64 + this.headerHeight).contentEndOffset(this.endOffset).scrollBar(BarState.Off)
      }.width('100%').height('100%').onRefreshing((): void => { this.load(true); }).backgroundColor($r('app.color.canvas'))
  }
}
