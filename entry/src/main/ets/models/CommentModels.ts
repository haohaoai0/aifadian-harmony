export class CommentUser {
  user_id: string = '';
  name: string = '';
  avatar: string = '';
  cover: string = '';
  url_slug: string = '';
}

export class PostComment {
  comment_id: string = '';
  post_id: string = '';
  user_id: string = '';
  content: string = '';
  like_count: number = 0;
  has_like: number = 0;
  publish_time: number = 0;
  publish_sn: string = '';
  can_edit: number = 0;
  sub_comment_has_more: number = 0;
  user: CommentUser = new CommentUser();
  reply_user: CommentUser = new CommentUser();
  sub_comments: PostComment[] = [];
}

export class CommentData {
  list?: PostComment[];
  hot_list?: PostComment[];
  has_more: number | string | boolean = 0;
}

export class CommentPage {
  comments: PostComment[] = [];
  hasMore: boolean = false;
  nextCursor: string = '';
}

export function mergeComments(existing: PostComment[], incoming: PostComment[]): PostComment[] {
  const result: PostComment[] = [];
  const seen: Set<string> = new Set<string>();
  const combined: PostComment[] = existing.concat(incoming);
  for (let i: number = 0; i < combined.length; i++) {
    const id: string = combined[i].comment_id ?? '';
    if (id.length === 0 || seen.has(id)) { continue; }
    seen.add(id);
    result.push(combined[i]);
  }
  return result;
}

export function commentHasMore(value: number | string | boolean): boolean {
  return value === true || value === 1 || value === '1';
}

export function commentCursor(comment: PostComment): string {
  return typeof comment.publish_sn === 'string' ? comment.publish_sn : String(comment.publish_sn ?? '');
}
