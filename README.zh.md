<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/banner/dark_zh.svg">
  <source media="(prefers-color-scheme: light)" srcset="res/banner/light_zh.svg">
  <img alt="The preview for moodiary." src="res/banner/light_zh.svg">
</picture>
<p align="center">简体中文 | <a href="README.md">English</a></p>

<p align="center"><a href="https://answer.moodiary.net" target="_blank">官方论坛</a>丨QQ群: <a target="_blank" href="https://qm.qq.com/cgi-bin/qm/qr?k=xGr0TNp_X1z3XEn09_iE_iGSLolQwl6Y&jump_from=webapi&authKey=ZmSb2oEd94FSXxBXRBq53hgTjjvcfmgkQrduB3uL12XtRylPmRlO2OdFz6R25tIo">760014526</a>丨Telegram: <a target="_blank" href="https://t.me/openmoodiary">openmoodiary</a></p>

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.29.2-blue?style=for-the-badge">
  <img src="https://img.shields.io/github/repo-size/ZhuJHua/moodiary?style=for-the-badge&color=ff7070">
  <img src="https://img.shields.io/github/stars/ZhuJHua/moodiary?style=for-the-badge&color=965f8a">
  <img src="https://img.shields.io/github/v/release/ZhuJHua/moodiary?style=for-the-badge&color=4f5e7f">
  <img src="https://img.shields.io/github/license/ZhuJHua/moodiary?style=for-the-badge&color=4ac6b7">
</div>



## ✨ 功能特性

- **跨平台支持**：🌍 兼容 Android、iOS、Windows、MacOS、Linux\*。
- **Material Design**：🎨 界面直观且用户友好，遵循 Material Design 设计规范。
- **多种编辑器**：📝 支持 Markdown 、纯文本、富文本等多种形式的文本编辑。
- **多媒体附件**：📷 可以为你的日记添加图片、音频、视频甚至画一张画。
- **搜索和分类**：🔍 轻松通过全文搜索及分类管理你的日记。
- **自定义主题**：🌈 支持浅色和深色模式，以及多种配色的主题。
- **自定义字体**：✍️ 支持导入不同的字体，并支持可变字体。
- **数据安全**：🔒 通过密码来保障你的日记安全，支持通过生物识别解锁。
- **导出和分享**：🧾 支持所有数据的导入/导出，以及单篇日记的分享。
- **备份与同步**：☁ 支持局域网同步，快速在设备间同步数据，以及 WebDav 备份。
- **足迹地图**：🗺️ 在地图上查看你足迹，生活中的每一步都值得被记录。
- **智能助手**：💬 支持接入第三方大模型，提供问答、情绪分析等功能。
- **本地自然语言处理（NLP）**：🤖 更安全的智能助手，让你的日记更懂你。

（注：跨平台能力由 Flutter 提供，带 * 号的平台可能需要更多测试）

## 🔧 主要技术栈

