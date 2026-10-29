import { FaqItem, FaqListData } from '../models/FaqModels';
import { afdianApi } from './AfdianApi';

export class FaqApi {
  async list(): Promise<FaqItem[]> {
    const data: FaqListData = await afdianApi.request<FaqListData>('/api/faq/list');
    return data.list ?? [];
  }

  async save(id: number, title: string, content: string): Promise<void> {
    await afdianApi.requestJsonVoid('/api/faq/edit-faq', new FaqPayload(id, title, content), '保存失败');
  }

  async remove(id: number): Promise<void> {
    await afdianApi.requestJsonVoid('/api/faq/delete-faq', new DeleteFaqPayload(id), '删除失败');
  }
}

class DeleteFaqPayload {
  id: number = 0;
  constructor(id: number) { this.id = id; }
}

class FaqPayload {
  id?: number;
  title: string = '';
  content: string = '';

  constructor(id: number, title: string, content: string) {
    if (id > 0) { this.id = id; }
    this.title = title;
    this.content = content;
  }
}

export const faqApi: FaqApi = new FaqApi();
