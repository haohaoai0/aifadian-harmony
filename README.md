<div align="center">

<img src="AppScope/resources/base/media/afd_icon.png" width="96" alt="爱发电标识">

# aifadian-harmony

**爱发电 HarmonyOS 第三方客户端**

基于 **ArkTS + ArkUI + HDS** 构建，为 HarmonyOS 提供原生的动态、创作者、消息和账号体验。

[功能一览](#二功能一览) · [从源码构建](#三从源码构建) · [隐私与数据](#五隐私与数据) · [致谢](#八致谢)

> 项目仍在开发中，部分操作通过爱发电站内网页完成。源码构建通过不代表所有账号、设备及业务流程均已验证。

</div>

---

## 一、项目说明

这是爱发电的**非官方客户端**，与爱发电及其运营方不存在隶属、授权或背书关系。应用问题与建议请提交到本仓库的 [Issues](https://github.com/haohaoai0/aifadian-harmony/issues)。提交时请提供版本、设备系统及复现步骤，并遮盖账号、收入、订单和聊天内容。

- 使用爱发电站内接口，接口、风控及验证码策略变化可能导致功能失效。
- 付费内容仍受平台权限控制；本项目不提供绕过付费、账号验证或访问限制的功能。
- 支付、提现及部分管理操作通过站内网页或系统外部应用继续完成。
- “爱发电”“Afdian”名称、标识及平台内容归各自权利人所有。

## 二、功能一览

下表说明当前源码中的实现范围；实际可用性受账号权限与上游接口影响。

| 模块 | 当前实现 |
| --- | --- |
| 登录与账号 | 密码、验证码、图形验证码、网页登录、注册与找回密码入口、多账号切换 |
| 动态 | 推荐与关注动态、动态详情、图片查看、喜欢、评论及回复 |
| 发现 | 分类浏览、创作者列表与搜索、创作者主页 |
| 创作者主页 | 动态、方案、目标、合集、商品及赞助榜展示 |
| 消息 | 会话列表、未读筛选、历史分页、文本私信、FAQ 快捷回复、已读与会话管理 |
| 收藏与赞助 | 收藏动态、创作者、众筹及赞助记录 |
| 创作管理 | 发布入口、创作者基础资料、隐私选项与 FAQ 管理 |
| 收入 | 数据卡、收入趋势、月账单、收到发电与提现记录展示 |
| 系统体验 | HDS 导航、浅色 / 深色 / 跟随系统、可选原生材质、中文与英文资源、窗口尺寸适配 |

## 三、从源码构建

### 环境要求

| 组件 | 要求 |
| --- | --- |
| IDE | 能识别工程 `modelVersion: 6.0.2` 并安装目标 SDK 的 DevEco Studio |
| SDK | `targetSdkVersion: 26.0.0`；最低兼容 `6.0.2(22)` |
| 语言与模型 | ArkTS、ArkUI V1、Stage 模型 |
| 设备声明 | 手机、平板、2in1；各形态的实际体验需要分别验证 |
| 命令行 | 已配置 DevEco Studio 与 SDK 的 `devecocli` |
| 离线检查 | Node.js 24、Python 3.10+；Python 检查仅使用标准库 |

```bash
git clone https://github.com/haohaoai0/aifadian-harmony.git
cd aifadian-harmony

# 不需要账号、签名或抓包文件
python scripts/validate_project.py
python scripts/audit_public.py
node --test tests/*.test.mjs

# 在配置好 DevEco 的环境中构建
devecocli build --product default --build-mode debug
devecocli build --product default --build-mode release
```

也可以直接在 DevEco Studio 打开仓库，等待依赖同步后构建 `default` 产品。工程不依赖开发者本机目录、分析资料或原始参考仓库。

应用版本的来源是 `AppScope/app.json5`，当前为 `0.1.0`，`versionCode` 为 `10001`。

### 离线检查与 CI

- `validate_project.py`：检查资源、多语言、主题、资源引用、SDK 配置、权限与基础 ArkTS 约束。
- `audit_public.py`：检查待提交文件中的签名配置、本机路径及常见凭据；Git 工程中读取暂存区内容。
- `node --test`：验证 URL 信任边界、接口路由、评论合并及消息分页去重。
- GitHub Actions 自动执行以上检查。云端检查不构建 HAP，也不代表签名、安装或运行验收。

## 四、签名与安装

仓库默认的 `build-profile.json5` **不包含签名材料与签名绑定**，可以用于未签名构建。未签名 HAP 不能直接安装到真机。

需要安装时，请在 DevEco Studio 的工程签名设置中，使用自己的证书、Profile、密钥库及对应包名配置签名，然后执行：

```bash
devecocli device list
devecocli run --module entry --device <设备序列号>
```

不要提交签名后的个人配置。证书、私钥、密钥库、Profile、本机配置和构建产物均已加入忽略规则；修改 `build-profile.json5` 后提交前还需确认 `signingConfigs` 为空，且产品没有个人 `signingConfig` 绑定。隐私检查会拦截带签名材料的暂存内容。

## 五、隐私与数据

- 仓库不包含开发者的登录态、Cookie、账号数据、聊天、订单、收入、接口响应、抓包、设备截图及运行日志。
- 登录令牌通过 **HUKS + AES-GCM** 加密后保存在应用私有存储，多账号记录保存加密令牌。代码包含旧版会话迁移逻辑，具体实现见 `AppStore.ets` 与 `SecureTokenCipher.ets`。
- 账号资料、设置等保存在应用私有 Preferences 中。WebView 的 Cookie 与网页缓存由系统 ArkWeb 管理。
- 原生接口请求的来源由代码中的固定 HTTPS 域名列表限制；Cookie 同步仅面向代码中明确列出的爱发电站点。
- 网页遵循平台自己的加载与数据策略；外部链接会提示后交给系统处理。
- 请求日志仅输出接口路径和错误状态，不输出请求正文或令牌。
- `ApiCipher.ets` 中的 RSA **公钥**与协议 IV 是兼容上游接口所需的公开协议常量，不是开发者私钥或账号凭据。

请勿在 Issue、PR、截图或测试样本中提交真实密码、手机号、邮箱、验证码、令牌、收支及私信数据。

## 六、已知限制

- 本项目仍在开发，功能清单不表示全部业务流程都经过真机验收。
- 交易与部分管理功能保留网页入口；不会将参考 Android 项目的功能清单视作鸿蒙端已实现的能力。
- 发布页的草稿、定时发布等入口尚未完成，部分多媒体编辑能力仍需站内网页。
- 上游接口没有稳定性保证，验证码、第三方登录及部分账号相关操作可能需要站内网页。
- 最低兼容版本、平板、多窗口和 2in1 体验需要在对应系统与设备上分别测试。
- 开源仓库不附带可直接安装的签名包，也不包含个人账号界面截图。

## 七、项目结构

```text
aifadian-harmony/
├── AppScope/                    # 应用标识、版本与图标
├── entry/src/main/
│   ├── ets/
│   │   ├── common/              # URL 与路由策略
│   │   ├── components/          # 公共界面组件
│   │   ├── models/              # 数据模型与列表合并
│   │   ├── pages/               # 原生页面与站内网页
│   │   ├── services/            # 网络、接口、账号及加密存储
│   │   └── utils/               # 平台兼容、材质与导航样式
│   └── resources/               # 中文、英文及深浅色资源
├── scripts/                     # 可独立运行的离线校验与隐私检查
├── tests/                       # 不依赖账号的 Node.js 测试
├── .github/workflows/checks.yml  # 离线 CI
├── build-profile.json5          # 无个人签名的公开构建配置
├── NOTICE                       # 来源与权利说明
└── LICENSE                      # Apache-2.0
```

## 八、致谢

- [afdian-compose](https://github.com/hrsthrt74/afdian-compose)（Apache-2.0）：功能组织、交互和项目说明参考。
- [HarmonyX](https://github.com/haohaoai0/HarmonyX)：HDS 导航、原生材质及窗口适配实践参考。
- HarmonyOS / ArkUI / HDS：原生界面、导航、系统分享、网络与设备密钥能力。

本仓库提供鸿蒙 ArkTS 工程；参考 Android 工程的源码、工具链及个人分析资料不随仓库分发。已有源文件中的版权声明予以保留，详见 [NOTICE](NOTICE)。

## 九、License

源码采用 [Apache License 2.0](LICENSE)。平台商标、图标与用户内容不因源码开源而变更其权利归属。
