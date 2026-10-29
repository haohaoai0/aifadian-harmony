import { http } from '@kit.NetworkKit';
import { ApiResponse, CategoryPage, CreatorPage, CreatorPlansPage, FormField, LoginData, MessagePage, PostDetail, PostPage, TopSponsorPage, UserProfile } from '../models/Models';
import { ApiCipher } from './ApiCipher';
import { CheckForgotCodePayload, ForgotCodePayload, PasswordLoginPayload, QuickLoginPayload, RegisterCodePayload,
  RegisterPayload, ResetPasswordPayload, ResetTokenData, SendCodeEnvelope, SendCodePayload, SendCodeResult } from '../models/AuthModels';
import { AfdianHttpResult, afdianHttp } from './AfdianHttp';

export class AfdianApi {
  async request<T>(path: string, fields: FormField[] = [], encrypted: string[] = []): Promise<T> {
    const bodyFields: FormField[] = await ApiCipher.encode(fields, encrypted);
    const body: string = bodyFields.map((item: FormField): string =>
      encodeURIComponent(item.name) + '=' + encodeURIComponent(item.value)).join('&');
    const method: http.RequestMethod = bodyFields.length > 0 ? http.RequestMethod.POST : http.RequestMethod.GET;
    const result: AfdianHttpResult = await afdianHttp.execute(path, method, body,
      'application/x-www-form-urlencoded');
    afdianHttp.validate(result.status, result.body, 'Service unavailable', true);
    const envelope: ApiResponse<T> = JSON.parse(this.protectLargeIds(result.body)) as ApiResponse<T>;
    return envelope.data as T;
  }
  async requestJson<T>(path: string, payload: Object, fallback: string): Promise<T> {
    const result: AfdianHttpResult = await afdianHttp.execute(path, http.RequestMethod.POST,
      JSON.stringify(payload), 'application/json');
    afdianHttp.validate(result.status, result.body, fallback, true);
    const envelope: ApiResponse<T> = JSON.parse(this.protectLargeIds(result.body)) as ApiResponse<T>;
    if (envelope.data === undefined) { throw new Error(fallback); }
    return envelope.data;
  }
  async requestVoid(path: string, fields: FormField[] = []): Promise<void> {
    const body: string = fields.map((item: FormField): string =>
      encodeURIComponent(item.name) + '=' + encodeURIComponent(item.value)).join('&');
    const result: AfdianHttpResult = await afdianHttp.execute(path,
      fields.length > 0 ? http.RequestMethod.POST : http.RequestMethod.GET, body,
      'application/x-www-form-urlencoded');
    afdianHttp.validate(result.status, result.body, 'Service unavailable', false);
  }
  async requestJsonVoid(path: string, payload: Object, fallback: string): Promise<void> {
    const result: AfdianHttpResult = await afdianHttp.execute(path, http.RequestMethod.POST,
      JSON.stringify(payload), 'application/json');
    afdianHttp.validate(result.status, result.body, fallback, false);
  }
  async requestText(path: string): Promise<string> {
    const result: AfdianHttpResult = await afdianHttp.execute(path, http.RequestMethod.GET);
    afdianHttp.validate(result.status, result.body, 'Service unavailable', true);
    return result.body;
  }
  feed(cursor: string = '', following: boolean = false): Promise<PostPage> {
    return this.request<PostPage>((following ? '/api/post/get-my-rec-list' : '/api/post/get-rec-list') +
      '?type=old&publish_sn=' + encodeURIComponent(cursor) + '&all=');
  }
  creators(page: number, type: string, category: string): Promise<CreatorPage> {
    return this.request<CreatorPage>('/api/creator/list?page=' + page + '&type=' + type + '&category_id=' + encodeURIComponent(category));
  }
  categories(): Promise<CategoryPage> { return this.request<CategoryPage>('/api/category/list'); }
  topSponsors(userId: string): Promise<TopSponsorPage> {
    return this.request<TopSponsorPage>('/api/creator/get-top-sponsors?user_id=' + encodeURIComponent(userId));
  }
  creatorPlans(userId: string): Promise<CreatorPlansPage> {
    return this.request<CreatorPlansPage>('/api/creator/get-plans?user_id=' + encodeURIComponent(userId) +
      '&album_id=&unlock_plan_ids=&diy=&affiliate_code=');
  }
  profile(userId: string): Promise<UserProfile> { return this.request<UserProfile>('/api/user/get-profile?user_id=' + encodeURIComponent(userId)); }
  myProfile(): Promise<UserProfile> { return this.request<UserProfile>('/api/my/profile'); }
  posts(userId: string, cursor: string = ''): Promise<PostPage> {
    return this.request<PostPage>('/api/post/get-list?type=old&per_page=10&user_id=' +
      encodeURIComponent(userId) + '&publish_sn=' + encodeURIComponent(cursor));
  }
  detail(postId: string): Promise<PostDetail> { return this.request<PostDetail>('/api/post/get-detail?post_id=' + encodeURIComponent(postId)); }
  messages(page: number): Promise<MessagePage> { return this.request<MessagePage>('/api/message/dialogs?page=' + page); }
  like(postId: string, liked: boolean): Promise<Object> {
    return this.request<Object>(liked ? '/api/post/unlike' : '/api/post/like', [new FormField('post_id', postId)]);
  }
  async login(account: string, password: string): Promise<LoginData> {
    const payload: PasswordLoginPayload = await ApiCipher.passwordPayload(account, password);
    const data: LoginData = await this.requestJson<LoginData>('/api/passport/login', payload,
      '登录失败，请检查账号或密码');
    return data;
  }
  async sendCode(account: string, captchaCode: string = ''): Promise<SendCodeResult> {
    const payload: SendCodePayload = await ApiCipher.sendCodePayload(account, captchaCode);
    return this.sendEncryptedJson('/api/passport/send-ql-code', payload);
  }
  async sendRegisterCode(account: string, password: string, name: string,
    captchaCode: string = ''): Promise<SendCodeResult> {
    const payload: RegisterCodePayload = await ApiCipher.registerCodePayload(account, password, name, captchaCode);
    return this.sendEncryptedJson('/api/passport/send-verify-code', payload);
  }
  async register(account: string, password: string, name: string, code: string): Promise<LoginData> {
    const payload: RegisterPayload = await ApiCipher.registerPayload(account, password, name, code);
    return this.requestJson<LoginData>('/api/passport/register', payload, '注册失败');
  }
  async sendForgotCode(account: string): Promise<SendCodeResult> {
    const payload: ForgotCodePayload = await ApiCipher.forgotCodePayload(account);
    return this.sendEncryptedJson('/api/passport/send-forget-code', payload);
  }
  async checkForgotCode(account: string, code: string): Promise<ResetTokenData> {
    const payload: CheckForgotCodePayload = await ApiCipher.checkForgotCodePayload(account, code);
    return this.requestJson<ResetTokenData>('/api/passport/check-forget-code', payload, '验证码校验失败');
  }
  async resetPassword(token: string, password: string): Promise<Object> {
    const payload: ResetPasswordPayload = await ApiCipher.resetPasswordPayload(token, password);
    await this.requestJsonVoid('/api/passport/reset-password', payload, '密码重置失败');
    return new Object();
  }
  private async sendEncryptedJson(path: string, payload: Object): Promise<SendCodeResult> {
    const result: AfdianHttpResult = await afdianHttp.execute(path,
      http.RequestMethod.POST, JSON.stringify(payload), 'application/json');
    if (result.status < 200 || result.status >= 300) { throw new Error('HTTP ' + result.status); }
    const envelope: SendCodeEnvelope = JSON.parse(result.body) as SendCodeEnvelope;
    if (envelope.ec === 200) {
      return new SendCodeResult(result.status, true, '', '');
    }
    if (envelope.ec === 201) {
      const captcha: string = envelope.data?.captcha_img ?? '';
      return new SendCodeResult(result.status, false, captcha,
        envelope.em || envelope.msg || envelope.message);
    }
    throw new Error(envelope.em || envelope.msg || envelope.message || '验证码发送失败');
  }
  private protectLargeIds(body: string): string {
    return body.replace(/("(?:publish_sn|pay_success_sn)"\s*:\s*)(-?\d{10,})/g, '$1"$2"');
  }
  async quickLogin(account: string, code: string): Promise<LoginData> {
    const payload: QuickLoginPayload = await ApiCipher.quickLoginPayload(account, code);
    const data: LoginData = await this.requestJson<LoginData>('/api/passport/quick-login', payload,
      '验证码登录失败');
    return data;
  }
}
export const afdianApi: AfdianApi = new AfdianApi();
