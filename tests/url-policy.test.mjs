import test from 'node:test';
import assert from 'node:assert/strict';
import { trustedSite, paymentLink, paymentSite } from '../entry/src/main/ets/common/UrlPolicy.ts';

for (const url of ['https://ifdian.net', 'https://ifdian.net/feed', 'https://afdian.com/u/1', 'https://afdian.net/p/2', 'https://AFDIAN.COM/login']) {
  test('accept service origin: ' + url, () => assert.equal(trustedSite(url), true));
}
for (const url of ['http://ifdian.net/feed', 'https://ifdian.net.evil.test/', 'https://evil.test/afdian.com',
  'https://ifdian.net@evil.test/', 'https://evil.test@ifdian.net/', 'https://sub.ifdian.net/',
  'https://ifdian.net:443/', 'https://ifdian.net\\@evil.test/', 'https://ifdian.net/\r\nCookie:x',
  'javascript:alert(1)', 'file:///data/storage', 'data:text/html,x']) {
  test('reject untrusted origin: ' + JSON.stringify(url), () => assert.equal(trustedSite(url), false));
}
test('only exact payment HTTPS origin', () => {
  assert.equal(paymentSite('https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb?x=1'), true);
  assert.equal(paymentSite('https://wx.tenpay.com.evil.test/'), false);
  assert.equal(paymentSite('http://wx.tenpay.com/'), false);
  assert.equal(trustedSite('https://wx.tenpay.com/'), false);
});
test('payment intents require known schemes and targets', () => {
  assert.equal(paymentLink('weixin://wap/pay?prepayid=x'), true);
  assert.equal(paymentLink('alipays://platformapi/startapp?appId=20000125'), true);
  assert.equal(paymentLink('weixin://evil/path'), false);
  assert.equal(paymentLink('intent://arbitrary'), false);
  assert.equal(paymentLink('alipays://platformapi/startapp?x=1\n'), false);
});
