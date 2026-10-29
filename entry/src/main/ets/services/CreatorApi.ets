import { Post } from '../models/Models';
import { CreatorAlbum, CreatorAlbumPostResponse, CreatorAlbumResponse, CreatorGoal, CreatorGoalResponse,
  CreatorPlanSkus, CreatorProduct, CreatorProductResponse } from '../models/CreatorModels';
import { afdianApi } from './AfdianApi';

export class CreatorApi {
  async goals(userId: string): Promise<CreatorGoal[]> {
    const response: CreatorGoalResponse = await afdianApi.request<CreatorGoalResponse>(
      '/api/creator/get-goals?user_id=' + encodeURIComponent(userId));
    return response.list ?? response.goals ?? [];
  }

  async albums(userId: string): Promise<CreatorAlbum[]> {
    const response: CreatorAlbumResponse = await afdianApi.request<CreatorAlbumResponse>(
      '/api/user/get-album-list?user_id=' + encodeURIComponent(userId) + '&page=1&per_page=10');
    return response.list ?? response.albums ?? [];
  }

  async albumPosts(albumId: string): Promise<Post[]> {
    const response: CreatorAlbumPostResponse = await afdianApi.request<CreatorAlbumPostResponse>(
      '/api/user/get-album-post?album_id=' + encodeURIComponent(albumId));
    return response.list ?? [];
  }

  async products(userId: string): Promise<CreatorProduct[]> {
    const response: CreatorProductResponse = await afdianApi.request<CreatorProductResponse>(
      '/api/creator/get-products?user_id=' + encodeURIComponent(userId) + '&page=1&tag_id=');
    return response.list ?? [];
  }

  async planSkus(planId: string, isExt: string = ''): Promise<CreatorPlanSkus> {
    return afdianApi.request<CreatorPlanSkus>('/api/creator/get-plan-skus?plan_id=' + encodeURIComponent(planId) +
      '&is_ext=' + encodeURIComponent(isExt));
  }
}

export const creatorApi: CreatorApi = new CreatorApi();
