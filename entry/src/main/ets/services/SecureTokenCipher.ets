import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { huks } from '@kit.UniversalKeystoreKit';

export class SecureTokenCipher {
  private readonly keyAlias: string = 'afdian_auth_token_v1';
  private readonly associatedData: Uint8Array = new util.TextEncoder().encodeInto('aifadian.auth.v1');

  async encrypt(value: string): Promise<string> {
    await this.ensureKey();
    const nonce: Uint8Array = cryptoFramework.createRandom().generateRandomSync(12).data;
    const options: huks.HuksOptions = {
      properties: this.cipherProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT, nonce),
      inData: new util.TextEncoder().encodeInto(value)
    };
    const initResult: huks.HuksSessionHandle = await huks.initSession(this.keyAlias, options);
    const result: huks.HuksReturnResult = await huks.finishSession(initResult.handle, options);
    const encrypted: Uint8Array = result.outData as Uint8Array;
    const payload: Uint8Array = new Uint8Array(nonce.length + encrypted.length);
    payload.set(nonce, 0);
    payload.set(encrypted, nonce.length);
    return new util.Base64Helper().encodeToStringSync(payload);
  }

  async decrypt(value: string): Promise<string> {
    await this.ensureKey();
    const payload: Uint8Array = new util.Base64Helper().decodeSync(value);
    if (payload.length <= 28) { throw new Error('Invalid secure session'); }
    const nonce: Uint8Array = payload.slice(0, 12);
    const encrypted: Uint8Array = payload.slice(12);
    const options: huks.HuksOptions = {
      properties: this.cipherProperties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT, nonce,
        encrypted.slice(encrypted.length - 16)),
      inData: encrypted.slice(0, encrypted.length - 16)
    };
    const initResult: huks.HuksSessionHandle = await huks.initSession(this.keyAlias, options);
    const result: huks.HuksReturnResult = await huks.finishSession(initResult.handle, options);
    return util.TextDecoder.create().decodeToString(result.outData as Uint8Array);
  }

  private async ensureKey(): Promise<void> {
    const empty: huks.HuksOptions = { properties: [] };
    if (await huks.hasKeyItem(this.keyAlias, empty)) { return; }
    const properties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE,
        value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT }
    ];
    await huks.generateKeyItem(this.keyAlias, { properties: properties });
  }

  private cipherProperties(purpose: number, nonce: Uint8Array, tag?: Uint8Array): huks.HuksParam[] {
    const properties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
      { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: this.associatedData }
    ];
    if (tag !== undefined) {
      properties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: tag });
    }
    return properties;
  }
}
