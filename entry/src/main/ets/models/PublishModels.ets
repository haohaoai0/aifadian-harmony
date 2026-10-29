import { CreatorPlan } from './Models';

export class CreatorPlansResponse {
  list: CreatorPlan[] = [];
  plans: CreatorPlan[] = [];
  sale_list: CreatorPlan[] = [];
}

export class PublishResult {
  post_id: string = '';
}
