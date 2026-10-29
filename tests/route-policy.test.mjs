import test from 'node:test';
import assert from 'node:assert/strict';
import { AFDIAN_ROUTE_DEFAULT, afdianPreferredHost, afdianPreferredOrigin, afdianRouteHosts } from '../entry/src/main/ets/common/UrlPolicy.ts';

test('default route prefers ifdian.net', () => {
  assert.equal(AFDIAN_ROUTE_DEFAULT, 'ifdian');
  assert.equal(afdianPreferredHost(AFDIAN_ROUTE_DEFAULT), 'ifdian.net');
  assert.equal(afdianPreferredOrigin(AFDIAN_ROUTE_DEFAULT), 'https://ifdian.net');
});

test('each preference carries a complete three-host fallback chain', () => {
  assert.deepEqual(afdianRouteHosts('ifdian'), ['ifdian.net', 'afdian.com', 'www.afdian.com']);
  assert.deepEqual(afdianRouteHosts('afdian'), ['afdian.com', 'ifdian.net', 'www.afdian.com']);
  assert.deepEqual(afdianRouteHosts('www'), ['www.afdian.com', 'ifdian.net', 'afdian.com']);
});

test('fallback chains contain only exact official hosts and no duplicates', () => {
  for (const preference of ['ifdian', 'afdian', 'www']) {
    const chain = afdianRouteHosts(preference);
    assert.equal(chain.length, 3);
    assert.equal(new Set(chain).size, chain.length);
    assert.ok(chain.every(host => ['ifdian.net', 'afdian.com', 'www.afdian.com'].includes(host)));
  }
});
