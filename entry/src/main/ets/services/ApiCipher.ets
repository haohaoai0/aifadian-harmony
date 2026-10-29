import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { FormField } from '../models/Models';
import { CheckForgotCodePayload, ForgotCodePayload, PasswordLoginPayload, QuickLoginPayload, RegisterCodePayload,
  RegisterPayload, ResetPasswordPayload, SendCodePayload } from '../models/AuthModels';

// Exact public protocol constants from afd_17996.apk AfdEncryptUtils, not credentials.
const PUBLIC_KEY: string = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4Top/Mt2ofZeAIMh9AHw4d6Q+iyBxXbou+1mbhclLsB3YSMbFD+X6QnlAY1vMHO7fteKevn25iVIELBXsmcQS5/oA2hO3VHi9uTG3XmYVcrw94cK5ppODeBOV0hV0dFS/NOT66pqPAuLW6HgRrntgznl4ju6ttOddDNJ7e97RH9qrZEpzjl9GqVZQ2sFdmmw4dNET9fP9HWq8VlfW+BFG7TuxzEjZNcxAgrG/f41Z0+G3RxAccF8LOxu4Ztk1ZDdv5xukdx2ukoEhgdmKUkDv/W5r3HPj1uX+buzDi/UsumMblWXb0Bys7ENhZ/n4+naZ3b3rJ32DnTF7brVHncu7wIDAQAB';
export class ApiCipher {
  static async encode(fields: FormField[], encryptedNames: string[]): Promise<FormField[]> {
    if (encryptedNames.length === 0) { return fields; }
    const keyText: string = await ApiCipher.newAesKeyText();
    const result: FormField[] = [];
    for (let i: number = 0; i < fields.length; i++) {
      let value: string = fields[i].value;
      if (value.length > 0 && encryptedNames.includes(fields[i].name)) {
        value = await ApiCipher.aesEncrypt(value, keyText);
      }
      result.push(new FormField(fields[i].name, value));
    }
    result.push(new FormField('ar_ept', await ApiCipher.rsaEncrypt(keyText)));
    // Errors deliberately propagate: never retry credentials as plaintext.
    return result;
  }

  static async passwordPayload(account: string, password: string): Promise<PasswordLoginPayload> {
    const keyText: string = await ApiCipher.newAesKeyText();
    return new PasswordLoginPayload(await ApiCipher.aesEncrypt(account, keyText),
      await ApiCipher.aesEncrypt(password, keyText), await ApiCipher.rsaEncrypt(keyText));
  }

  static async quickLoginPayload(account: string, code: string): Promise<QuickLoginPayload> {
    const keyText: string = await ApiCipher.newAesKeyText();
    return new QuickLoginPayload(await ApiCipher.aesEncrypt(account, keyText),
      await ApiCipher.aesEncrypt(code, keyText), await ApiCipher.rsaEncrypt(keyText));
  }

  static async sendCodePayload(account: string, captchaCode: string): Promise<SendCodePayload> {
    const keyText: string = await ApiCipher.newAesKeyText();
    return new SendCodePayload(await ApiCipher.aesEncrypt(account, keyText), captchaCode,
      await ApiCipher.rsaEncrypt(keyText));
  }

  static async registerCodePayload(account: string, password: string, name: string,
    captchaCode: string): Promise<RegisterCodePayload> {
    const keyText: string = await ApiCipher.newAesKeyText();
    return new RegisterCodePayload(await ApiCipher.aesEncrypt(account, keyText),
      await ApiCipher.aesEncrypt(password, keyText), name, captchaCode, await ApiCipher.rsaEncrypt(keyText));
  }

  static async registerPayload(account: string, password: string, name: string,
    code: string): Promise<RegisterPayload> {
    const keyText: string = await ApiCipher.newAesKeyText();
    return new RegisterPayload(await ApiCipher.aesEncrypt(account, keyText),
      await ApiCipher.aesEncrypt(password, keyText), name, await ApiCipher.aesEncrypt(code, keyText),
      await ApiCipher.rsaEncrypt(keyText));
  }

  static async forgotCodePayload(account: string): Promise<ForgotCodePayload> {
    const keyText: string = await ApiCipher.newAesKeyText();
    return new ForgotCodePayload(await ApiCipher.aesEncrypt(account, keyText), await ApiCipher.rsaEncrypt(keyText));
  }

  static async checkForgotCodePayload(account: string, code: string): Promise<CheckForgotCodePayload> {
    const keyText: string = await ApiCipher.newAesKeyText();
    return new CheckForgotCodePayload(await ApiCipher.aesEncrypt(account, keyText),
      await ApiCipher.aesEncrypt(code, keyText), await ApiCipher.rsaEncrypt(keyText));
  }

  static async resetPasswordPayload(token: string, password: string): Promise<ResetPasswordPayload> {
    const keyText: string = await ApiCipher.newAesKeyText();
    return new ResetPasswordPayload(await ApiCipher.aesEncrypt(token, keyText),
      await ApiCipher.aesEncrypt(password, keyText), await ApiCipher.rsaEncrypt(keyText));
  }

  private static async newAesKeyText(): Promise<string> {
    const random: cryptoFramework.DataBlob = await cryptoFramework.createRandom().generateRandom(16);
    let keyText: string = '';
    for (let i: number = 0; i < random.data.length; i++) {
      keyText += random.data[i].toString(16).padStart(2, '0');
    }
    return keyText;
  }

  private static async aesEncrypt(value: string, keyText: string): Promise<string> {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const key: cryptoFramework.SymKey =
      await cryptoFramework.createSymKeyGenerator('AES256').convertKey({ data: encoder.encodeInto(keyText) });
    const iv: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: { data: encoder.encodeInto('7brVHncu7wIDAQAB') }
    };
    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, iv);
    return new util.Base64Helper().encodeToStringSync((await cipher.doFinal({ data: encoder.encodeInto(value) })).data);
  }

  private static async rsaEncrypt(value: string): Promise<string> {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const base64: util.Base64Helper = new util.Base64Helper();
    const pair: cryptoFramework.KeyPair =
      await cryptoFramework.createAsyKeyGenerator('RSA2048').convertKey({ data: base64.decodeSync(PUBLIC_KEY) }, null);
    const rsa: cryptoFramework.Cipher = cryptoFramework.createCipher('RSA2048|PKCS1');
    await rsa.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, pair.pubKey, null);
    return base64.encodeToStringSync((await rsa.doFinal({ data: encoder.encodeInto(value) })).data);
  }
}
