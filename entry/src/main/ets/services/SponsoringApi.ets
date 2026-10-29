import { SponsoringResponse } from '../models/SponsoringModels';
import { afdianApi } from './AfdianApi';

export class SponsoringApi {
  current(): Promise<SponsoringResponse> {
    const response: Promise<SponsoringResponse> = afdianApi.request<SponsoringResponse>(
      '/api/my/sponsoring?need_sponsor_info=1');
    return response;
  }
}

export const sponsoringApi: SponsoringApi = new SponsoringApi();
