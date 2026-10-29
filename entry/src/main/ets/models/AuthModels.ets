export class PasswordLoginPayload {
  account: string = '';
  password: string = '';
  mp_token: string = '';
  ar_ept: string = '';

  constructor(account: string, password: string, arEpt: string) {
    this.account = account;
    this.password = password;
    this.ar_ept = arEpt;
  }
}

export class QuickLoginPayload {
  account: string = '';
  code: string = '';
  mp_token: string = '';
  ar_ept: string = '';

  constructor(account: string, code: string, arEpt: string) {
    this.account = account;
    this.code = code;
    this.ar_ept = arEpt;
  }
}

export class SendCodePayload {
  account: string = '';
  captcha_code: string = '';
  ar_ept: string = '';

  constructor(account: string, captchaCode: string, arEpt: string) {
    this.account = account;
    this.captcha_code = captchaCode;
    this.ar_ept = arEpt;
  }
}

export class RegisterCodePayload {
  account: string = '';
  password: string = '';
  name: string = '';
  captcha_code: string = '';
  ar_ept: string = '';

  constructor(account: string, password: string, name: string, captchaCode: string, arEpt: string) {
    this.account = account;
    this.password = password;
    this.name = name;
    this.captcha_code = captchaCode;
    this.ar_ept = arEpt;
  }
}

export class RegisterPayload {
  account: string = '';
  password: string = '';
  name: string = '';
  code: string = '';
  mp_token: string = '';
  ar_ept: string = '';

  constructor(account: string, password: string, name: string, code: string, arEpt: string) {
    this.account = account;
    this.password = password;
    this.name = name;
    this.code = code;
    this.ar_ept = arEpt;
  }
}

export class ForgotCodePayload {
  account: string = '';
  ar_ept: string = '';

  constructor(account: string, arEpt: string) {
    this.account = account;
    this.ar_ept = arEpt;
  }
}

export class CheckForgotCodePayload {
  account: string = '';
  code: string = '';
  ar_ept: string = '';

  constructor(account: string, code: string, arEpt: string) {
    this.account = account;
    this.code = code;
    this.ar_ept = arEpt;
  }
}

export class ResetPasswordPayload {
  token: string = '';
  password: string = '';
  ar_ept: string = '';

  constructor(token: string, password: string, arEpt: string) {
    this.token = token;
    this.password = password;
    this.ar_ept = arEpt;
  }
}

export class ResetTokenData {
  token: string = '';
  reset_token: string = '';
}

export class SendCodeData {
  captcha_img: string = '';
}

export class SendCodeEnvelope {
  ec: number = 0;
  em: string = '';
  msg: string = '';
  message: string = '';
  data?: SendCodeData;
}

export class SendCodeResult {
  status: number = 0;
  sent: boolean = false;
  captchaImg: string = '';
  message: string = '';

  constructor(status: number, sent: boolean, captchaImg: string, message: string) {
    this.status = status;
    this.sent = sent;
    this.captchaImg = captchaImg;
    this.message = message;
  }
}

export class ApiEnvelopeInfo {
  ec?: number;
  em: string = '';
  msg: string = '';
  message: string = '';
  data?: Object;

  errorText(fallback: string): string {
    if (this.em.length > 0) { return this.em; }
    if (this.msg.length > 0) { return this.msg; }
    if (this.message.length > 0) { return this.message; }
    return fallback;
  }
}

export class SavedAccountRecord {
  userId: string = '';
  name: string = '';
  avatar: string = '';
  encryptedToken: string = '';
  lastUsedAt: number = 0;
}

export class SavedAccountSummary {
  userId: string = '';
  name: string = '';
  avatar: string = '';
  lastUsedAt: number = 0;
}
