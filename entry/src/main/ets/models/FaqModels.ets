export class FaqItem {
  id: number = 0;
  user_id: string = '';
  stat: number = 1;
  title: string = '';
  content: string = '';
  create_time: string = '';
  update_time: string = '';
}

export class FaqListData {
  list?: FaqItem[];
}
