import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { Avatar, StateView } from '../components/Common';
import { IncomeBillAmount, IncomeBillMonth, IncomeBillYear, IncomeDashboard, IncomeOrder, IncomeOrderPage, IncomeValue,
  IncomePaidOrder, IncomePaidOrderAggregate, IncomeStatRecord, IncomeWithdrawal, incomeHasMore, incomeOrderCursor,
  incomeValueText } from '../models/IncomeModels';
import { incomeApi } from '../services/IncomeApi';
import { appStore } from '../services/AppStore';
import { RouteParam } from '../models/Models';
import { afdianPreferredOrigin } from '../common/UrlPolicy';
import { navigationStyle } from '../utils/NavigationStyle';
import { formatDateTime } from '../utils/DisplayTime';

@Component
export struct IncomeDestination {
  @Consume('pageStack') stack: NavPathStack;
  @StorageProp('afd.topInset') topInset: number = 40;
  @StorageProp('afd.bottomInset') bottomInset: number = 12;
  @StorageProp('afd.width') widthVp: number = 400;
  @StorageProp('afd.material') material: boolean = true;
  @StorageProp('afd.loggedIn') loggedIn: boolean = false;
  @StorageProp('afd.sessionRevision') @Watch('sessionChanged') revision: number = 0;
  @State dashboard: IncomeDashboard = new IncomeDashboard();
  @State years: IncomeBillYear[] = [];
  @State orders: IncomeOrder[] = [];
  @State withdrawals: IncomeWithdrawal[] = [];
  @State dailyStats: IncomeStatRecord[] = [];
  @State periodStats: IncomeStatRecord[] = [];
  @State paidOrders: IncomePaidOrder[] = [];
  @State paidOrdersKnown: boolean = false;
  @State statsType: string = 'day';
  @State selectedTab: number = 0;
  @State overviewLoading: boolean = false;
  @State overviewFailed: boolean = false;
  @State tabLoading: boolean = false;
  @State tabFailed: boolean = false;
  @State loadingMore: boolean = false;
  @State moreFailed: boolean = false;
  @State hasMore: boolean = false;
  @State expandedOrder: string = '';
  @State statsLoading: boolean = false;
  @State statsFailed: boolean = false;
  @State settlementNow: number = Date.now();
  @State hiddenCards: string[] = [];
  private generation: number = 0;
  private tabGeneration: number = 0;
  private dailyGeneration: number = 0;
  private statsGeneration: number = 0;
  private paidOrdersGeneration: number = 0;
  private active: boolean = false;
  private scroller: Scroller = new Scroller();
  private settlementTimer: number = -1;

  aboutToAppear(): void {
    this.active = true;
    if (this.settlementTimer >= 0) { clearInterval(this.settlementTimer); }
    this.settlementTimer = setInterval((): void => {
      if (this.active) { this.settlementNow = Date.now(); }
    }, 60000);
    this.hiddenCards = appStore.loadIncomeHiddenCards();
    this.reload();
  }
  aboutToDisappear(): void {
    this.active = false;
    if (this.settlementTimer >= 0) { clearInterval(this.settlementTimer); }
    this.settlementTimer = -1;
    this.generation++;
    this.tabGeneration++;
    this.dailyGeneration++;
    this.statsGeneration++;
    this.paidOrdersGeneration++;
  }

  private sessionChanged(): void {
    this.generation++; this.tabGeneration++; this.dailyGeneration++; this.statsGeneration++; this.paidOrdersGeneration++;
    this.clearData();
    this.hiddenCards = appStore.loadIncomeHiddenCards();
    if (this.active) { this.reload(); }
  }

  private clearData(): void {
    this.dashboard = new IncomeDashboard(); this.years = []; this.orders = []; this.withdrawals = [];
    this.dailyStats = []; this.periodStats = []; this.paidOrders = []; this.paidOrdersKnown = false;
    this.statsLoading = false; this.statsFailed = false;
    this.hasMore = false; this.expandedOrder = ''; this.loadingMore = false; this.moreFailed = false;
    this.overviewLoading = false; this.tabLoading = false;
    this.overviewFailed = false; this.tabFailed = false;
  }

  private reload(): void {
    const generation: number = ++this.generation;
    if (!appStore.isLoggedIn()) { this.clearData(); return; }
    this.loadOverview(generation);
    if (this.selectedTab === 3) { this.loadPeriodStats(); } else { this.loadTab(); }
    this.loadDailyStats();
    this.loadPaidOrders();
  }

  private isCardHidden(cardId: string): boolean {
    return this.hiddenCards.indexOf(cardId) >= 0;
  }

  private hideCard(cardId: string): void {
    if (this.isCardHidden(cardId)) { return; }
    this.hiddenCards = this.hiddenCards.concat([cardId]);
    appStore.saveIncomeHiddenCards(this.hiddenCards);
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.income_card_hidden') });
  }

  private restoreCards(): void {
    this.hiddenCards = [];
    appStore.saveIncomeHiddenCards(this.hiddenCards);
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.income_cards_restored') });
  }

  private async loadOverview(generation: number): Promise<void> {
    this.overviewLoading = true; this.overviewFailed = false;
    try {
      const data: IncomeDashboard = await incomeApi.dashboard();
      if (!this.active || generation !== this.generation) { return; }
      this.dashboard = data;
    } catch (error) {
      if (this.active && generation === this.generation) { this.overviewFailed = true; }
    } finally {
      if (this.active && generation === this.generation) { this.overviewLoading = false; }
    }
  }

  private selectTab(tab: number): void {
    if (tab === this.selectedTab) { return; }
    this.selectedTab = tab; this.expandedOrder = '';
    if (tab === 3) { this.loadPeriodStats(); } else { this.loadTab(); }
  }

