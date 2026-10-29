import { IncomeBillMonth, IncomeBillYear, IncomeDashboard, IncomeMonthlyResponse, IncomeOrder, IncomeOrderPage,
  IncomePaidOrder, IncomePaidOrderPage, IncomeStatRecord, IncomeStatResponse, IncomeWithdrawal, IncomeWithdrawalPage,
  incomeHasMore, incomeHasNoMore, incomeOrderCursor, incomeValueText } from '../models/IncomeModels';
import { afdianApi } from './AfdianApi';
import { appStore } from './AppStore';

export class IncomeApi {
  private requireSession(): void {
    if (!appStore.isLoggedIn()) { throw new Error('Authentication required'); }
  }

  async dashboard(): Promise<IncomeDashboard> {
    this.requireSession();
    const data: IncomeDashboard = await afdianApi.request<IncomeDashboard>('/api/my/dashboard');
    if (data === null || typeof data !== 'object' || Array.isArray(data) ||
      (data.summary === undefined && data.balance_after_tax === undefined)) {
      throw new Error('Income dashboard data unavailable');
    }
    return data;
  }

  async monthlyBills(): Promise<IncomeBillYear[]> {
    this.requireSession();
    const data: IncomeMonthlyResponse = await afdianApi.request<IncomeMonthlyResponse>('/api/my/income');
    if (data === null || !Array.isArray(data.monthly_bill)) { throw new Error('Invalid monthly income response'); }
    const years: IncomeBillYear[] = data.monthly_bill;
    for (let y: number = 0; y < years.length; y++) {
      const year: IncomeBillYear = years[y];
      if (year === null || typeof year !== 'object' || !Array.isArray(year.data)) {
        throw new Error('Invalid monthly income year');
      }
      const months: IncomeBillMonth[] = year.data;
      for (let m: number = 0; m < months.length; m++) {
        const month: IncomeBillMonth = months[m];
        if (month === null || typeof month !== 'object' || month.data === undefined || month.data === null ||
          typeof month.data !== 'object') { throw new Error('Invalid monthly income bill'); }
      }
    }
    return years;
  }

  async receivedOrders(cursor: string = ''): Promise<IncomeOrderPage> {
    this.requireSession();
    // myDashboard.get_more_sponsor uses a pay_success_sn cursor, not a page number.
    const data: IncomeOrderPage = await afdianApi.request<IncomeOrderPage>(
      '/api/my/sponsored-bill?pay_success_sn=' + encodeURIComponent(cursor) + '&type=old');
    if (data === null || !Array.isArray(data.list) || data.has_more === undefined) {
      throw new Error('Invalid received income response');
    }
    const list: IncomeOrder[] = data.list;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i] === null || typeof list[i] !== 'object') { throw new Error('Invalid received income order'); }
    }
    if (incomeHasMore(data.has_more) && (list.length === 0 || incomeOrderCursor(list[list.length - 1]).length === 0 ||
      incomeOrderCursor(list[list.length - 1]) === cursor)) {
      throw new Error('Received income cursor did not advance');
    }
    return data;
  }

  async withdrawals(): Promise<IncomeWithdrawal[]> {
    this.requireSession();
    const data: IncomeWithdrawalPage = await afdianApi.request<IncomeWithdrawalPage>('/api/my/withdraw-history');
    if (data === null || !Array.isArray(data.list)) { throw new Error('Invalid withdrawal history response'); }
    const list: IncomeWithdrawal[] = data.list;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i] === null || typeof list[i] !== 'object') { throw new Error('Invalid withdrawal history item'); }
    }
    return list;
  }

  async stats(type: string, page: number = 1): Promise<IncomeStatResponse> {
    this.requireSession();
    const data: IncomeStatResponse = await afdianApi.request<IncomeStatResponse>(
      '/api/my/stat?page=' + page + '&type=' + encodeURIComponent(type));
    if (data === null || !Array.isArray(data.list)) { throw new Error('Invalid income stats response'); }
    return data;
  }

  async paidOrders(beginTime: number, endTime: number): Promise<IncomePaidOrder[]> {
    this.requireSession();
    const records: IncomePaidOrder[] = [];
    let page: number = 1;
    let lastOrderId: string = '';
    while (page <= 30) {
      let path: string = '/api/my/sponsored-bill-filter?page=' + page +
        '&sort_field=update_time&sort_value=desc&status=2' +
        '&begin_time=' + Math.floor(beginTime) + '&end_time=' + Math.max(Math.floor(beginTime), Math.floor(endTime) - 1);
      if (lastOrderId.length > 0) { path += '&last_order_id=' + encodeURIComponent(lastOrderId); }
      const data: IncomePaidOrderPage = await afdianApi.request<IncomePaidOrderPage>(path);
      if (data === null || !Array.isArray(data.list)) { throw new Error('Invalid paid order response'); }
      const list: IncomePaidOrder[] = data.list;
      for (let i: number = 0; i < list.length; i++) {
        if (list[i] !== null && typeof list[i] === 'object') { records.push(list[i]); }
      }
      const nextCursor: string = incomeValueText(data.last_order_id);
      if (!incomeHasMore(data.has_more) || incomeHasNoMore(data.has_more) || list.length === 0 ||
        nextCursor.length === 0 || nextCursor === lastOrderId) {
        break;
      }
      lastOrderId = nextCursor;
      page++;
    }
    return records;
  }

  async recentDailyStats(requiredDays: number = 45): Promise<IncomeStatRecord[]> {
    const records: IncomeStatRecord[] = [];
    let page: number = 1;
    while (page <= 5 && records.length < requiredDays) {
      const data: IncomeStatResponse = await this.stats('day', page);
      const list: IncomeStatRecord[] = data.list ?? [];
      if (list.length === 0) { break; }
      for (let i: number = 0; i < list.length; i++) {
        const record: IncomeStatRecord = list[i];
        if (record.date_str.length > 0 &&
          !records.some((existing: IncomeStatRecord): boolean => existing.date_str === record.date_str)) {
          records.push(record);
        }
      }
      if (incomeHasNoMore(data.has_more)) { break; }
      page++;
    }
    return records;
  }
}

export const incomeApi: IncomeApi = new IncomeApi();
