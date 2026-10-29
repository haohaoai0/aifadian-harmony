export class ApiResponse<T> { ec: number = 0; em: string = ''; data?: T; }
export class CreatorInfo {
  doing: string = '';
  detail: string = '';
  monthly_fans: string = '';
  status: number = 0;
  create_time: number = 0;
  type: number = 0;
  pic: string = '';
  watermark: number = 0;
  privacy_public_income: number = 0;
  privacy_public_sponsor: number = 0;
  can_copy_text: number = 1;
  can_copy_pic: number = 1;
  show_album: number = 1;
  show_shop: number = 0;
  homepage_product_count: number = -1;
  category?: Category;
}
export class CreatorPlan {
  plan_id: string = '';
  name: string = '';
  show_price: string = '';
  price: string = '';
  pay_month: string = '';
  product_type: number = 0;
  independent: number = 0;
  permanent: number = 0;
  pic: string = '';
  desc: string = '';
  floor_price: string = '';
}
export class User {
  user_id: string = '';
  name: string = '';
  avatar: string = '';
  cover: string = '';
  url_slug: string = '';
  birthday: string = '';
  gender: string = '';
  addr_name: string = '';
  addr_phone: string = '';
  addr_address: string = '';
  show_sponsoring: boolean = true;
  has_set_password: string = '';
  plan?: CreatorPlan;
  creator?: CreatorInfo;
}
export class Category { category_id: string = ''; name: string = ''; pic: string = ''; }
export class CreatorPage { list: User[] = []; has_more: number = 0; }
export class TopSponsorPage { list: User[] = []; has_more: number = 0; }
export class CreatorPlansPage { list: CreatorPlan[] = []; sale_list: CreatorPlan[] = []; sale_has_more: number = 0; }
export class CategoryPage { list: Category[] = []; }
export class UserProfile { user: User = new User(); }
export class Post {
  post_id: string = ''; user_id: string = ''; title: string = ''; content: string = ''; preview_text: string = '';
  cover: string = ''; pics: string[] = []; audio: string = ''; video: string = '';
  is_public: number = 1;
  has_right: number = 0; has_like: number = 0; like_count: number = 0; comment_count: number = 0;
  publish_time: number = 0; publish_sn: string = ''; user?: User;
}
export class PostPage { list: Post[] = []; has_more: number = 0; }
export class PostDetail { post: Post = new Post(); }
export class LoginData { auth_token: string = ''; }
export class MessageItem { desc: string = ''; send_time: number = 0; unread_count: number = 0; user: User = new User(); }
export class MessagePage { list: MessageItem[] = []; has_more: number = 0; }
export class RouteParam {
  url: string = ''; title: string = ''; userId: string = ''; postId: string = ''; avatar: string = ''; login: boolean = false;
  constructor(url: string = '', title: string = '') { this.url = url; this.title = title; }
}
export class FormField {
  name: string = ''; value: string = '';
  constructor(name: string, value: string) { this.name = name; this.value = value; }
}
export function plainText(value: string): string {
  return value.replace(/<br\s*\/?\s*>/gi, '\n').replace(/<\/p>/gi, '\n').replace(/<[^>]*>/g, '')
    .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").trim();
}
