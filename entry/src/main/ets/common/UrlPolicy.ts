// Shared by ArkTS and the offline policy tests. Never accept suffix or substring host matches.
export const BASE_URL: string = 'https://ifdian.net';
export type AfdianRoutePreference = 'ifdian' | 'afdian' | 'www';
export const AFDIAN_ROUTE_DEFAULT: AfdianRoutePreference = 'ifdian';

export function afdianRouteHosts(preference: AfdianRoutePreference): string[] {
  if (preference === 'afdian') { return ['afdian.com', 'ifdian.net', 'www.afdian.com']; }
  if (preference === 'www') { return ['www.afdian.com', 'ifdian.net', 'afdian.com']; }
  return ['ifdian.net', 'afdian.com', 'www.afdian.com'];
}

export function afdianPreferredHost(preference: AfdianRoutePreference): string {
  return afdianRouteHosts(preference)[0];
}

export function afdianPreferredOrigin(preference: AfdianRoutePreference): string {
  return 'https://' + afdianPreferredHost(preference);
}

export function trustedSite(value: string): boolean {
  return /^https:\/\/(ifdian\.net|afdian\.com|afdian\.net)(\/|$)/i.test(value) &&
    !/[\u0000-\u0020\\]/.test(value);
}
export function paymentLink(value: string): boolean {
  return /^(weixin:\/\/wap\/pay\?|alipays:\/\/platformapi\/startapp\?)/i.test(value) &&
    !/[\u0000-\u001f]/.test(value);
}
export function paymentSite(value: string): boolean {
  return /^https:\/\/wx\.tenpay\.com\//i.test(value) && !/[\u0000-\u0020\\]/.test(value);
}
