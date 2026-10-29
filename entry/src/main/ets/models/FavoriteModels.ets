import { Post, User } from './Models';

export class FavoriteCreatorResponse {
  list: User[] = [];
  marked: User[] = [];
  user_list: User[] = [];
  users: User[] = [];
}

export class FavoritePostResponse {
  list: Post[] = [];
  post_list: Post[] = [];
  has_more: number = 0;
}

export class FavoriteCrowdfundingGoal {
  amount: string = '';
  sum_income: string = '';
  percent: string = '';
}

export class FavoriteCrowdfunding {
  crowdfunding_id: string = '';
  name: string = '';
  title: string = '';
  pic: string = '';
  process: number = 0;
  begin_time: number = 0;
  end_time: number = 0;
  sponsor_count: number = 0;
  goal_list: FavoriteCrowdfundingGoal[] = [];
}

export class FavoriteCrowdfundingItem {
  crowdfunding?: FavoriteCrowdfunding;
  crowdfunding_id: string = '';
  name: string = '';
  title: string = '';
  pic: string = '';
  process: number = 0;
  begin_time: number = 0;
  end_time: number = 0;
  sponsor_count: number = 0;
  goal_list: FavoriteCrowdfundingGoal[] = [];
}

export class FavoriteCrowdfundingResponse {
  items?: FavoriteCrowdfundingItem[];
  list?: FavoriteCrowdfundingItem[];
}
