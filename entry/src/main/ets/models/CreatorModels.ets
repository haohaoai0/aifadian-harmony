import { Post } from './Models';

export class CreatorGoal {
  goal_id: string = '';
  user_id: string = '';
  status: number = 0;
  type: number = 0;
  desc: string = '';
  monthly_fans: number | string = 0;
  monthly_income: string = '';
  begin_time: number = 0;
  end_time: number = 0;
  sum_income: string = '';
  sum_fans: number = 0;
  days_left: string = '';
  percent: string = '';
  title: string = '';
  name: string = '';
  current_amount: string = '';
  target_amount: string = '';

  displayTitle(): string { return this.desc || this.title || this.name; }
  currentText(): string {
    if (this.type === 2) { return this.sum_fans.toString(); }
    return this.sum_income || this.current_amount;
  }
  targetText(): string {
    if (this.type === 2) { return String(this.monthly_fans); }
    return this.monthly_income || this.target_amount;
  }
}

export class CreatorAlbum {
  album_id: string = '';
  title: string = '';
  name: string = '';
  cover: string = '';
  content: string = '';
  post_count: number = 0;

  displayTitle(): string { return this.title || this.name; }
}

export class CreatorProduct {
  plan_id: string = '';
  name: string = '';
  pic: string = '';
  price: string = '';
  show_price: string = '';
  floor_price: string = '';
  desc: string = '';
  description: string = '';
}

export class CreatorGoalResponse {
  list?: CreatorGoal[];
  goals?: CreatorGoal[];
}

export class CreatorAlbumResponse {
  list?: CreatorAlbum[];
  albums?: CreatorAlbum[];
}

export class CreatorAlbumPostResponse {
  list?: Post[];
}

export class CreatorProductResponse {
  list?: CreatorProduct[];
}

export class CreatorPlanSkuPlan {
  plan_id: string = '';
  user_id: string = '';
  name: string = '';
  pic: string = '';
  desc: string = '';
  price: string = '';
  show_price: string = '';
  pay_month: number = 0;
  product_type: number = 0;
  permanent: number = 0;
  need_address: number = 0;
}

export class CreatorPlanSku {
  sku_id: string = '';
  plan_id: string = '';
  name: string = '';
  stock: string = '';
  price: string = '';
  pic: string = '';
  desc: string = '';
  sponsor_count: string = '';
  show_stock: number = 0;
  plan?: CreatorPlanSkuPlan;
}

export class CreatorPlanSkus {
  plan?: CreatorPlanSkuPlan;
  floor_price: string = '';
  has_time_limit_price: number = 0;
  list: CreatorPlanSku[] = [];
  vip_all_plans: CreatorPlanSkuPlan[] = [];
  bought_skus: CreatorPlanSku[] = [];
}
