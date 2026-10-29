import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { webview } from '@kit.ArkWeb';
import { User } from '../models/Models';
import { AfdianRoutePreference, AFDIAN_ROUTE_DEFAULT } from '../common/UrlPolicy';
import { SecureTokenCipher } from './SecureTokenCipher';
import { SavedAccountRecord, SavedAccountSummary } from '../models/AuthModels';

export class AppStore {
  private context: common.UIAbilityContext | undefined = undefined;
  private store: preferences.Preferences | undefined = undefined;
  private cipher: SecureTokenCipher = new SecureTokenCipher();
  private token: string = '';
  private legacyToken: string = '';
  private route: AfdianRoutePreference = AFDIAN_ROUTE_DEFAULT;
  private current: User = new User();
  init(context: common.UIAbilityContext): void {
    this.context = context;
    this.store = preferences.getPreferencesSync(context, { name: 'aifadian_private' });
    this.legacyToken = this.store.getSync('auth_token', '') as string;
    this.token = this.legacyToken;
    this.route = this.normalizeRoute(this.store.getSync('route', AFDIAN_ROUTE_DEFAULT) as string);
    try { this.current = JSON.parse(this.store.getSync('user', '{}') as string) as User; } catch (error) { this.current = new User(); }
    AppStorage.setOrCreate<string>('afd.theme', this.store.getSync('theme', 'system') as string);
    AppStorage.setOrCreate<boolean>('afd.material', this.store.getSync('material', true) as boolean);
    this.publish();
    this.applyTheme();
  }
  async restoreSession(): Promise<void> {
    if (!this.store) { return; }
    if (this.legacyToken.length > 0) {
      try {
        const migratedToken: string = this.legacyToken;
        const encrypted: string = await this.cipher.encrypt(migratedToken);
        this.store.putSync('auth_token_secure', encrypted);
        this.store.deleteSync('auth_token');
        this.store.flushSync();
        this.legacyToken = '';
        this.token = migratedToken;
      } catch (error) {
        // Keep the legacy token readable if migration fails; never destroy a valid session.
        this.token = this.legacyToken;
      }
      this.publish();
      await this.syncWebCookies();
      return;
    }
    const encrypted: string = this.store.getSync('auth_token_secure', '') as string;
    if (encrypted.length === 0) {
      this.token = '';
      this.publish();
      return;
    }
    try {
      this.token = await this.cipher.decrypt(encrypted);
    } catch (error) {
      this.token = '';
      this.store.deleteSync('auth_token_secure');
      this.store.flushSync();
    }
    this.publish();
    await this.syncWebCookies();
  }
  getToken(): string { return this.token; }
  getUser(): User { return this.current; }
  isLoggedIn(): boolean { return this.token.length > 0; }
  getRoute(): AfdianRoutePreference { return this.route; }
  async saveSession(token: string): Promise<void> {
    if (!/^[A-Za-z0-9_\-.~+/=]+$/.test(token)) { throw new Error('Invalid session'); }
    this.token = token;
    const encrypted: string = await this.cipher.encrypt(token);
    this.store?.putSync('auth_token_secure', encrypted);
    this.store?.deleteSync('auth_token');
    this.store?.flushSync();
    this.publish();
    await this.syncWebCookies();
  }
  saveUser(user: User, publishRevision: boolean = true): void {
    this.current = user;
    this.store?.putSync('user', JSON.stringify(user));
    this.store?.flushSync();
    this.publish(publishRevision);
    this.rememberCurrentAccount(user);
  }
  savedAccounts(): SavedAccountSummary[] {
    const records: SavedAccountRecord[] = this.readAccounts();
    records.sort((left: SavedAccountRecord, right: SavedAccountRecord): number => right.lastUsedAt - left.lastUsedAt);
    const result: SavedAccountSummary[] = [];
    for (let i: number = 0; i < records.length; i++) {
      const summary: SavedAccountSummary = new SavedAccountSummary();
      summary.userId = records[i].userId;
      summary.name = records[i].name;
      summary.avatar = records[i].avatar;
      summary.lastUsedAt = records[i].lastUsedAt;
      result.push(summary);
    }
    return result;
  }
  async activateSavedAccount(userId: string): Promise<void> {
    const records: SavedAccountRecord[] = this.readAccounts();
    for (let i: number = 0; i < records.length; i++) {
      if (records[i].userId === userId) {
        const token: string = await this.cipher.decrypt(records[i].encryptedToken);
        if (!/^[A-Za-z0-9_\-.~+/=]+$/.test(token)) { throw new Error('Invalid saved session'); }
        this.token = token;
        this.publish();
        return;
      }
    }
    throw new Error('Saved account not found');
  }
  async commitActiveAccount(): Promise<void> {
    if (!this.isLoggedIn()) { throw new Error('Authentication required'); }
    const encrypted: string = await this.cipher.encrypt(this.token);
    this.store?.putSync('auth_token_secure', encrypted);
    this.store?.flushSync();
    await this.rememberCurrentAccount(this.current);
    await this.syncWebCookies();
  }
  async syncWebCookies(): Promise<void> {
    if (!this.isLoggedIn()) { return; }
    // Only these exact service origins receive the token. No per-navigation cookie injection.
    await webview.WebCookieManager.configCookie('https://ifdian.net', 'auth_token=' + this.token + '; Path=/; Secure; HttpOnly; SameSite=Lax', false, true);
    await webview.WebCookieManager.configCookie('https://afdian.com', 'auth_token=' + this.token + '; Path=/; Secure; HttpOnly; SameSite=Lax', false, true);
    await webview.WebCookieManager.configCookie('https://www.afdian.com', 'auth_token=' + this.token + '; Path=/; Secure; HttpOnly; SameSite=Lax', false, true);
  }
  async importWebSession(): Promise<boolean> {
    const preferredOrigin: string = this.route === 'afdian' ? 'https://afdian.com' :
      this.route === 'www' ? 'https://www.afdian.com' : 'https://ifdian.net';
    const cookies: string = await webview.WebCookieManager.fetchCookie(preferredOrigin);
    const pair: string | undefined = cookies.split(';').map((part: string): string => part.trim()).find((part: string): boolean => part.startsWith('auth_token='));
    const token: string = pair === undefined ? '' : pair.substring('auth_token='.length);
    if (token.length === 0) { return false; }
    await this.saveSession(token);
    return true;
  }
  async clearSession(): Promise<void> {
    const previousUserId: string = this.current.user_id;
    if (previousUserId.length > 0) { this.removeAccount(previousUserId); }
    this.token = '';
    this.current = new User();
    this.store?.deleteSync('auth_token');
    this.store?.deleteSync('auth_token_secure');
    this.store?.deleteSync('user');
    this.store?.flushSync();
    this.publish();
    await webview.WebCookieManager.clearAllCookies();
  }
  setRoute(route: AfdianRoutePreference): void {
    this.route = route;
    AppStorage.setOrCreate<string>('afd.route', route);
    this.store?.putSync('route', route);
    this.store?.flushSync();
  }
  setTheme(theme: string): void {
    AppStorage.setOrCreate<string>('afd.theme', theme);
    this.store?.putSync('theme', theme); this.store?.flushSync(); this.applyTheme();
  }
  setMaterial(enabled: boolean): void {
    AppStorage.setOrCreate<boolean>('afd.material', enabled);
    this.store?.putSync('material', enabled); this.store?.flushSync();
  }
  loadIncomeHiddenCards(): string[] {
    if (!this.store) { return []; }
    const key: string = 'income_hidden_cards_' + this.current.user_id;
    const raw: string = this.store.getSync(key, '[]') as string;
    try {
      const parsed: string[] = JSON.parse(raw) as string[];
      if (!Array.isArray(parsed)) { return []; }
      return parsed.filter((value: string): boolean => typeof value === 'string' && value.length > 0);
    } catch (error) {
      return [];
    }
  }
  saveIncomeHiddenCards(value: string[]): void {
    if (!this.store) { return; }
    this.store.putSync('income_hidden_cards_' + this.current.user_id, JSON.stringify(value));
    this.store.flushSync();
  }
  private applyTheme(): void {
    const theme: string = AppStorage.get<string>('afd.theme') ?? 'system';
    this.context?.getApplicationContext().setColorMode(theme === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
      theme === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  }
  private publish(publishRevision: boolean = true): void {
    AppStorage.setOrCreate<boolean>('afd.loggedIn', this.isLoggedIn());
    AppStorage.setOrCreate<string>('afd.route', this.route);
    if (publishRevision) {
      AppStorage.setOrCreate<number>('afd.sessionRevision', (AppStorage.get<number>('afd.sessionRevision') ?? 0) + 1);
    }
  }
  private normalizeRoute(value: string): AfdianRoutePreference {
    if (value === 'afdian') { return 'afdian'; }
    if (value === 'www') { return 'www'; }
    return 'ifdian';
  }
  private async rememberCurrentAccount(user: User): Promise<void> {
    if (!this.isLoggedIn() || user.user_id.length === 0) { return; }
    const token: string = this.token;
    try {
      const encrypted: string = await this.cipher.encrypt(token);
      if (!this.isLoggedIn() || this.token !== token) { return; }
      const records: SavedAccountRecord[] = this.readAccounts();
      const next: SavedAccountRecord[] = [];
      for (let i: number = 0; i < records.length; i++) {
        if (records[i].userId !== user.user_id) { next.push(records[i]); }
      }
      const record: SavedAccountRecord = new SavedAccountRecord();
      record.userId = user.user_id;
      record.name = user.name;
      record.avatar = user.avatar;
      record.encryptedToken = encrypted;
      record.lastUsedAt = Date.now();
      next.unshift(record);
      while (next.length > 8) { next.pop(); }
      this.store?.putSync('saved_accounts', JSON.stringify(next));
      this.store?.flushSync();
    } catch (error) {}
  }
  private removeAccount(userId: string): void {
    const records: SavedAccountRecord[] = this.readAccounts();
    const remaining: SavedAccountRecord[] = records.filter((record: SavedAccountRecord): boolean =>
      record.userId !== userId);
    this.store?.putSync('saved_accounts', JSON.stringify(remaining));
    this.store?.flushSync();
  }
  private readAccounts(): SavedAccountRecord[] {
    const raw: string = this.store?.getSync('saved_accounts', '[]') as string ?? '[]';
    try {
      const parsed: SavedAccountRecord[] = JSON.parse(raw) as SavedAccountRecord[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      return [];
    }
  }
}
export const appStore: AppStore = new AppStore();
