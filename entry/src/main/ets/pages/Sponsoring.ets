import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { Avatar, StateView } from '../components/Common';
import { RouteParam, User } from '../models/Models';
import { SponsoringDetail, SponsoringItem, SponsoringResponse, SponsoringSale } from '../models/SponsoringModels';
import { sponsoringApi } from '../services/SponsoringApi';
import { navigationStyle } from '../utils/NavigationStyle';
import { formatDate } from '../utils/DisplayTime';

@Component
export struct SponsoringDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @StorageProp('afd.sessionRevision') @Watch('reload') revision: number = 0;
  @State active: SponsoringItem[] = [];
  @State expired: SponsoringItem[] = [];
  @State loading: boolean = true;
  @State failed: boolean = false;
  private generation: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void { this.load(); }
  aboutToDisappear(): void { this.generation++; }
  reload(): void { this.active = []; this.expired = []; this.load(); }

  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    this.failed = false;
    if (!this.loggedIn) { this.loading = false; return; }
    this.loading = this.active.length === 0 && this.expired.length === 0;
    try {
      const data: SponsoringResponse = await sponsoringApi.current();
      if (generation !== this.generation) { return; }
      this.active = data.sponsoring ?? [];
      this.expired = data.sponsoring_expired ?? [];
    } catch (error) {
      if (generation === this.generation) { this.failed = true; }
    } finally {
      if (generation === this.generation) { this.loading = false; }
    }
  }

  private details(item: SponsoringItem): SponsoringDetail[] {
    const list: SponsoringDetail[] = item.sponsor_info?.out_detail?.list ?? [];
    return list;
  }

  private initial(item: SponsoringItem): string {
    const name: string = item.user?.name ?? '';
    return name.length > 0 ? name.substring(0, 1) : '爱';
  }

  private period(value: string): Resource {
    if (value === '3') { return $r('app.string.sponsoring_quarter'); }
    if (value === '12') { return $r('app.string.sponsoring_year'); }
    return $r('app.string.sponsoring_month');
  }

  private price(detail: SponsoringDetail): string {
    const adjusted: string = detail.plan?.show_price_after_adjust ?? '';
    if (adjusted.length > 0) { return adjusted; }
    const regular: string = detail.plan?.show_price ?? '';
    return regular.length > 0 ? regular : (detail.show_amount ?? '');
  }

  private expiry(value: string): string {
    const numberValue: number = Number(value);
    if (Number.isFinite(numberValue) && numberValue > 0) {
      const seconds: number = numberValue > 100000000000 ? Math.floor(numberValue / 1000) : numberValue;
      return formatDate(seconds);
    }
    return value;
  }

  private openCreator(user: User): void {
    const param: RouteParam = new RouteParam();
    param.userId = user.user_id;
    this.stack.pushPath({ name: 'Creator', param: param });
  }

  private openMessage(user: User): void {
    const param: RouteParam = new RouteParam();
    param.userId = user.user_id;
    param.title = user.name;
    param.avatar = user.avatar;
    this.stack.pushPath({ name: 'Message', param: param });
  }

  @Builder private DetailRow(detail: SponsoringDetail) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text('¥' + this.price(detail)).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
        Text('/').fontSize(14).fontColor($r('app.color.secondary'))
        Text(this.period(detail.plan?.pay_month ?? '')).fontSize(14).fontColor($r('app.color.secondary'))
        Blank()
        if (detail.plan?.permanent) {
          Text($r('app.string.sponsoring_permanent')).fontSize(12).fontColor($r('app.color.accent'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8).backgroundColor($r('app.color.accent_soft'))
        }
      }.width('100%')
      Text(detail.plan?.name || $r('app.string.sponsoring_custom')).fontSize(15).fontColor($r('app.color.text')).width('100%')
      if ((detail.agreement?.next_execute_time ?? '').length > 0) {
        Text($r('app.string.sponsoring_next', detail.agreement?.next_execute_time ?? ''))
          .fontSize(12).fontColor($r('app.color.secondary')).width('100%')
      } else if (this.expiry(detail.expire_time).length > 0) {
        Text($r('app.string.sponsoring_expires', this.expiry(detail.expire_time)))
          .fontSize(12).fontColor($r('app.color.secondary')).width('100%')
      }
    }.width('100%').padding({ top: 12 }).border({ width: { top: 1 }, color: $r('app.color.separator') })
  }

  @Builder private SponsorCard(item: SponsoringItem, isExpired: boolean) {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Avatar({ src: item.user?.avatar ?? '', diameter: 48 })
        Column({ space: 5 }) {
          Text(item.user?.name || this.initial(item)).fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.user?.creator?.doing || $r('app.string.sponsoring_supporter'))
            .fontSize(13).fontColor($r('app.color.secondary')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(14).fontColor([$r('app.color.secondary')])
      }.width('100%').onClick((): void => this.openCreator(item.user))
      if (this.details(item).length > 0) {
        ForEach(this.details(item), (detail: SponsoringDetail, index: number) => {
          this.DetailRow(detail)
        }, (detail: SponsoringDetail, index: number): string => (detail.plan?.name ?? '') + ':' + index.toString())
      } else if ((item.sale_list ?? []).length > 0) {
        ForEach(item.sale_list, (sale: SponsoringSale, index: number) => {
          Column({ space: 6 }) {
            Row({ space: 8 }) {
              Text(sale.plan?.name || $r('app.string.sponsoring_custom')).fontSize(15).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text')).layoutWeight(1)
              Text(String(sale.sign_status) !== '0' ? $r('app.string.sponsoring_ticket_detail') : $r('app.string.sponsoring_detail'))
                .fontSize(12).fontColor($r('app.color.secondary'))
            }.width('100%')
            if ((sale.sku_processed ?? []).length > 0) {
              Text(sale.sku_processed.map((sku) => sku.name + ' × ' + sku.count).join('  '))
                .fontSize(12).fontColor($r('app.color.secondary')).width('100%')
            }
          }.width('100%').padding({ top: 12 }).border({ width: { top: 1 }, color: $r('app.color.separator') })
        }, (sale: SponsoringSale, index: number): string => sale.out_trade_no + ':' + index.toString())
      } else if (!isExpired) {
        Text($r('app.string.sponsoring_awaiting')).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
      }
      Row({ space: 10 }) {
        Button($r('app.string.sponsoring_message')).layoutWeight(1).height(40)
          .backgroundColor($r('app.color.accent')).onClick((): void => this.openMessage(item.user))
        Button($r('app.string.sponsoring_profile')).layoutWeight(1).height(40)
          .backgroundColor($r('app.color.surface')).fontColor($r('app.color.accent'))
          .onClick((): void => this.openCreator(item.user))
      }.width('100%')
    }.width('100%').padding(18).backgroundColor(isExpired ? $r('app.color.canvas') : $r('app.color.surface'))
      .borderRadius(20).opacity(isExpired ? 0.72 : 1)
  }

  build() {
    HdsNavDestination() {
      List({ space: 12, scroller: this.scroller }) {
        if (!this.loggedIn) {
          ListItem() {
            Column({ space: 16 }) {
              StateView({ title: $r('app.string.sponsoring_login') })
              Button($r('app.string.login')).backgroundColor($r('app.color.accent'))
                .onClick((): void => this.stack.pushPath({ name: 'Login' }))
            }.width('100%')
          }
        } else if (this.loading || this.failed) {
          ListItem() { StateView({ loading: this.loading, error: this.failed, onAction: (): void => { this.load(); } }) }
        } else if (this.active.length === 0 && this.expired.length === 0) {
          ListItem() { StateView({ title: $r('app.string.sponsoring_empty') }) }
        } else {
          if (this.active.length > 0) {
            ListItem() { Text($r('app.string.sponsoring_current')).fontSize(14).fontColor($r('app.color.secondary')).width('100%') }
            ForEach(this.active, (item: SponsoringItem) => {
              ListItem() { this.SponsorCard(item, false) }
            }, (item: SponsoringItem): string => item.user?.user_id ?? '')
          }
          if (this.expired.length > 0) {
            ListItem() { Text($r('app.string.sponsoring_expired')).fontSize(14).fontColor($r('app.color.secondary')).width('100%').margin({ top: 12 }) }
            ForEach(this.expired, (item: SponsoringItem) => {
              ListItem() { this.SponsorCard(item, true) }
            }, (item: SponsoringItem): string => (item.user?.user_id ?? '') + ':expired')
          }
        }
      }.width('100%').height('100%').padding({ left: 16, right: 16 })
        .contentStartOffset(this.topInset + 64).contentEndOffset(this.bottomInset + 24)
        .scrollBar(BarState.Off).backgroundColor($r('app.color.canvas'))
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: $r('app.string.sponsoring_title') } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
