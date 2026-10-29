import { User } from './Models';

export class NoticePost {
  post_id: string = '';
  title: string = '';
  desc: string = '';
  thumb: string = '';
  pic_count: number = 0;
}

export class NoticeItem {
  notice_id: string = '';
  id: string = '';
  publish_sn: string = '';
  action: string = '';
  subject: string = '';
  time: number = 0;
  create_time: number = 0;
  send_time: number = 0;
  comment_id: string = '';
  comment_text: string = '';
  desc: string = '';
  content: string = '';
  unread: number = 0;
  user: User = new User();
  post: NoticePost = new NoticePost();
  post_id: string = '';
}

export class NoticeRawUser {
  user_id: string = '';
  name: string = '';
  avatar: string = '';
  headimgurl: string = '';
}

export class NoticeRawPost {
  post_id: string = '';
  title: string = '';
  desc: string = '';
  thumb: string = '';
  pic_count: number | string = 0;
}

export class NoticeRawAction {
  user?: NoticeRawUser;
  publish_time: number | string = 0;
  comment_id: number | string = '';
  content: string = '';
}

export class NoticeRawItem {
  subject: string = '';
  publish_sn: number | string = '';
  action: string = '';
  action_item?: NoticeRawAction;
  object_item?: NoticeRawPost;
  post?: NoticeRawPost;
  create_time: number | string = 0;
  send_time: number | string = 0;
  unread: number | string = 0;
  comment_id: number | string = '';
  content: string = '';
  desc: string = '';
}

export class NoticeResponse {
  list?: NoticeRawItem[];
  notice_list?: NoticeRawItem[];
  has_more: number | string | boolean = 0;
}

export class NoticePage {
  list: NoticeItem[] = [];
  hasMore: boolean = false;
}
