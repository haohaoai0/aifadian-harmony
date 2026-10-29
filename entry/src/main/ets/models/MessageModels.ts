export class MessageOrderPlan { name: string = ''; }
export class MessageOrderContent {
  total_amount: string = '';
  remark: string = '';
  out_trade_no: string = '';
  plan?: MessageOrderPlan;
}
export class DirectMessage {
  msg_id: string = '';
  type: string | number = '';
  content: string | MessageOrderContent = '';
  sender: string = '';
  receiver: string = '';
  send_time: number = 0;
  url: string = '';
}
export class MessageEntry { message: DirectMessage = new DirectMessage(); type: string = ''; }
export class MessageHistory { list: MessageEntry[] = []; has_more: number = 0; can_pic_msg: boolean = false; }
export class MessageFAQ { id: number = 0; title: string = ''; }
export class MessageFAQResponse { other_list: MessageFAQ[] = []; }
export class UnreadCount { comment: number = 0; like: number = 0; message: number = 0; }
export class MyCheckData {
  unread_message_num: number = 0;
  unread_comment: number = 0;
  unread_like: number = 0;
  unread_private_msg: number = 0;
  unread_count?: UnreadCount;
}

// Keep server order; IDs are opaque strings, never converted to floating point.
// Overlapping history and polling pages must never duplicate a message.
export function mergeMessages(current: MessageEntry[], incoming: MessageEntry[], older: boolean = false): MessageEntry[] {
  const result: MessageEntry[] = [];
  const positions: Map<string, number> = new Map<string, number>();
  const combined: MessageEntry[] = older ? incoming.concat(current) : current.concat(incoming);
  for (const entry of combined) {
    const id: string = entry.message?.msg_id ?? '';
    if (id.length === 0) { continue; }
    const position: number | undefined = positions.get(id);
    if (position === undefined) { positions.set(id, result.length); result.push(entry); }
    else { result[position] = entry; }
  }
  return result;
}
