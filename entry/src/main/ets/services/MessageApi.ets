import { FormField, MessagePage } from '../models/Models';
import { MessageEntry, MessageFAQ, MessageFAQResponse, MessageHistory, MyCheckData } from '../models/MessageModels';
import { afdianApi } from './AfdianApi';

export class MessageApi {
  dialogs(page: number, unread: boolean = false): Promise<MessagePage> {
    return afdianApi.request<MessagePage>('/api/message/dialogs?page=' + page + '&unread=' + (unread ? '1' : ''));
  }
  history(userId: string, cursor: string = '', newer: boolean = false): Promise<MessageHistory> {
    return afdianApi.request<MessageHistory>('/api/message/messages?user_id=' + encodeURIComponent(userId) +
      '&type=' + (newer ? 'new' : 'old') + '&message_id=' + encodeURIComponent(cursor));
  }
  sendText(userId: string, content: string): Promise<MessageEntry> {
    return afdianApi.request<MessageEntry>('/api/message/send', [new FormField('user_id', userId),
      new FormField('type', '1'), new FormField('content', content)]);
  }
  async faqs(userId: string): Promise<MessageFAQ[]> {
    const response: MessageFAQResponse = await afdianApi.request<MessageFAQResponse>(
      '/api/faq/list-faq?user_id=' + encodeURIComponent(userId));
    return response.other_list ?? [];
  }
  askFaq(userId: string, faqId: number): Promise<MessageEntry> {
    return afdianApi.request<MessageEntry>('/api/faq/ask', [
      new FormField('id', faqId.toString()),
      new FormField('user_id', userId)
    ]);
  }
  async markRead(userId: string): Promise<void> {
    await afdianApi.requestVoid('/api/message/messages?user_id=' + encodeURIComponent(userId) +
      '&type=old&message_id=');
  }
  async unreadDialogs(): Promise<MessagePage> {
    const page: MessagePage = await afdianApi.request<MessagePage>('/api/message/dialogs?page=1&unread=1');
    return page;
  }
  check(): Promise<MyCheckData> {
    return afdianApi.request<MyCheckData>('/api/my/check');
  }
  async deleteDialog(userId: string): Promise<void> {
    await afdianApi.requestVoid('/api/message/delete-dialog?user_id=' + encodeURIComponent(userId));
  }
}
export const messageApi: MessageApi = new MessageApi();
