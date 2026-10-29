import test from 'node:test';
import assert from 'node:assert/strict';
import { PostComment, commentCursor, mergeComments } from '../entry/src/main/ets/models/CommentModels.ts';

function comment(id, cursor = id) {
  const value = new PostComment();
  value.comment_id = id;
  value.publish_sn = cursor;
  return value;
}

test('comments keep hot-first ordering and preserve existing duplicates', () => {
  const existing = [comment('hot', '10'), comment('old', '9')];
  const incoming = [comment('old', '9'), comment('next', '8')];
  assert.deepEqual(mergeComments(existing, incoming).map(value => value.comment_id), ['hot', 'old', 'next']);
});

test('empty comment ids are discarded', () => {
  assert.deepEqual(mergeComments([], [comment(''), comment('valid')]).map(value => value.comment_id), ['valid']);
});

test('comment cursors remain opaque strings', () => {
  assert.equal(commentCursor(comment('x', '9007199254740993')), '9007199254740993');
});
