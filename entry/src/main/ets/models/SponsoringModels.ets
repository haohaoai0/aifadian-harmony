import { User } from './Models';

export class SponsoringPlan {
  name: string = '';
  show_price: string = '';
  show_price_after_adjust: string = '';
  pay_month: string = '';
  permanent: boolean = false;
  independent: boolean = false;
}

export class SponsoringAgreement {
  amount: string = '';
  next_execute_time: string = '';
  external_agreement_no: string = '';
}

export class SponsoringDetail {
  user?: User;
  plan: SponsoringPlan = new SponsoringPlan();
  agreement?: SponsoringAgreement;
  expire_time: string = '';
  show_amount: string = '';
}

export class SponsoringOutDetail {
  list: SponsoringDetail[] = [];
}

export class SponsoringInfo {
  out_detail?: SponsoringOutDetail;
}

export class SponsoringSku {
  name: string = '';
  count: string = '';
}

export class SponsoringSale {
  plan: SponsoringPlan = new SponsoringPlan();
  sku_processed: SponsoringSku[] = [];
  out_trade_no: string = '';
  sign_status: string = '';
}

export class SponsoringItem {
  user: User = new User();
  sponsor_info?: SponsoringInfo;
  agreements: SponsoringAgreement[] = [];
  sale_list: SponsoringSale[] = [];
  expire_time: string = '';
  show_amount: string = '';
}

export class SponsoringResponse {
  sponsoring: SponsoringItem[] = [];
  sponsoring_expired: SponsoringItem[] = [];
}

export class AccountLogin {
  email: string = '';
  phone: string = '';
}

export class AccountOAuthEntry {
  nickname: string = '';
}

export class AccountOAuth {
  wect?: AccountOAuthEntry;
  qq?: AccountOAuthEntry;
  google?: AccountOAuthEntry;
}

export class AccountData {
  login: AccountLogin = new AccountLogin();
  oauth?: AccountOAuth;
  user_private_id: string = '';
}

export class PasswordChangeResult {
  auth_token: string = '';
}