- [Flutter](https://github.com/flutter/flutter)（跨平台 UI 框架）
- [Isar](https://github.com/isar/isar)（高性能本地数据库）
- [GetX](https://github.com/jonataslaw/getx)（状态管理框架）

## 📸 应用截图

> 应用持续更新中，新版本界面可能稍有变化

### 移动端

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/mobile_dark_zh.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/mobile_light_zh.webp">
  <img alt="The mobile screenshot for moodiary." src="res/screenshot/mobile_light_zh.webp">
</picture>

### 桌面端

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/desktop_dark_zh.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/desktop_light_zh.webp">
  <img alt="The desktop screenshot for moodiary." src="res/screenshot/desktop_light_zh.webp">
</picture>

## 🚀 安装指南

### 第三方 SDK

某些能力需要自行申请第三方 SDK，下列服务商均提供免费的版本，获取到的 Key 在实验室中配置。

#### 天气服务

- [和风天气](https://dev.qweather.com/docs/api/)

#### 地图服务

- [天地图](http://lbs.tianditu.gov.cn/server/MapService.html)

#### 智能助手

- [腾讯混元大模型](https://cloud.tencent.com/document/product/1729/97731)

### 直接安装

通过下载 Release 中已编译好的安装包来使用，如果没有你所需要的平台，请使用手动编译。

### 手动编译

#### 环境要求

> 我总是会使用最新的 Flutter 版本（如果可能的话），使用新版本可以带来更多的功能和更好的性能提升，永远不要使用老版本除非你希望代码变成一坨 💩

- Flutter SDK (>= 3.29.0 Stable)（建议使用 fvm 来管理 flutter 版本）
- Dart (>= 3.7.0)
- Rust 工具链（Nightly）
- Clang/LLVM
- 兼容的 IDE（如 Android Studio、Visual Studio Code）

#### 安装步骤

> 注意：出于安全考虑，我并没有在代码库中包含我的签名，当您需要手动打包时，需要自己修改对应平台的配置文件，例如安卓平台的 build.gradle，修改包名后打包，感谢您的理解

1. **克隆仓库**：

```bash
git clone https://github.com/ZhuJHua/moodiary.git
cd moodiary
```

2. **安装依赖**：

```bash
flutter pub get
```

3. **运行应用**：

```bash
flutter run
```

4. **打包发布**：

- Android: `flutter build apk`
- iOS: `flutter build ipa`
- Windows: `flutter build windows`
- MacOS: `flutter build macos`

## 📝 更多说明

### 自然语言处理（NLP）

> 处于实验阶段

如今，越来越多的行业产品开始融入 AI 技术，这无疑极大地提升了我们的使用体验。然而，对于日记应用来说，将数据交给大型模型处理并不可接受，因为无法确定这些数据是否会被用于训练。因此，更好的方法是采用本地模型。虽然由于体积限制，本地模型的能力可能不如大型模型强大，但在一定程度上仍能为我们提供必要的帮助。

目前，我在源码中集成了以下任务：

#### 基于 Bert 预训练模型的 SQuAD 任务

我采用了 MobileBert 来处理 SQuAD 任务，这是一个简单的机器阅读理解任务。你可以向它提出问题，它会返回你需要的答案。模型文件采用 TensorFlow Lite 所需的 `.tflite` 格式，所以你可以添加自己的模型文件到 `assets/tflite` 目录下。

感谢以下开源项目：

- [Chinese MobileBERT](https://github.com/ymcui/Chinese-MobileBERT)
- [Mobilebert](https://github.com/google-research/google-research/tree/master/mobilebert)
- [ChineseSquad](https://github.com/junzeng-pluto/ChineseSquad)

## 🤝 贡献指南

欢迎贡献！请按照以下步骤进行贡献：

1. Fork 本仓库。
2. 创建一个新分支（`git checkout -b feature-branch-name`）。
3. 提交你的修改（`git commit -am 'Add some feature'`）。
4. 推送到分支（`git push origin feature-branch-name`）。
5. 创建一个 Pull Request。

请确保你的代码遵循 [Flutter 风格指南](https://flutter.dev/docs/development/tools/formatting) 并包含适当的测试。

## 📄 许可证

此项目基于 AGPL-3.0 许可证进行许可，详情请参阅 [LICENSE](LICENSE) 文件。

## 💖 鸣谢

- 感谢 Flutter 团队提供出色的框架。
- 特别感谢开源社区的宝贵贡献。

## 🥪 捐助

可以给我买一个三明治，让我更有动力继续开发。

<img src="res/sponsor/wechat.jpg" style="width:300px" alt="Sponsor"/>

### 捐助者名单

如果您想要出现在名单中，可以在留言中留下您的 Github 用户名，排名不分先后，名单会定期更新。

| 捐助者                                | 金额     | 捐助者                                           | 金额      |
| ------------------------------------- | -------- | ------------------------------------------------ | --------- |
| [dsxksss](https://github.com/dsxksss) | 50 CNY   | 十*                                              | 20 CNY    |
| 沭**                                  | 10 CNY   | 朱东杰                                           | 60 CNY    |
| *人*                                  | 5 CNY    | wu*                                              | 10 CNY    |
| 云*                                   | 2.76 CNY | 不对味的雪碧                                     | 10 CNY    |
| w**                                   | 6.6 CNY  | [帕斯卡的芦苇](https://github.com/xiaoxianzi-99) | 10 CNY    |
| 不**                                  | 20 CNY   | 曾**                                             | 20 CNY    |
| *人*                                  | 20 CNY   | *人*                                             | 18.88 CNY |
| Lucci                                 | 9.9 CNY  | *人*                                             | 5 CNY     |
| 宋**                                  | 5 CNY    | 翰**                                             | 5 CNY     |
# Moodiary（轻智能终端二次开发）

> 本仓库在开源 Moodiary 基础上进行"轻智能终端"二次开发，完整设计见
> [docs/轻智能终端-完整架构设计执行指导文档.md](docs/轻智能终端-完整架构设计执行指导文档.md)，
> 开发计划与分工见 [docs/二次开发计划.md](docs/二次开发计划.md)。

## 已实现功能

- **Block 协议**：文本/Todo/智能实体/图表/AI 流式/图片/代码七类块，独立 Isar 表 + 软删除 + 流式断点字段
- **数据迁移 v1→v2**：启动自动把旧版日记内容包装为 Block，幂等 + 迁移历史
- **快速收集面板**：首页 FAB → 底部半屏速记（富文本入口预留 + 图片/文档附件 + 麦克风预留），保存即写 Diary + Block
- **日历热力图**：按字数/Block 数/心情综合活跃度着色（P2.1）
- **记录块视图**：日记列表第三种视图，Block 卡片流（P1.6）
- **CRM 同步（Twenty）**：
  - 客户端：GraphQL 分页/增删改 + 429/5xx 指数退避
  - 本地缓存：CrmEntityCache（twentyId 索引/快照/软删）
  - 连接测试 / 全量同步 / 同步对账 / 跨对象本地搜索
  - 自定义业务对象：合同、回款、发票、提成
  - 设置 → CRM 同步页面（配置存 secure storage）
  - 服务端 Ktor 反向代理：`/api/twenty/*`（令牌经 `TWENTY_API_TOKEN` 注入）
- **模块开关**：设置页可独立启用/关闭 CRM/知识库/日历（P2.8）
- **附件管线**：Attachments/YYYY/MM + metadata.json 索引 + 孤立附件扫描清理（P1.9）
- **同步日志**：结构化 JSONL（INFO/WARN/ERROR，最近 500 条环形）
- **跨模块搜索**：日记/Block/CRM 统一检索服务（P1.7）
- **Rust 同步引擎骨架**：SyncEngine/Pull/Push/File/Conflict(LWW)/AI/VectorIndex(Mock) + FFI 契约（P1.3/P1.4）

## Twenty 连接与验证

```powershell
# 1. 本地配置（不入 git）：config\twenty.local.json（参考 twenty.example.json）
# 2. CLI 自检
dart run tool/twenty_sync_check.dart
# 3. 真实环境集成测试（会创建并删除一条测试公司）
flutter test --tags integration test/integration/twenty_integration_test.dart
# 4. 服务端代理
cd server
$env:TWENTY_BASE_URL='http://10.200.245.54:3000'
$env:TWENTY_API_TOKEN='<你的API Key>'
.\gradlew.bat run
```

## 测试与验证

- `flutter analyze`：0 问题
- `flutter test --exclude-tags integration`：36/36 全绿
- `flutter test --tags integration`：真实 Twenty 环境（连接/拉取/对账/建删闭环）
- `cargo test`：37/37
- `server gradlew test`：8/8

## 文档索引

- 架构设计：[轻智能终端-完整架构设计执行指导文档.md](docs/轻智能终端-完整架构设计执行指导文档.md)
- 开发计划与 WBS：[二次开发计划.md](docs/二次开发计划.md)
- 多 Agent 岗位配置：[开发岗位配置.md](docs/开发岗位配置.md)
- 进度跟踪：[开发进度.md](docs/开发进度.md)
