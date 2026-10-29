import { FormField, Post, User } from '../models/Models';
import { FavoriteCreatorResponse, FavoriteCrowdfunding, FavoriteCrowdfundingItem, FavoriteCrowdfundingResponse,
  FavoritePostResponse } from '../models/FavoriteModels';
import { afdianApi } from './AfdianApi';

export class FavoritePostPage {
  list: Post[] = [];
  hasMore: boolean = false;
}

export class FavoriteApi {
  async creators(): Promise<User[]> {
    const data: FavoriteCreatorResponse | User[] =
      await afdianApi.request<FavoriteCreatorResponse | User[]>('/api/my/marked');
    if (Array.isArray(data)) { return data; }
    if (data.list.length > 0) { return data.list; }
    if (data.marked.length > 0) { return data.marked; }
    if (data.user_list.length > 0) { return data.user_list; }
    return data.users;
  }

  async posts(page: number): Promise<FavoritePostPage> {
    const path: string = page <= 1 ? '/api/my/marked-post?page=' : '/api/my/marked-post?page=' + page;
    const data: FavoritePostResponse | Post[] =
      await afdianApi.request<FavoritePostResponse | Post[]>(path);
    const result: FavoritePostPage = new FavoritePostPage();
    if (Array.isArray(data)) {
      result.list = data;
    } else {
      const regular: Post[] = data.list ?? [];
      const fallback: Post[] = data.post_list ?? [];
      result.list = regular.length > 0 ? regular : fallback;
      result.hasMore = data.has_more === 1;
    }
    return result;
  }

  unmarkCreator(userId: string): Promise<Object> {
    return afdianApi.request<Object>('/api/user/unmark', [new FormField('user_id', userId)]);
  }

  unmarkPost(postId: string): Promise<Object> {
    return afdianApi.request<Object>('/api/user/unmark-post', [new FormField('post_id', postId)]);
  }

  async crowdfundings(): Promise<FavoriteCrowdfunding[]> {
    const response: FavoriteCrowdfundingResponse = await afdianApi.request<FavoriteCrowdfundingResponse>(
      '/api/user/marked-crowdfunding');
    const raw: FavoriteCrowdfundingItem[] = response.items ?? response.list ?? [];
    const result: FavoriteCrowdfunding[] = [];
    for (let i: number = 0; i < raw.length; i++) {
      const nested: FavoriteCrowdfunding | undefined = raw[i].crowdfunding;
      if (nested !== undefined) {
        result.push(nested);
        continue;
      }
      const project: FavoriteCrowdfunding = new FavoriteCrowdfunding();
      project.crowdfunding_id = raw[i].crowdfunding_id;
      project.name = raw[i].name;
      project.title = raw[i].title;
      project.pic = raw[i].pic;
      project.process = raw[i].process;
      project.begin_time = raw[i].begin_time;
      project.end_time = raw[i].end_time;
      project.sponsor_count = raw[i].sponsor_count;
      project.goal_list = raw[i].goal_list ?? [];
      if (project.crowdfunding_id.length > 0) { result.push(project); }
    }
    return result;
  }
}

export const favoriteApi: FavoriteApi = new FavoriteApi();