  private async loadTab(): Promise<void> {
    const generation: number = this.generation;
    const tabGeneration: number = ++this.tabGeneration;
    const tab: number = this.selectedTab;
    this.loadingMore = false; this.moreFailed = false; this.hasMore = false;
    if (!appStore.isLoggedIn()) { this.tabLoading = false; return; }
    this.tabLoading = true; this.tabFailed = false;
    try {
      if (tab === 0) {
        const years: IncomeBillYear[] = await incomeApi.monthlyBills();
        if (!this.currentRequest(generation, tabGeneration)) { return; }
        this.years = years;
      } else if (tab === 1) {
        const page: IncomeOrderPage = await incomeApi.receivedOrders();
        if (!this.currentRequest(generation, tabGeneration)) { return; }
        this.orders = page.list ?? []; this.hasMore = incomeHasMore(page.has_more);
      } else if (tab === 2) {
        const withdrawals: IncomeWithdrawal[] = await incomeApi.withdrawals();
        if (!this.currentRequest(generation, tabGeneration)) { return; }
        this.withdrawals = withdrawals;
      } else {
        return;
      }
    } catch (error) {
      if (this.currentRequest(generation, tabGeneration)) { this.tabFailed = true; }
    } finally {
      if (this.currentRequest(generation, tabGeneration)) { this.tabLoading = false; }
    }
  }

  private currentRequest(generation: number, tabGeneration: number): boolean {
    return this.active && generation === this.generation && tabGeneration === this.tabGeneration;
  }

  private async loadDailyStats(): Promise<void> {
    const generation: number = ++this.dailyGeneration;
    try {
      const records: IncomeStatRecord[] = await incomeApi.recentDailyStats(45);
      if (this.active && generation === this.dailyGeneration) { this.dailyStats = records; }
    } catch (error) {
      if (this.active && generation === this.dailyGeneration) { this.dailyStats = []; }
    }
  }

  private async loadPaidOrders(): Promise<void> {
    const generation: number = ++this.paidOrdersGeneration;
    this.paidOrdersKnown = false;
    try {
      const records: IncomePaidOrder[] = await incomeApi.paidOrders(
        this.offsetStartSeconds(29), this.offsetStartSeconds(-1));
      if (this.active && generation === this.paidOrdersGeneration) {
        this.paidOrders = records;
        this.paidOrdersKnown = true;
        if (this.selectedTab === 3 && !this.hasUsableStats(this.periodStats)) {
          this.periodStats = this.paidPeriodStats();
          this.statsFailed = false;
        }
      }
    } catch (error) {
      if (this.active && generation === this.paidOrdersGeneration) {
        this.paidOrders = [];
        this.paidOrdersKnown = false;
      }
    }
  }

  private async loadPeriodStats(): Promise<void> {
    const generation: number = ++this.statsGeneration;
    this.statsLoading = true; this.statsFailed = false;
    try {
      const data = await incomeApi.stats(this.statsType, 1);
      if (!this.active || generation !== this.statsGeneration) { return; }
      const records: IncomeStatRecord[] = data.list ?? [];
      this.periodStats = this.hasUsableStats(records) ? records : this.paidPeriodStats();
    } catch (error) {
      if (this.active && generation === this.statsGeneration) { this.statsFailed = true; }
    } finally {
      if (this.active && generation === this.statsGeneration) { this.statsLoading = false; }
    }
  }

  private selectStatsType(type: string): void {
    if (this.statsType === type) { return; }
    this.statsType = type;
    this.loadPeriodStats();
  }

  private compactDate(offsetDays: number): string {
    const value: Date = new Date();
    value.setDate(value.getDate() - offsetDays);
    return value.getFullYear().toString() +
      (value.getMonth() + 1).toString().padStart(2, '0') +
      value.getDate().toString().padStart(2, '0');
  }

  private statsBetween(startOffsetDays: number, endOffsetDays: number): IncomeStatRecord[] {
    const start: string = this.compactDate(startOffsetDays);
    const end: string = this.compactDate(endOffsetDays);
    return this.dailyStats.filter((record: IncomeStatRecord): boolean =>
      record.date_str >= start && record.date_str <= end);
  }

  private statsIncome(startOffsetDays: number, endOffsetDays: number): string {
    const records: IncomeStatRecord[] = this.statsBetween(startOffsetDays, endOffsetDays);
    let hasKnownValue: boolean = false;
    let total: number = 0;
    for (let i: number = 0; i < records.length; i++) {
      const text: string = incomeValueText(records[i].paid_order_real_amount);
      if (text.length === 0) { continue; }
      const value: number = Number(text);
      if (Number.isFinite(value)) {
        hasKnownValue = true;
        total += value;
      }
    }
    return hasKnownValue ? total.toFixed(2) : '--';
  }

  private statsField(record: IncomeStatRecord, field: string): string {
    if (field === 'uv') { return incomeValueText(record.uv); }
    if (field === 'orders') { return incomeValueText(record.paid_order_count); }
    return incomeValueText(record.paid_user_count);
  }

  private offsetStartSeconds(offsetDays: number): number {
    const value: Date = new Date();
    value.setHours(0, 0, 0, 0);
    value.setDate(value.getDate() - offsetDays);
    return Math.floor(value.getTime() / 1000);
  }

  private paidOrderAggregate(startOffsetDays: number, endOffsetDays: number): IncomePaidOrderAggregate {
    const start: number = this.offsetStartSeconds(startOffsetDays);
    const end: number = this.offsetStartSeconds(endOffsetDays - 1);
    const output: IncomePaidOrderAggregate = new IncomePaidOrderAggregate();
    const supporters: string[] = [];
    for (let i: number = 0; i < this.paidOrders.length; i++) {
      const order: IncomePaidOrder = this.paidOrders[i];
      const updateTime: number = Number(incomeValueText(order.update_time));
      if (!Number.isFinite(updateTime) || updateTime < start || updateTime >= end) { continue; }
      output.orderCount++;
      const amount: number = Number(incomeValueText(order.total_amount));
      if (Number.isFinite(amount)) { output.amount += amount; }
      const userId: string = (order.user_id ?? order.user?.user_id ?? '').trim();
      if (userId.length > 0 && supporters.indexOf(userId) < 0) { supporters.push(userId); }
    }
    output.sponsorCount = supporters.length;
    return output;
  }

