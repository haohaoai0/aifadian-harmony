import { NoticeItem, NoticePage, NoticeRawAction, NoticeRawItem, NoticeRawPost, NoticeRawUser, NoticeResponse } from '../models/NoticeModels';
import { User } from '../models/Models';
import { afdianApi } from './AfdianApi';

class NoticeEnvelope {
  ec?: number;
  em: string = '';
  data?: NoticeResponse;
}

function numberValue(value: number | string | undefined): number {
  if (typeof value === 'number') { return Number.isFinite(value) ? value : 0; }
  if (typeof value === 'string') {
    const parsed: number = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function stringValue(value: number | string | undefined): string {
  if (typeof value === 'number') { return Number.isFinite(value) ? value.toString() : ''; }
  return typeof value === 'string' ? value : '';
}

function hasMoreValue(value: number | string | boolean): boolean {
  return value === true || value === 1 || value === '1';
}

export class NoticeApi {
  async list(action: string, cursor: string = ''): Promise<NoticePage> {
    const path: string = '/api/my/notice?publish_sn=' + encodeURIComponent(cursor) +
      '&type=old&action=' + encodeURIComponent(action);
    const text: string = await afdianApi.requestText(path);
    // publish_sn is about 1.8e13. Quote it before JSON.parse so precision is never lost.
    const protectedText: string = text.replace(/("publish_sn"\s*:\s*)(-?\d{10,})/g, '$1"$2"');
    const envelope: NoticeEnvelope = JSON.parse(protectedText) as NoticeEnvelope;
    if (envelope.ec !== undefined && envelope.ec !== 200) {
      throw new Error(envelope.em || 'Notice request failed');
    }
    const data: NoticeResponse = envelope.data ?? new NoticeResponse();
    const raw: NoticeRawItem[] = data.list ?? data.notice_list ?? [];
    const page: NoticePage = new NoticePage();
    for (let i: number = 0; i < raw.length; i++) {
      page.list.push(this.parse(raw[i]));
    }
    page.hasMore = hasMoreValue(data.has_more);
    return page;
  }

  private parse(raw: NoticeRawItem): NoticeItem {
    const item: NoticeItem = new NoticeItem();
    item.action = raw.action;
    item.subject = raw.subject ?? '';
    item.publish_sn = stringValue(raw.publish_sn);
    item.notice_id = item.publish_sn;
    item.id = item.notice_id;
    item.create_time = numberValue(raw.create_time);
    item.send_time = numberValue(raw.send_time);
    item.unread = numberValue(raw.unread);
    item.comment_id = stringValue(raw.comment_id);
    item.comment_text = raw.content ?? '';
    item.desc = raw.desc ?? '';
    item.content = raw.content ?? '';
    item.time = numberValue(raw.action_item?.publish_time);
    if (item.time === 0) { item.time = item.create_time > 0 ? item.create_time : item.send_time; }
    const actionItem: NoticeRawAction | undefined = raw.action_item;
    if (actionItem !== undefined) {
      item.user = this.user(actionItem.user);
      item.comment_id = stringValue(actionItem.comment_id) || item.comment_id;
      item.comment_text = actionItem.content || item.comment_text;
      item.content = item.comment_text;
    }
    const post: NoticeRawPost | undefined = raw.action === 'comment' ?
      (raw.object_item ?? raw.post) : (raw.post ?? raw.object_item);
    if (post !== undefined) {
      item.post.post_id = post.post_id ?? '';
      item.post.title = post.title ?? '';
      item.post.desc = post.desc ?? '';
      item.post.thumb = post.thumb ?? '';
      item.post.pic_count = numberValue(post.pic_count);
      item.post_id = item.post.post_id;
    }
    return item;
  }

  private user(raw: NoticeRawUser | undefined): User {
    const user: User = new User();
    if (raw === undefined) { return user; }
    user.user_id = raw.user_id ?? '';
    user.name = raw.name ?? '';
    user.avatar = raw.avatar || raw.headimgurl || '';
    return user;
  }
}

export const noticeApi: NoticeApi = new NoticeApi();
