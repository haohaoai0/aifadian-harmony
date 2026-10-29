import test from 'node:test';
import assert from 'node:assert/strict';
import { MessageEntry, mergeMessages } from '../entry/src/main/ets/models/MessageModels.ts';

function row(id, text = id) {
  const value = new MessageEntry();
  value.message.msg_id = id;
  value.message.content = text;
  return value;
}
const ids = rows => rows.map(value => value.message.msg_id);

test('overlapping poll updates the receipt without duplicating the sent message', () => {
  const current = [row('a'), row('b', 'receipt')];
  const merged = mergeMessages(current, [row('b', 'confirmed'), row('c')]);
  assert.deepEqual(ids(merged), ['a', 'b', 'c']);
  assert.equal(merged[1].message.content, 'confirmed');
  assert.equal(current[1].message.content, 'receipt');
});
test('history prepends overlapping pages and preserves chronological server order', () => {
  assert.deepEqual(ids(mergeMessages([row('b'), row('c')], [row('a'), row('b')], true)), ['a', 'b', 'c']);
});
test('opaque message IDs retain precision and are not sorted lexically', () => {
  const value = ['9007199254740993', '9007199254740992', '002'];
  assert.deepEqual(ids(mergeMessages([], value.map(id => row(id)))), value);
});
test('empty or malformed IDs cannot become an infinite paging cursor', () => {
  const invalid = new MessageEntry();
  assert.deepEqual(ids(mergeMessages([], [invalid, row('valid'), row('')])), ['valid']);
});
test('an empty poll keeps existing messages and repeated pages remain stable', () => {
  const values = [row('a'), row('b')];
  assert.deepEqual(ids(mergeMessages(values, [])), ['a', 'b']);
  assert.deepEqual(ids(mergeMessages(values, values)), ['a', 'b']);
});
