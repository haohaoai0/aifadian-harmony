import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AfdianRoutePreference, afdianRouteHosts } from '../common/UrlPolicy';
import { ApiEnvelopeInfo } from '../models/AuthModels';
import { appStore } from './AppStore';

export class AfdianHttpResult {
  status: number = 0;
  body: string = '';
  origin: string = '';

  constructor(status: number, body: string, origin: string) {
    this.status = status;
    this.body = body;
    this.origin = origin;
  }
}

export class AfdianHttp {
  async execute(path: string, method: http.RequestMethod, body: string = '',
    contentType: string = ''): Promise<AfdianHttpResult> {
    if (!path.startsWith('/api/')) { throw new Error('Invalid API path'); }
    const preference: AfdianRoutePreference = appStore.getRoute();
    const hosts: string[] = afdianRouteHosts(preference);
    const idempotent: boolean = method === http.RequestMethod.GET;
    const client: http.HttpRequest = http.createHttp();
    try {
      for (let index: number = 0; index < hosts.length; index++) {
        const host: string = hosts[index];
        const origin: string = 'https://' + host;
        const headers: Record<string, string> = {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 HarmonyOS/afdian/0.2.0/api',
          'Referer': origin,
          'Origin': origin
        };
        if (contentType.length > 0) { headers['Content-Type'] = contentType; }
        if (appStore.isLoggedIn()) { headers.Cookie = 'auth_token=' + appStore.getToken(); }
        const urlPath: string = this.withToken(path);
        const options: http.HttpRequestOptions = {
          method: method,
          header: headers,
          expectDataType: http.HttpDataType.STRING,
          usingCache: false,
          connectTimeout: 15000,
          readTimeout: 22000
        };
        if (body.length > 0) { options.extraData = body; }
        try {
          const response: http.HttpResponse = await client.request(origin + urlPath, options);
          const status: number = response.responseCode;
          if (status < 200 || status >= 300) {
            hilog.warn(0xFF00, 'AfdianHttp', '%{public}s HTTP %{public}d', path.split('?')[0], status);
          }
          if (!idempotent || !this.isDomainFailure(status) || index === hosts.length - 1) {
            return new AfdianHttpResult(status,
              typeof response.result === 'string' ? response.result as string : '', origin);
          }
        } catch (error) {
          const businessError: BusinessError = error as BusinessError;
          hilog.warn(0xFF00, 'AfdianHttp', '%{public}s network failure code=%{public}d',
            path.split('?')[0], businessError.code);
          const canSwitch: boolean = idempotent || this.connectionNotEstablished(error);
          if (!canSwitch || index === hosts.length - 1) {
            throw new Error((error as Error).message || 'Network request failed');
          }
        }
      }
      throw new Error('No API route available');
    } finally {
      client.destroy();
    }
  }

  validate(status: number, body: string, fallback: string, requireData: boolean): void {
    if (status < 200 || status >= 300) { throw new Error('HTTP ' + status); }
    let envelope: ApiEnvelopeInfo;
    try {
      envelope = JSON.parse(body) as ApiEnvelopeInfo;
    } catch (error) {
      throw new Error(fallback + '（响应结构异常）');
    }
    if (envelope.ec !== undefined && envelope.ec !== 200) {
      throw new Error(envelope.errorText(fallback));
    }
    if (requireData && envelope.data === undefined) { throw new Error(fallback + '（响应结构异常）'); }
  }

  private withToken(path: string): string {
    if (!appStore.isLoggedIn()) { return path; }
    const separator: string = path.includes('?') ? '&' : '?';
    return path + separator + 'auth_token=' + encodeURIComponent(appStore.getToken());
  }

  private isDomainFailure(status: number): boolean {
    return status === 404 || status === 405 || status === 408 || status === 421 ||
      status === 500 || status === 502 || status === 503 || status === 504;
  }

  private connectionNotEstablished(error: Object): boolean {
    const businessError: BusinessError = error as BusinessError;
    // curl 6 = DNS failed, curl 7 = connect failed. Any request body was not delivered.
    return businessError.code === 2300006 || businessError.code === 2300007;
  }
}

export const afdianHttp: AfdianHttp = new AfdianHttp();
