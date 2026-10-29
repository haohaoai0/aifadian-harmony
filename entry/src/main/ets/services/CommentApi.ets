import { FormField } from '../models/Models';
import { CommentData, CommentPage, PostComment, commentCursor, commentHasMore, mergeComments } from '../models/CommentModels';
import { afdianApi } from './AfdianApi';

export class CommentApi {
  async list(postId: string, cursor: string = ''): Promise<CommentPage> {
    const hot: string = cursor.length === 0 ? '&hot=1' : '';
    const data: CommentData = await afdianApi.request<CommentData>('/api/comment/get-list?post_id=' +
      encodeURIComponent(postId) + '&publish_sn=' + encodeURIComponent(cursor) + '&type=old' + hot);
    const normal: PostComment[] = this.valid(data.list ?? []);
    const hotList: PostComment[] = this.valid(data.hot_list ?? []);
    const page: CommentPage = new CommentPage();
    page.comments = mergeComments(hotList, normal);
    page.hasMore = normal.length > 0 && commentHasMore(data.has_more);
    page.nextCursor = normal.length > 0 ? commentCursor(normal[normal.length - 1]) : '';
    return page;
  }

  async replies(postId: string, rootCommentId: string, cursor: string = ''): Promise<CommentPage> {
    const data: CommentData = await afdianApi.request<CommentData>('/api/comment/get-sub-list?post_id=' +
      encodeURIComponent(postId) + '&root_comment_id=' + encodeURIComponent(rootCommentId) +
      '&publish_sn=' + encodeURIComponent(cursor));
    const normal: PostComment[] = this.valid(data.list ?? []);
    const page: CommentPage = new CommentPage();
    page.comments = normal;
    page.hasMore = normal.length > 0 && commentHasMore(data.has_more);
    page.nextCursor = normal.length > 0 ? commentCursor(normal[normal.length - 1]) : '';
    return page;
  }

  publish(postId: string, content: string, replyCommentId: string = ''): Promise<PostComment> {
    return afdianApi.request<PostComment>('/api/comment/publish', [
      new FormField('post_id', postId),
      new FormField('content', content),
      new FormField('reply_comment_id', replyCommentId)
    ]);
  }

  remove(commentId: string): Promise<Object> {
    return afdianApi.request<Object>('/api/comment/delete', [new FormField('comment_id', commentId)]);
  }

  like(commentId: string, liked: boolean): Promise<Object> {
    return afdianApi.request<Object>(liked ? '/api/comment/unlike' : '/api/comment/like',
      [new FormField('comment_id', commentId)]);
  }

  private valid(source: PostComment[]): PostComment[] {
    const result: PostComment[] = [];
    for (let i: number = 0; i < source.length; i++) {
      if (source[i] !== null && source[i] !== undefined && (source[i].comment_id ?? '').length > 0) {
        result.push(source[i]);
      }
    }
    return result;
  }
}

export const commentApi: CommentApi = new CommentApi();