  private periodIncome(startOffsetDays: number, endOffsetDays: number): string {
    if (!this.paidOrdersKnown) { return this.statsIncome(startOffsetDays, endOffsetDays); }
    return this.paidOrderAggregate(startOffsetDays, endOffsetDays).amount.toFixed(2);
  }

  private periodCount(startOffsetDays: number, endOffsetDays: number, field: string): string {
    if (!this.paidOrdersKnown || field === 'uv') {
      return this.statsCount(startOffsetDays, endOffsetDays, field);
    }
    const aggregate: IncomePaidOrderAggregate = this.paidOrderAggregate(startOffsetDays, endOffsetDays);
    return (field === 'orders' ? aggregate.orderCount : aggregate.sponsorCount).toString();
  }

  private statsCount(startOffsetDays: number, endOffsetDays: number, field: string): string {
    const records: IncomeStatRecord[] = this.statsBetween(startOffsetDays, endOffsetDays);
    let hasKnownValue: boolean = false;
    let total: number = 0;
    for (let i: number = 0; i < records.length; i++) {
      const value: string = this.statsField(records[i], field);
      if (value.length === 0) { continue; }
      const numberValue: number = Number(value);
      if (Number.isFinite(numberValue)) {
        hasKnownValue = true;
        total += numberValue;
      }
    }
    return hasKnownValue ? total.toString() : '--';
  }

  private statIncome(record: IncomeStatRecord): number {
    const value: number = Number(incomeValueText(record.paid_order_real_amount));
    return Number.isFinite(value) ? value : 0;
  }

