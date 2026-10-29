// The page and its HDS chrome must observe the same native Scroller instances.
export class RootScrollers {
  feed: Scroller = new Scroller();
  explore: Scroller = new Scroller();
  messages: Scroller = new Scroller();
  profile: Scroller = new Scroller();
  all(): Scroller[] { return [this.feed, this.explore, this.messages, this.profile]; }
}
export const rootScrollers: RootScrollers = new RootScrollers();
