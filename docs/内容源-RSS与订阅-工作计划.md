# 更多内容源：RSS / 订阅（工作计划）

> 状态：**计划待评审**　|　日期：2026-09-13　|　分支建议：`feat/align-get-brain` 上独立批次
> 定位：对标得到大脑的「内容源聚合」（得到课程 / 直播 / 博主订阅），先做**本地 RSS/Atom 订阅**，
> 保持「可选、默认关闭、本地优先、不做登录态抓取」的边界。

---

## 0. 一句话目标

让用户把**公开 RSS/Atom 源**加入 App，App 按低频周期拉取最新条目，自动提取正文并**增量入库**为笔记
（原文 + 来源链接保真），与既有「链接采集 / 图片速记 / 系统分享」共同构成「好记」入口矩阵。

---

## 1. 范围与边界

### 1.1 做（本期）

| 能力 | 说明 |
| :-- | :-- |
| 订阅源管理 | 新增 / 启用停用 / 删除；仅 RSS 2.0 与 Atom |
| 拉取与解析 | HTTP 拉取 + XML 解析（标题/链接/摘要/发布时间/正文） |
| 增量入库 | 以条目 `guid/link` 去重；只入库新条目；每源每轮上限 N 条 |
| 正文提取 | 摘要不足时抓条目链接正文（复用链接采集 + SPA WebView 兜底） |
| 入口 | 设置 → 内容源（管理）；条目落笔记列表 |
| 自动刷新 | 启动/回前台低频刷新（复用 `DigestScheduler` 模式），默认关闭 |

### 1.2 不做（明确边界）

- 不做登录态抓取（微博/小红书/知乎等需 Cookie 的平台）——合规与风控风险高；
- 不做批量高频爬取；不做付费墙/全文绕过；
- 不引入服务器；不做云端聚合；
- 「博主订阅」若指平台账号级订阅，一律走 RSS 桥，本 App 只消费 RSS。

### 1.3 可选（后续）

- 微信公众号历史文章（需登录态，风险高，默认不做）；
- 与「每日回望」联动：把当日订阅条目纳入回望素材；
- 知识库自动归入：订阅条目按主题归入知识库集合。

---

## 2. 数据与存储设计（不新增 Drift 表）

### 2.1 订阅源：PrefUtil JSON

key：`feedSources`（需加入 `PrefUtil` 允许列表）

```json
[
  {
    "id": "uuid",
    "url": "https://example.com/feed.xml",
    "title": "示例源",
    "enabled": true,
    "lastFetchedAt": 1789000000000,
    "lastItemKeys": ["guid-or-link-hash"]
  }
]
```

### 2.2 条目入库：复用 Diary + Block

- Diary：`title = 条目标题`，`contentText = 正文/摘要`，`tags += ['订阅', 源标题]`；
- Block（原文保真）：`source=initial`，`captureType='feed'`，`sourceUrl=条目链接`；
- 去重键：`feedItemKey = sha1(guid ?? link)`，写入源配置 `lastItemKeys` + Block meta 双保险。

> `BlockMeta` 为 JSON 自由字段，新增 `feedId`/`feedItemKey` 不需要 Drift schema 变更。

---

## 3. 模块与文件规划

```
lib/features/feed/
├── feed_models.dart        # FeedSource / FeedItem / FeedFetchResult
├── feed_parser.dart        # 纯函数：RSS2 / Atom 解析、日期归一、去重键
├── feed_service.dart       # 拉取 + 解析 + 增量过滤（不落库）
├── feed_saver.dart         # FeedItem → Diary + Block（原文/来源保真）
├── feed_scheduler.dart     # 低频自动刷新（复用 DigestScheduler 模式）
└── feed_settings_page.dart # 内容源管理页（新增/启用/删除/手动刷新）
```

| 复用资产 | 用途 |
| :-- | :-- |
| `LinkCaptureService` / `WebRenderService` | 摘要不足时抓正文 + SPA 兜底 |
| `LinkCaptureSaver` 模式 | 原文 + `sourceUrl` 保真落库 |
| `DigestScheduler` 模式 | 启动/回前台的低频自动任务 + PrefUtil 开关 |
| `KbCollectionService` | 可选：条目按主题归入知识库 |

---

## 4. 分批实施计划

| 批次 | 主题 | 内容 | 验收 |
| :-- | :-- | :-- | :-- |
| **57** | 解析与模型（纯函数） | `FeedSource/FeedItem`、RSS2/Atom 解析、时间与去重键；单测覆盖 RSS/Atom/异常 | analyze 0 error；新增单测全绿 |
| **58** | 拉取 + 增量 + 落库 | `FeedService.fetch`、`FeedSaver`（Diary+Block+sourceUrl）、去重；单测覆盖增量/重复/上限 | 单测全绿；手测源可入库 |
| **59** | 入口与管理页 | 设置 → 内容源（列表/新增/启用/删除/立即刷新）；条目在首页可见 | MuMu 走查：新增源→刷新→列表出现条目 |
| **60** | 自动刷新与打磨 | `FeedScheduler`（默认关、低频、失败静默）、与回望联动（可选）、UI 打磨 | analyze/test/构建通过；真机走查通过 |

---

## 5. 关键实现要点

1. **解析零依赖**：RSS/Atom 均为 XML，用正则 + 实体反转义覆盖标题/链接/摘要/时间；正文复用链接采集（HTTP → 必要时 WebView）。
2. **增量与幂等**：源配置 `lastItemKeys`（上限 200）+ Block meta `feedItemKey` 双保险，重复刷新不产生重复笔记。
3. **低频克制**：每源默认 6 小时一次、每轮最多 10 条；启动/回前台触发，不常驻后台；默认关闭。
4. **失败不打扰**：单源失败写「同步日志」，管理页显示状态，不弹错误。
5. **合规**：只消费公开 RSS；只存标题/摘要/链接与个人本地正文副本；不做登录态抓取与高频请求。