  private hasUsableStats(records: IncomeStatRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      if (incomeValueText(records[i].paid_order_real_amount).length > 0 ||
        incomeValueText(records[i].paid_order_count).length > 0 ||
        incomeValueText(records[i].uv).length > 0) {
        return true;
      }
    }
    return false;
  }

  private hasKnownDailyIncome(): boolean {
    for (let i: number = 0; i < this.dailyStats.length; i++) {
      if (incomeValueText(this.dailyStats[i].paid_order_real_amount).length > 0) { return true; }
    }
    return false;
  }

  private paidStatForRange(startOffsetDays: number, endOffsetDays: number): IncomeStatRecord {
    const aggregate: IncomePaidOrderAggregate = this.paidOrderAggregate(startOffsetDays, endOffsetDays);
    const record: IncomeStatRecord = new IncomeStatRecord();
    record.date_str = this.compactDate(startOffsetDays);
    record.paid_order_real_amount = aggregate.amount.toFixed(2);
    record.paid_order_count = aggregate.orderCount;
    record.paid_user_count = aggregate.sponsorCount;
    return record;
  }

  private paidDailyStats(days: number): IncomeStatRecord[] {
    const records: IncomeStatRecord[] = [];
    for (let offset: number = days - 1; offset >= 0; offset--) {
      records.push(this.paidStatForRange(offset, offset));
    }
    return records;
  }

  private paidPeriodStats(): IncomeStatRecord[] {
    if (!this.paidOrdersKnown) { return []; }
    if (this.statsType === 'day') {
      return this.paidDailyStats(30).reverse();
    }
    if (this.statsType === 'week') {
      const now: Date = new Date();
      const daysSinceMonday: number = (now.getDay() + 6) % 7;
      const records: IncomeStatRecord[] = [];
      for (let index: number = 0; ; index++) {
        const start: number = daysSinceMonday + index * 7;
        if (start > 29) { break; }
        records.push(this.paidStatForRange(start, Math.max(0, start - 6)));
      }
      return records;
    }
    const now: Date = new Date();
    const records: IncomeStatRecord[] = [];
    const currentMonthStart: number = now.getDate() - 1;
    records.push(this.paidStatForRange(currentMonthStart, 0));
    const previousMonthStart: Date = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const previousMonthDays: number = new Date(now.getFullYear(), now.getMonth(), 0).getDate();
    const previousOffset: number = currentMonthStart + previousMonthDays;
    if (previousOffset <= 29) {
      records.push(this.paidStatForRange(previousOffset, currentMonthStart));
    }
    return records;
  }

  private recentTrend(): IncomeStatRecord[] {
    const source: IncomeStatRecord[] = !this.hasKnownDailyIncome() && this.paidOrdersKnown ?
      this.paidDailyStats(30) : this.dailyStats;
    const sorted: IncomeStatRecord[] = source.slice().sort((left: IncomeStatRecord, right: IncomeStatRecord): number =>
      left.date_str.localeCompare(right.date_str));
    let endExclusive: number = sorted.length;
    while (endExclusive > 0 && this.statIncome(sorted[endExclusive - 1]) <= 0) { endExclusive--; }
    if (endExclusive === 0) { endExclusive = sorted.length; }
    return sorted.slice(Math.max(0, endExclusive - 14), endExclusive);
  }

  private maxTrendIncome(): number {
    let maximum: number = 0;
    const records: IncomeStatRecord[] = this.recentTrend();
    for (let i: number = 0; i < records.length; i++) {
      maximum = Math.max(maximum, this.statIncome(records[i]));
    }
    return maximum;
  }

  private trendHeight(record: IncomeStatRecord): number {
    const maximum: number = this.maxTrendIncome();
    return maximum <= 0 ? 4 : Math.max(4, this.statIncome(record) / maximum * 56);
  }

  private statDate(value: string): string {
    return value.length === 8 ? value.substring(2, 4) + '/' + value.substring(4, 6) + '/' +
      value.substring(6, 8) : value;
  }

  private settlementTarget(): Date {
    const now: Date = new Date();
    const currentDay: number = now.getDate();
    const currentHour: number = now.getHours();
    const target: Date = new Date(now.getFullYear(), now.getMonth(), 1, 10, 0, 0);
    if (currentDay > 1 || currentHour >= 10) { target.setMonth(target.getMonth() + 1); }
    return target;
  }

  private settlementWindowStart(): Date {
    const target: Date = this.settlementTarget();
    return new Date(target.getFullYear(), target.getMonth() - 1, 1, 10, 0, 0);
  }

  private settlementRingProgress(): number {
    const now: number = this.settlementNow;
    const start: number = this.settlementWindowStart().getTime();
    const end: number = this.settlementTarget().getTime();
    if (end <= start) { return 0; }
    return Math.max(0, Math.min(100, (now - start) / (end - start) * 100));
  }

  private settlementRemainingMinutes(): number {
    const now: number = this.settlementNow;
    return Math.max(0, Math.ceil((this.settlementTarget().getTime() - now) / 60000));
  }

  private settlementClockValue(): string {
    const minutes: number = this.settlementRemainingMinutes();
    if (minutes >= 1440) { return Math.floor(minutes / 1440).toString(); }
    if (minutes >= 60) { return Math.floor(minutes / 60).toString(); }
    return minutes.toString();
  }

  private settlementClockUnit(): Resource {
    const minutes: number = this.settlementRemainingMinutes();
    if (minutes >= 1440) { return $r('app.string.income_settlement_day_unit'); }
    if (minutes >= 60) { return $r('app.string.income_settlement_hour_unit'); }
    return $r('app.string.income_settlement_minute_unit');
  }

  private settlementRemainingDetail(): Resource {
    const minutes: number = this.settlementRemainingMinutes();
    if (minutes <= 0) { return $r('app.string.income_settlement_due'); }
    if (minutes >= 1440) {
      return $r('app.string.income_settlement_remaining_detail_days',
        Math.floor(minutes / 60 % 24).toString());
    }
    return $r('app.string.income_settlement_remaining_detail_hours',
      (minutes % 60).toString());
  }

  private nextSettlement(): ResourceStr {
    const target: Date = this.settlementTarget();
    return $r('app.string.income_settlement_time', (target.getMonth() + 1).toString(),
      target.getDate().toString());
  }

  private nextSettlementYear(): ResourceStr {
    return $r('app.string.income_settlement_year', this.settlementTarget().getFullYear().toString());
  }

  private settlementRemaining(): ResourceStr {
    const now: Date = new Date();
    const target: Date = this.settlementTarget();
    const totalHours: number = Math.max(0, Math.floor((target.getTime() - now.getTime()) / 3600000));
    return $r('app.string.income_settlement_remaining', Math.floor(totalHours / 24).toString(),
      (totalHours % 24).toString());
  }

  private isSettlementWindow(): boolean {
    const now: Date = new Date();
    return now.getDate() === 1 && now.getHours() < 10;
  }

  private currentMonthBill(): IncomeBillAmount | undefined {
    const now: Date = new Date();
    const yearText: string = now.getFullYear().toString();
    const monthText: string = (now.getMonth() + 1).toString();
    for (let y: number = 0; y < this.years.length; y++) {
      const year: IncomeBillYear = this.years[y];
      if (String(year.year ?? '') !== yearText) { continue; }
      const months: IncomeBillMonth[] = year.data ?? [];
      for (let m: number = 0; m < months.length; m++) {
        if (String(months[m].month ?? '') === monthText) { return months[m].data; }
      }
    }
    return undefined;
  }

  private currentMonthCreatorAmount(): IncomeValue | undefined {
    const official: IncomeValue | undefined = this.currentMonthBill()?.creator_amount;
    if (incomeValueText(official).length > 0) { return official; }
    const monthText: string = incomeValueText(this.dashboard.summary?.month_amount);
    if (monthText.length === 0) { return undefined; }
    const monthAmount: number = Number(monthText);
    if (!Number.isFinite(monthAmount)) { return undefined; }
    return (Math.floor(monthAmount * 0.94 * 100) / 100).toFixed(2);
  }

  private openWithdraw(): void {
    this.stack.pushPath({
      name: 'Web',
      param: new RouteParam(afdianPreferredOrigin(appStore.getRoute()) + '/withdraw', '')
    });
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore || this.tabLoading || !this.hasMore || this.selectedTab !== 1 || this.orders.length === 0) { return; }
    const generation: number = this.generation;
    const tabGeneration: number = this.tabGeneration;
    const cursor: string = incomeOrderCursor(this.orders[this.orders.length - 1]);
    this.loadingMore = true; this.moreFailed = false;
    try {
      const page: IncomeOrderPage = await incomeApi.receivedOrders(cursor);
      if (!this.currentRequest(generation, tabGeneration)) { return; }
      const incoming: IncomeOrder[] = page.list ?? [];
      const unique: IncomeOrder[] = incoming.filter((item: IncomeOrder): boolean => {
        const id: string = incomeOrderCursor(item);
        return id.length === 0 || !this.orders.some((old: IncomeOrder): boolean => incomeOrderCursor(old) === id);
      });
      if (incomeHasMore(page.has_more) && unique.length === 0) { throw new Error('Income page did not advance'); }
      this.orders = this.orders.concat(unique); this.hasMore = incomeHasMore(page.has_more);
    } catch (error) {
      if (this.currentRequest(generation, tabGeneration)) { this.moreFailed = true; }
    } finally {
      if (this.currentRequest(generation, tabGeneration)) { this.loadingMore = false; }
    }
  }

  private dimension(resource: Resource): number {
    const value: number = this.getUIContext().getHostContext()?.resourceManager.getNumber(resource.id) ?? 0;
    return this.getUIContext().px2vp(value);
  }

  private money(value: IncomeValue | undefined): ResourceStr {
    const text: string = incomeValueText(value);
    return text.length > 0 ? $r('app.string.income_cny', text) : $r('app.string.income_unavailable');
  }

  private date(value: IncomeValue | undefined): ResourceStr {
    const text: string = incomeValueText(value);
    if (text.length === 0 || Number(text) <= 0) { return $r('app.string.income_unavailable'); }
    const formatted: string = formatDateTime(Number(text));
    return formatted.length > 0 ? formatted : $r('app.string.income_unavailable');
  }

  private count(value: IncomeValue | undefined): ResourceStr {
    const text: string = incomeValueText(value);
    return text.length > 0 ? $r('app.string.income_supporter_count', text) : $r('app.string.income_unavailable');
  }

  private orderKey(order: IncomeOrder, index: number): string {
    const cursor: string = incomeOrderCursor(order);
    return cursor.length > 0 ? 'income:' + cursor : 'income:' + (order.user?.user_id ?? '') + ':' + String(order.create_time ?? '') + ':' + index;
  }

  private hasMonthlyBills(): boolean {
    return this.years.some((year: IncomeBillYear): boolean => (year.data?.length ?? 0) > 0);
  }

  private withdrawalStatus(value: IncomeValue | undefined): Resource {
    const status: string = String(value ?? '');
    if (status === '1') { return $r('app.string.income_withdraw_waiting'); }
    if (status === '2') { return $r('app.string.income_withdraw_success'); }
    if (status === '3' || status === '4') { return $r('app.string.income_withdraw_failed'); }
    if (status === '7') { return $r('app.string.income_withdraw_bank_error'); }
    if (status === '8') { return $r('app.string.income_withdraw_transferring'); }
    return $r('app.string.income_withdraw_unknown');
  }

  @Builder private Metric(title: Resource, value: IncomeValue | undefined, cardId: string) {
    Column({ space: 8 }) {
      Text(title).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
      Text(this.money(value)).fontSize($r('app.float.income_metric_size')).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text')).maxLines(2).wordBreak(WordBreak.BREAK_ALL)
    }.alignItems(HorizontalAlign.Start).padding($r('app.float.income_card_padding')).width('100%')
      .constraintSize({ minHeight: this.dimension($r('app.float.income_metric_height')) })
      .backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
      .gesture(LongPressGesture({ repeat: false, duration: 600 })
        .onAction((): void => this.hideCard(cardId)))
  }

  @Builder private DataMetric(title: Resource, value: string, unit: Resource, cardId: string) {
    Column({ space: 6 }) {
      Text(title).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
      Row({ space: 4 }) {
        Text(value).fontSize($r('app.float.income_metric_size')).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text'))
        Text(unit).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
      }.alignItems(VerticalAlign.Bottom)
    }.padding($r('app.float.income_card_padding')).width('100%').alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.dimension($r('app.float.income_metric_height')) })
      .backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
      .gesture(LongPressGesture({ repeat: false, duration: 600 })
        .onAction((): void => this.hideCard(cardId)))
  }

  @Builder private SettlementCard() {
    Column({ space: 12 }) {
      Row({ space: 16 }) {
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.clock')).fontSize(20).fontColor([$r('app.color.accent')])
            Text($r('app.string.income_settlement_title')).fontSize($r('app.float.income_body_size'))
              .fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          }
          Text(this.nextSettlement()).fontSize($r('app.float.income_metric_size')).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent')).maxLines(1)
          Text(this.nextSettlementYear()).fontSize($r('app.float.income_label_size'))
            .fontColor($r('app.color.secondary'))
          Text(this.settlementRemainingDetail()).fontSize($r('app.float.income_label_size'))
            .fontColor($r('app.color.text'))
          if (this.isSettlementWindow()) {
            Text($r('app.string.income_settlement_window')).fontSize($r('app.float.income_label_size'))
              .fontColor($r('app.color.accent'))
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: this.settlementRingProgress(), total: 100, type: ProgressType.Ring })
            .width($r('app.float.income_settlement_ring_size'))
            .height($r('app.float.income_settlement_ring_size'))
            .color($r('app.color.accent'))
            .backgroundColor($r('app.color.surface'))
            .style({ strokeWidth: $r('app.float.income_settlement_ring_stroke'), enableSmoothEffect: true })
          Column({ space: 1 }) {
            Text(this.settlementClockValue()).fontSize($r('app.float.income_settlement_clock_size'))
              .fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
            Text(this.settlementClockUnit()).fontSize($r('app.float.income_label_size'))
              .fontColor($r('app.color.secondary'))
          }.alignItems(HorizontalAlign.Center)
        }.width($r('app.float.income_settlement_ring_size'))
          .height($r('app.float.income_settlement_ring_size'))
      }
      .width('100%').alignItems(VerticalAlign.Center)
      Divider().color($r('app.color.separator'))
      Row({ space: 12 }) {
        if (incomeValueText(this.dashboard.summary?.unconfirmed_amount).length > 0) {
          Text($r('app.string.income_pending_amount',
            incomeValueText(this.dashboard.summary?.unconfirmed_amount)))
            .fontSize($r('app.float.income_body_size')).fontColor($r('app.color.text')).layoutWeight(1)
        } else {
          Blank()
        }
        Button($r('app.string.income_withdraw_now')).fontSize($r('app.float.income_label_size'))
          .fontColor($r('app.color.accent')).backgroundColor($r('app.color.surface'))
          .height(36).borderRadius(18).onClick((): void => this.openWithdraw())
      }.width('100%').alignItems(VerticalAlign.Center)
      Text($r('app.string.income_settlement_hint')).fontSize($r('app.float.income_label_size')).lineHeight(20)
        .fontColor($r('app.color.secondary')).width('100%')
      Text($r('app.string.income_creator_share_hint')).fontSize($r('app.float.income_label_size')).lineHeight(20)
        .fontColor($r('app.color.secondary')).width('100%')
    }.padding($r('app.float.income_card_padding')).width('100%').alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.accent_soft')).borderRadius($r('app.float.income_card_radius'))
      .gesture(LongPressGesture({ repeat: false, duration: 600 })
        .onAction((): void => this.hideCard('settlement')))
  }

  @Builder private IncomeTrend() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.income_trend_title')).fontSize($r('app.float.income_body_size'))
          .fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
        Text($r('app.string.income_trend_hint')).fontSize($r('app.float.income_label_size'))
          .fontColor($r('app.color.secondary'))
      }.width('100%')
      if (this.recentTrend().length === 0) {
        Text($r('app.string.income_stats_empty')).fontSize($r('app.float.income_body_size'))
          .fontColor($r('app.color.secondary')).padding({ top: 18, bottom: 18 })
      } else {
        Row({ space: 4 }) {
          ForEach(this.recentTrend(), (record: IncomeStatRecord) => {
            Column({ space: 4 }) {
              Blank()
              Column().width('72%').height(this.trendHeight(record)).borderRadius(4)
                .backgroundColor($r('app.color.accent'))
              Text(record.date_str.length === 8 ? record.date_str.substring(6, 8) : record.date_str)
                .fontSize(8).fontColor($r('app.color.secondary'))
            }.layoutWeight(1).height(76).justifyContent(FlexAlign.End)
          }, (record: IncomeStatRecord): string => record.date_str)
        }.width('100%').height(76).alignItems(VerticalAlign.Bottom)
      }
    }.padding($r('app.float.income_card_padding')).width('100%').alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
      .gesture(LongPressGesture({ repeat: false, duration: 600 })
        .onAction((): void => this.hideCard('trend')))
  }

  @Builder private StatsTypeButton(type: string, label: Resource) {
    Button({ type: ButtonType.Normal }) {
      Text(label).fontSize($r('app.float.income_label_size'))
        .fontWeight(this.statsType === type ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.statsType === type ? $r('app.color.accent') : $r('app.color.secondary'))
    }.layoutWeight(1).height(36).borderRadius(18)
      .backgroundColor(this.statsType === type ? $r('app.color.accent_soft') : $r('app.color.surface'))
      .onClick((): void => this.selectStatsType(type))
  }

  @Builder private StatRow(record: IncomeStatRecord, index: number) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(this.statDate(record.date_str)).fontSize($r('app.float.income_body_size'))
          .fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
        Text(this.money(record.paid_order_real_amount)).fontSize($r('app.float.income_metric_size'))
          .fontColor($r('app.color.accent'))
      }.width('100%')
      Row({ space: 14 }) {
        Text($r('app.string.income_stat_visitors', incomeValueText(record.uv) || '--'))
          .fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
        Text($r('app.string.income_stat_orders', incomeValueText(record.paid_order_count) || '--'))
          .fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
        Text($r('app.string.income_stat_supporters', incomeValueText(record.paid_user_count) || '--'))
          .fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
      }.width('100%')
    }.padding($r('app.float.income_card_padding')).width('100%').alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: this.dimension($r('app.float.income_content_max_width')) })
      .backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
  }

  @Builder private Overview() {
    Column({ space: 12 }) {
      Row() {
        Text($r('app.string.income_overview')).fontSize($r('app.float.income_section_size')).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text')).layoutWeight(1)
        Button($r('app.string.income_refresh')).fontSize($r('app.float.income_label_size')).backgroundColor(Color.Transparent)
          .fontColor($r('app.color.accent')).enabled(!this.overviewLoading && !this.tabLoading)
          .onClick((): void => this.reload())
      }.width('100%')
      if (this.overviewLoading) { LoadingProgress().width(32).height(32).color($r('app.color.accent')).margin($r('app.float.income_card_padding')) }
      else if (this.overviewFailed) {
        Column({ space: 10 }) {
          Text($r('app.string.income_overview_error')).fontSize($r('app.float.income_body_size')).fontColor($r('app.color.secondary'))
          Button($r('app.string.retry')).backgroundColor($r('app.color.accent')).onClick((): void => { this.loadOverview(this.generation); })
        }.width('100%').padding($r('app.float.income_card_padding')).backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
      } else {
        if (!this.isCardHidden('balance')) {
          Column({ space: 10 }) {
            Text($r('app.string.income_available_balance')).fontSize($r('app.float.income_body_size')).fontColor($r('app.color.secondary'))
            Text(this.money(this.dashboard.balance_after_tax)).fontSize($r('app.float.income_balance_size')).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
            if (incomeValueText(this.dashboard.balance).length > 0) {
              Text($r('app.string.income_balance_before_tax', incomeValueText(this.dashboard.balance)))
                .fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
            }
            if (incomeValueText(this.dashboard.transfer_fee_detail?.afd_fee).length > 0) {
              Text($r('app.string.income_platform_fee', incomeValueText(this.dashboard.transfer_fee_detail?.afd_fee)))
                .fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
            }
            if (incomeValueText(this.dashboard.transfer_fee_detail?.channel_fee).length > 0) {
              Text($r('app.string.income_channel_fee', incomeValueText(this.dashboard.transfer_fee_detail?.channel_fee)))
                .fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
            }
          }.padding($r('app.float.income_card_padding')).width('100%').alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
            .gesture(LongPressGesture({ repeat: false, duration: 600 })
              .onAction((): void => this.hideCard('balance')))
        }
        GridRow({ columns: this.widthVp >= 840 ? 4 : 2, gutter: { x: 12, y: 12 } }) {
          if (!this.isCardHidden('total')) {
            GridCol() { this.Metric($r('app.string.income_total'), this.dashboard.summary?.all_sum_amount, 'total') }
          }
          if (!this.isCardHidden('settled')) {
            GridCol() { this.Metric($r('app.string.income_settled'), this.dashboard.summary?.bill_amount, 'settled') }
          }
          if (!this.isCardHidden('this_month')) {
            GridCol() { this.Metric($r('app.string.income_this_month'), this.dashboard.summary?.month_amount, 'this_month') }
          }
          if (!this.isCardHidden('next_month')) {
            GridCol() { this.Metric($r('app.string.income_next_month'), this.dashboard.summary?.next_month_amount, 'next_month') }
          }
          if (!this.isCardHidden('creator_share')) {
            GridCol() { this.Metric($r('app.string.income_creator_share'), this.currentMonthCreatorAmount(), 'creator_share') }
          }
        }
        if (!this.isCardHidden('settlement')) { this.SettlementCard() }
        GridRow({ columns: this.widthVp >= 840 ? 4 : 2, gutter: { x: 12, y: 12 } }) {
          if (!this.isCardHidden('today')) {
            GridCol() { this.DataMetric($r('app.string.income_today'), this.periodIncome(0, 0), $r('app.string.income_yuan'), 'today') }
          }
          if (!this.isCardHidden('yesterday')) {
            GridCol() { this.DataMetric($r('app.string.income_yesterday'), this.periodIncome(1, 1), $r('app.string.income_yuan'), 'yesterday') }
          }
          if (!this.isCardHidden('last_7_days')) {
            GridCol() { this.DataMetric($r('app.string.income_last_7_days'), this.periodIncome(6, 0), $r('app.string.income_yuan'), 'last_7_days') }
          }
          if (!this.isCardHidden('last_30_days')) {
            GridCol() { this.DataMetric($r('app.string.income_last_30_days'), this.periodIncome(29, 0), $r('app.string.income_yuan'), 'last_30_days') }
          }
          if (!this.isCardHidden('sponsors_7_days')) {
            GridCol() { this.DataMetric($r('app.string.income_sponsors_7_days'), this.periodCount(6, 0, 'users'), $r('app.string.income_people'), 'sponsors_7_days') }
          }
          if (!this.isCardHidden('orders_7_days')) {
            GridCol() { this.DataMetric($r('app.string.income_orders_7_days'), this.periodCount(6, 0, 'orders'), $r('app.string.income_times'), 'orders_7_days') }
          }
          if (!this.isCardHidden('visitors_30_days')) {
            GridCol() { this.DataMetric($r('app.string.income_visitors_30_days'), this.periodCount(29, 0, 'uv'), $r('app.string.income_people'), 'visitors_30_days') }
          }
          if (!this.isCardHidden('history_visitors')) {
            GridCol() { this.DataMetric($r('app.string.income_history_visitors'), incomeValueText(this.dashboard.summary?.uv) || '--', $r('app.string.income_people'), 'history_visitors') }
          }
        }
        if (!this.isCardHidden('trend')) { this.IncomeTrend() }
        Text($r('app.string.income_month_hint')).fontSize($r('app.float.income_label_size')).lineHeight(20).fontColor($r('app.color.secondary')).width('100%')
      }
    }.width('100%').constraintSize({ maxWidth: this.dimension($r('app.float.income_content_max_width')) })
  }

  @Builder private TabButton(tab: number, label: Resource) {
    Button({ type: ButtonType.Normal }) {
      Text(label).fontSize($r('app.float.income_label_size')).fontWeight(this.selectedTab === tab ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selectedTab === tab ? $r('app.color.accent') : $r('app.color.secondary')).maxLines(2).textAlign(TextAlign.Center)
    }.width('100%').height($r('app.float.income_tab_height')).borderRadius($r('app.float.income_field_radius'))
      .backgroundColor(this.selectedTab === tab ? $r('app.color.accent_soft') : $r('app.color.surface'))
      .onClick((): void => this.selectTab(tab))
  }

  @Builder private MonthlyBill(year: IncomeBillYear, month: IncomeBillMonth) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text($r('app.string.income_bill_month', String(year.year ?? ''), String(month.month ?? '')))
          .fontSize($r('app.float.income_body_size')).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).layoutWeight(1)
        Text(this.money(month.data?.creator_amount)).fontSize($r('app.float.income_metric_size')).fontColor($r('app.color.accent'))
      }.width('100%')
      Text(this.count(month.data?.sponsor_count)).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
      Text($r('app.string.income_bill_creator_amount', incomeValueText(month.data?.creator_amount) || '--'))
        .fontSize($r('app.float.income_label_size')).fontColor($r('app.color.accent'))
      Text($r('app.string.income_bill_total_amount', incomeValueText(month.data?.total_amount) || '--'))
        .fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
      Text(this.date(month.data?.create_time)).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
    }.padding($r('app.float.income_card_padding')).width('100%').alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: this.dimension($r('app.float.income_content_max_width')) })
      .backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
  }

  @Builder private ReceivedOrder(order: IncomeOrder, index: number) {
    Column({ space: 12 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Avatar({ src: order.user?.avatar ?? '', diameter: 42 })
          Column({ space: 6 }) {
            Text(order.user?.name || $r('app.string.income_supporter')).fontSize($r('app.float.income_body_size')).fontColor($r('app.color.text')).maxLines(2)
            Text(this.date(order.create_time)).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(this.money(order.total_amount)).fontSize($r('app.float.income_metric_size')).fontColor($r('app.color.accent'))
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('app.color.secondary')])
            .rotate({ angle: this.expandedOrder === this.orderKey(order, index) ? 90 : 0 })
        }.width('100%')
      }.width('100%').padding(0).backgroundColor(Color.Transparent).borderRadius(0)
        .onClick((): void => { const key: string = this.orderKey(order, index); this.expandedOrder = this.expandedOrder === key ? '' : key; })
      if (this.expandedOrder === this.orderKey(order, index)) {
        Divider().color($r('app.color.separator'))
        Text(order.plan === undefined || order.plan === null ? $r('app.string.income_plan_unavailable') : order.plan.name || $r('app.string.income_custom_support'))
          .fontSize($r('app.float.income_body_size')).fontColor($r('app.color.text')).width('100%')
        if (incomeValueText(order.month).length > 0) {
          Text($r('app.string.income_support_months', incomeValueText(order.month))).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
        }
        if (incomeValueText(order.plan?.price).length > 0) {
          Text($r('app.string.income_plan_price', incomeValueText(order.plan?.price))).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
        }
        if ((order.remark ?? '').length > 0) {
          Text($r('app.string.income_message', order.remark ?? '')).fontSize($r('app.float.income_body_size')).lineHeight(24).fontColor($r('app.color.secondary')).width('100%')
        }
      }
    }.padding($r('app.float.income_card_padding')).width('100%').alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: this.dimension($r('app.float.income_content_max_width')) })
      .backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
  }

  @Builder private Withdrawal(item: IncomeWithdrawal) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text(this.withdrawalStatus(item.status)).fontSize($r('app.float.income_body_size')).fontColor($r('app.color.text')).layoutWeight(1)
        Text(this.money(item.pay_amount)).fontSize($r('app.float.income_metric_size')).fontColor($r('app.color.accent'))
      }.width('100%')
      Text(this.date(item.apply_time)).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary'))
      if (item.order_id !== undefined && String(item.order_id).length > 0) {
        Text($r('app.string.income_withdraw_order', String(item.order_id))).fontSize($r('app.float.income_label_size')).fontColor($r('app.color.secondary')).width('100%').wordBreak(WordBreak.BREAK_ALL)
      }
      if ((item.deal_error ?? '').length > 0) {
        Text(item.deal_error ?? '').fontSize($r('app.float.income_label_size')).fontColor($r('app.color.danger')).width('100%')
      }
    }.padding($r('app.float.income_card_padding')).width('100%').alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: this.dimension($r('app.float.income_content_max_width')) })
      .backgroundColor($r('app.color.surface')).borderRadius($r('app.float.income_card_radius'))
  }

  build() {
    HdsNavDestination() {
      List({ space: 12, scroller: this.scroller }) {
        if (!this.loggedIn) {
          ListItem() {
            Column({ space: 12 }) {
              StateView({ title: $r('app.string.income_login_hint') })
              Button($r('app.string.login')).backgroundColor($r('app.color.accent')).onClick((): void => this.stack.pushPath({ name: 'Login' }))
            }.width('100%')
          }
        } else {
          ListItem() { this.Overview() }
          ListItem() {
            GridRow({ columns: this.widthVp >= 840 ? 4 : 2, gutter: { x: 8, y: 8 } }) {
              GridCol() { this.TabButton(0, $r('app.string.income_monthly_bills')) }
              GridCol() { this.TabButton(1, $r('app.string.income_received_orders')) }
              GridCol() { this.TabButton(2, $r('app.string.income_withdraw_history')) }
              GridCol() { this.TabButton(3, $r('app.string.income_stats_title')) }
            }.width('100%').constraintSize({ maxWidth: this.dimension($r('app.float.income_content_max_width')) }).margin({ top: 8 })
          }
          if (this.tabLoading || this.tabFailed) {
            ListItem() { StateView({ loading: this.tabLoading, error: this.tabFailed, onAction: (): void => { this.loadTab(); } }) }
          } else if (this.selectedTab === 0) {
            ForEach(this.years, (year: IncomeBillYear) => {
              ForEach(year.data ?? [], (month: IncomeBillMonth) => {
                ListItem() { this.MonthlyBill(year, month) }
              }, (month: IncomeBillMonth): string => String(year.year) + ':' + String(month.month))
            }, (year: IncomeBillYear): string => String(year.year))
            if (!this.hasMonthlyBills()) { ListItem() { StateView({ title: $r('app.string.income_no_bills') }) } }
          } else if (this.selectedTab === 1) {
            ForEach(this.orders, (order: IncomeOrder, index: number) => {
              ListItem() { this.ReceivedOrder(order, index) }
            }, (order: IncomeOrder, index: number): string => this.orderKey(order, index))
            if (this.orders.length === 0) { ListItem() { StateView({ title: $r('app.string.income_no_orders') }) } }
            if (this.hasMore) {
              ListItem() {
                Button(this.loadingMore ? $r('app.string.loading') : this.moreFailed ? $r('app.string.retry') : $r('app.string.load_more'))
                  .enabled(!this.loadingMore).backgroundColor($r('app.color.surface')).fontColor($r('app.color.accent'))
                  .onClick((): void => { this.loadMore(); })
              }
            }
          } else if (this.selectedTab === 2) {
            ForEach(this.withdrawals, (item: IncomeWithdrawal, index: number) => {
              ListItem() { this.Withdrawal(item) }
            }, (item: IncomeWithdrawal, index: number): string => String(item.order_id ?? item.apply_time ?? '') + ':' + index)
            if (this.withdrawals.length === 0) { ListItem() { StateView({ title: $r('app.string.income_no_withdrawals') }) } }
          } else {
            ListItem() {
              Row({ space: 8 }) {
                this.StatsTypeButton('day', $r('app.string.income_stats_day'))
                this.StatsTypeButton('week', $r('app.string.income_stats_week'))
                this.StatsTypeButton('month', $r('app.string.income_stats_month'))
              }.width('100%').constraintSize({ maxWidth: this.dimension($r('app.float.income_content_max_width')) })
            }
            if (this.statsLoading || this.statsFailed) {
              ListItem() { StateView({ loading: this.statsLoading, error: this.statsFailed,
                onAction: (): void => { this.loadPeriodStats(); } }) }
            } else if (this.periodStats.length === 0) {
              ListItem() { StateView({ title: $r('app.string.income_stats_empty') }) }
            } else {
              ForEach(this.periodStats, (record: IncomeStatRecord, index: number) => {
                ListItem() { this.StatRow(record, index) }
              }, (record: IncomeStatRecord, index: number): string => record.date_str + ':' + index)
            }
          }
        }
      }.width('100%').height('100%').padding({ left: $r('app.float.income_page_padding'), right: $r('app.float.income_page_padding') })
        .alignListItem(ListItemAlign.Center).scrollBar(BarState.Off)
        .contentStartOffset(this.topInset + this.dimension($r('app.float.income_title_clearance')))
        .contentEndOffset(this.bottomInset + this.dimension($r('app.float.income_bottom_clearance')))
    }.titleBar({ avoidLayoutSafeArea: true, enableComponentSafeArea: false, style: navigationStyle(this.material),
      content: { title: { mainTitle: $r('app.string.income_title') }, menu: { maxCount: 1, value: [{
        content: {
          icon: $r('sys.symbol.card'),
          label: $r('app.string.income_restore_cards'),
          isEnabled: this.hiddenCards.length > 0,
          action: (): void => { this.restoreCards(); }
        }
      }] } } })
      .titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.canvas')).bindToScrollable([this.scroller])
  }
}
