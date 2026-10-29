// Contracts recovered from the service's dashboardIncome, myDashboard and withdraw bundles.
// Missing monetary values stay missing; never substitute a successful-looking zero balance.
export type IncomeValue = string | number;
export type IncomeFlag = string | number | boolean;

export class IncomeSummary {
  all_sum_amount?: IncomeValue;
  bill_amount?: IncomeValue;
  month_amount?: IncomeValue;
  next_month_amount?: IncomeValue;
  all_sponsor_count?: IncomeValue;
  month_sponsor_count?: IncomeValue;
  unconfirmed_amount?: IncomeValue;
  uv?: IncomeValue;
  pv?: IncomeValue;
}

export class IncomeFeeDetail {
  afd_fee?: IncomeValue;
  channel_fee?: IncomeValue;
}

export class IncomeBillAmount {
  sponsor_count?: IncomeValue;
  total_amount?: IncomeValue;
  creator_amount?: IncomeValue;
  create_time?: IncomeValue;
}

export class IncomeBillMonth {
  month?: IncomeValue;
  data?: IncomeBillAmount;
}

export class IncomeBillYear {
  year?: IncomeValue;
  data?: IncomeBillMonth[];
}

export class IncomeMonthlyResponse {
  monthly_bill?: IncomeBillYear[];
}

export class IncomeDashboard {
  summary?: IncomeSummary;
  balance?: IncomeValue;
  balance_after_tax?: IncomeValue;
  transfer_fee_detail?: IncomeFeeDetail;
}

export class IncomeStatRecord {
  date_str: string = '';
  uv?: IncomeValue;
  pv?: IncomeValue;
  paid_order_real_amount?: IncomeValue;
  paid_order_count?: IncomeValue;
  paid_user_count?: IncomeValue;
  paid_old_user_count?: IncomeValue;
}

export class IncomeStatResponse {
  list?: IncomeStatRecord[];
  has_more?: IncomeFlag;
}

export class IncomeUser {
  user_id?: string;
  name?: string;
  avatar?: string;
}

export class IncomePaidOrder {
  user_id?: string;
  user?: IncomeUser;
  total_amount?: IncomeValue;
  update_time?: IncomeValue;
  status?: IncomeFlag;
}

export class IncomePaidOrderPage {
  list?: IncomePaidOrder[];
  has_more?: IncomeFlag;
  last_order_id?: IncomeValue;
}

export class IncomePaidOrderAggregate {
  amount: number = 0;
  orderCount: number = 0;
  sponsorCount: number = 0;
}

export class IncomePlan {
  plan_id?: string;
  name?: string;
  price?: IncomeValue;
  independent?: IncomeFlag;
}

export class IncomeOrder {
  pay_success_sn?: IncomeValue;
  create_time?: IncomeValue;
  total_amount?: IncomeValue;
  month?: IncomeValue;
  remark?: string;
  is_upgrade?: IncomeFlag;
  py_type?: IncomeValue;
  user?: IncomeUser;
  plan?: IncomePlan;
}

export class IncomeOrderPage {
  list?: IncomeOrder[];
  has_more?: IncomeFlag;
}

export class IncomeWithdrawal {
  status?: IncomeValue;
  order_id?: IncomeValue;
  pay_amount?: IncomeValue;
  apply_time?: IncomeValue;
  deal_error?: string;
}

export class IncomeWithdrawalPage {
  list?: IncomeWithdrawal[];
}

export function incomeValueText(value: IncomeValue | undefined): string {
  if (value === undefined || value === null) { return ''; }
  if (typeof value !== 'string' && typeof value !== 'number') { return ''; }
  const text: string = String(value).trim();
  if (text.length === 0 || !Number.isFinite(Number(text))) { return ''; }
  return text;
}

export function incomeHasMore(value: IncomeFlag | undefined): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

export function incomeHasNoMore(value: IncomeFlag | undefined): boolean {
  return value === false || value === 0 || value === '0' || value === 'false';
}

export function incomeOrderCursor(order: IncomeOrder): string {
  const value: IncomeValue | undefined = order.pay_success_sn;
  if (typeof value !== 'string' && typeof value !== 'number') { return ''; }
  return String(value).trim();
}
