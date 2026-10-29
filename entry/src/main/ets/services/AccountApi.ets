import { FormField, User } from '../models/Models';
import { AccountData, PasswordChangeResult } from '../models/SponsoringModels';
import { afdianApi } from './AfdianApi';
import { appStore } from './AppStore';

export class BasicProfileFields {
  avatar: string = '';
  name: string = '';
  addrName: string = '';
  addrPhone: string = '';
  addrAddress: string = '';
  gender: string = '0';
  birthday: string = '';

  fields(): FormField[] {
    return [
      new FormField('avatar', this.avatar),
      new FormField('name', this.name),
      new FormField('addr_name', this.addrName),
      new FormField('addr_phone', this.addrPhone),
      new FormField('addr_address', this.addrAddress),
      new FormField('gender', this.gender),
      new FormField('birthday', this.birthday)
    ];
  }
}

export class CreatorBasicFields {
  name: string = '';
  avatar: string = '';
  urlSlug: string = '';
  categoryId: string = '';
  type: string = '0';
  doing: string = '';
  detail: string = '';
  pic: string = '';
  cover: string = '';
  watermark: string = '0';

  fields(): FormField[] {
    return [
      new FormField('name', this.name),
      new FormField('avatar', this.avatar),
      new FormField('url_slug', this.urlSlug),
      new FormField('category_id', this.categoryId),
      new FormField('type', this.type),
      new FormField('doing', this.doing),
      new FormField('detail', this.detail),
      new FormField('pic', this.pic),
      new FormField('cover', this.cover),
      new FormField('watermark', this.watermark)
    ];
  }
}

export class AccountApi {
  private requireSession(): void {
    if (!appStore.isLoggedIn()) { throw new Error('Authentication required'); }
  }

  account(): Promise<AccountData> {
    this.requireSession();
    return afdianApi.request<AccountData>('/api/my/account');
  }

  saveBasic(profile: BasicProfileFields): Promise<Object> {
    this.requireSession();
    return afdianApi.request<Object>('/api/my/edit-basic', profile.fields());
  }

  sendVerifyCode(account: string): Promise<Object> {
    this.requireSession();
    return afdianApi.request<Object>('/api/account/send-verify-code',
      [new FormField('account', account)], ['account']);
  }

  bind(account: string, code: string): Promise<Object> {
    this.requireSession();
    return afdianApi.request<Object>('/api/account/bind',
      [new FormField('account', account), new FormField('code', code)], ['account', 'code']);
  }

  changePassword(oldPassword: string, newPassword: string): Promise<PasswordChangeResult> {
    this.requireSession();
    return afdianApi.request<PasswordChangeResult>('/api/account/change-password',
      [new FormField('old_password', oldPassword), new FormField('new_password', newPassword)],
      ['old_password', 'new_password']);
  }
  async unbind(kind: string): Promise<void> {
    this.requireSession();
    let path: string = '';
    if (kind === 'wechat') { path = '/api/account/unbind-wechat'; }
    else if (kind === 'qq') { path = '/api/account/unbind-qq'; }
    else if (kind === 'google') { path = '/api/account/unbind-google'; }
    else { throw new Error('Unsupported account binding'); }
    await afdianApi.requestVoid(path);
  }
  saveCreatorBasic(user: User, doing: string, detail: string, cover: string): Promise<Object> {
    this.requireSession();
    const fields: CreatorBasicFields = new CreatorBasicFields();
    fields.name = user.name;
    fields.avatar = user.avatar;
    fields.urlSlug = user.url_slug;
    fields.categoryId = user.creator?.category?.category_id ?? '';
    fields.type = (user.creator?.type ?? 0).toString();
    fields.doing = doing;
    fields.detail = detail;
    fields.pic = user.creator?.pic ?? '';
    fields.cover = cover;
    fields.watermark = (user.creator?.watermark ?? 0).toString();
    return afdianApi.request<Object>('/api/creator/edit-basic', fields.fields());
  }
  saveCreatorPrivacy(kind: string, enabled: boolean): Promise<Object> {
    this.requireSession();
    const path: string = kind === 'income' ? '/api/creator/privacy-public-income' :
      '/api/creator/privacy-public-sponsor';
    return afdianApi.request<Object>(path, [new FormField('status', enabled ? '1' : '0')]);
  }
}

export const accountApi: AccountApi = new AccountApi();
