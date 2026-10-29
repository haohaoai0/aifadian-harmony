import { CreatorPlan, FormField } from '../models/Models';
import { CreatorPlansResponse, PublishResult } from '../models/PublishModels';
import { afdianApi } from './AfdianApi';
import { appStore } from './AppStore';

export class PublishRequest {
  title: string = '';
  content: string = '';
  cover: string = '';
  isPublic: boolean = true;
  planIds: string[] = [];
}

export class PublishApi {
  async plans(): Promise<CreatorPlan[]> {
    const userId: string = appStore.getUser().user_id;
    if (userId.length === 0) { return []; }
    const path: string = '/api/creator/get-plans?user_id=' + encodeURIComponent(userId) +
      '&album_id=&unlock_plan_ids=&diy=&affiliate_code=';
    const data: CreatorPlansResponse | CreatorPlan[] = await afdianApi.request<CreatorPlansResponse | CreatorPlan[]>(path);
    if (Array.isArray(data)) { return data; }
    const regular: CreatorPlan[] = data.list ?? [];
    return regular.length > 0 ? regular : (data.plans ?? []);
  }

  publish(request: PublishRequest): Promise<PublishResult> {
    if (!appStore.isLoggedIn()) { return Promise.reject(new Error('Authentication required')); }
    const planIds: string = request.planIds.join(',');
    const preview: string = request.content.trim().substring(0, 160);
    return afdianApi.request<PublishResult>('/api/post/publish', [
      new FormField('post_id', ''),
      new FormField('vote_id', ''),
      new FormField('cate', ''),
      new FormField('title', request.title.trim()),
      new FormField('content', request.content.trim()),
      new FormField('pics', ''),
      new FormField('is_public', request.isPublic ? '1' : '0'),
      new FormField('min_price', ''),
      new FormField('audio', ''),
      new FormField('video', ''),
      new FormField('audio_thumb', ''),
      new FormField('video_thumb', ''),
      new FormField('type', '0'),
      new FormField('cover', request.cover.trim()),
      new FormField('group_id', ''),
      new FormField('is_feed', '1'),
      new FormField('plan_ids', planIds),
      new FormField('album_ids', ''),
      new FormField('attachment', ''),
      new FormField('timing', ''),
      new FormField('optype', 'publish'),
      new FormField('preview_text', preview)
    ]);
  }
}

export const publishApi: PublishApi = new PublishApi();
