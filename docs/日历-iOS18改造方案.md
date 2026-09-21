# 日历页 iOS 18 改造方案（含远程 Hermes 接口契约）

> 生成：2026-09-22　分支：`feat/align-get-brain`　承接：批次 124（日历页走查修复）
> 参考：用户提供的 9 张「iPhone 日历使用指南」图（技巧 01/02/03/04/05/06/07/08）

---

## 0. 结论先行：怎么改

**新建特性模块 `lib/features/calendar/`，用新页面替换底部导航「日历」入口；旧页 `lib/pages/home/calendar/` 原样保留、不删不改，直到新页功能对齐再决定去留。**

理由：

| 方案 | 评价 |
| :-- | :-- |
| A. 直接改 `lib/pages/home/calendar/` | 上游目录，项目硬性规则「新功能代码放 `lib/features/`」；且现有 839 行页面要同时改月格手势、底部栏、时间轴、编辑器，改动面太大、回退困难 |
| B. **新建 `lib/features/calendar/`（采纳）** | 符合规则；旧页留作兜底，一行切回；领域层（`Schedule`/重复规则/提醒/待办聚合/活跃度）全部复用，不重复造 |
| C. 全部推倒重写 | 会把已跑通的重复规则、提醒调度、待办聚合、AI 抽取一起扔进风险区，不划算 |

**复用（不动）**：`features/schedule`（Schedule 实体、仓储、重复规则展开）、`features/reminder`（提醒引擎/调度）、`features/todo`（跨源待办聚合与勾选）、`features/activity`（活跃度）。
**新增**：日历（多日历 + 颜色）、地点、附件、时区、iOS 风 UI、Hermes 同步契约。

---

## 1. UI 结构与视觉规范

```
┌───────────────────────────────────────────────┐
│  ‹   2026年9月   ›        ☰  🔍  ⚙  ＋         │ ← 毛玻璃顶栏（BackdropFilter）
├───────────────────────────────────────────────┤
│  日 一 二 三 四 五 六                          │ ← 月网格（可捏合缩放）
│             1  2  3  4  5  6                  │   L0 小圆点（默认）
│   7  8  9 10 11 12 13                         │   L1 事件条
│  14 15 16 17 18 19 20                         │   L2 事件条＋标题时间
│  21 22 23 24 25 26 27                         │
├───────────────────────────────────────────────┤
│  9月25日 星期五 · 今天                         │ ← SliverPersistentHeader（吸顶）
├───────────────────────────────────────────────┤
│  全天  ▸ 妈妈生日 / 项目结项                    │
│ 08:00 ─────────────────────────────────────    │
│ 09:00 ┃ 项目进度会议            ┃ 工作         │ ← 事件卡：左色条=日历色
│       ┃ 📍 会议室 A  09:00-10:00              │
│ 10:00 ────────────● 现在 ────────────────      │ ← 当前时间红线（仅今天）
│ 11:00 ○ 提交设计稿给老板                        │ ← 提醒事项：空心圆 + 勾选框
├───────────────────────────────────────────────┤
│         ╭──────────────────────────╮           │
│         │ 今天 │ 日历 │ 收件箱     │           │ ← 底部胶囊分段（毛玻璃，悬浮）
│         ╰──────────────────────────╯           │
└───────────────────────────────────────────────┘
```

**视觉 token（`ios_calendar_theme.dart` 统一提供，贴在项目主题之上）**

| 项 | 取值 | 说明 |
| :-- | :-- | :-- |
| 圆角 | 卡片 12 / 容器 16 / 胶囊 22 | iOS 连续圆角观感 |
| 事件卡底色 | `日历色 @ 12% alpha` 叠 `surfaceContainerLow` | 淡色背景，不用纯色块 |
| 事件卡描边 | `日历色 @ 32%` 1px（仅 L2） | 缩放到标题档时出现 |
| 阴影 | `y=1, blur=3, black 6%` | 轻微、不做重投影 |
| 毛玻璃 | `BackdropFilter(sigmaX/Y: 24)` + `surface @ 70%` | 顶栏、底部胶囊、弹出面板 |
| 日历配色 | 工作 `#0A84FF`／生活 `#30D158`／家庭 `#FF9F0A`／旅行 `#BF5AF2`／个人 `#1E88E5`；今天 `#FF3B30` | iOS 系统色 |
| 字号 | 时间标签 11（等宽、`onSurfaceVariant`）；卡片标题 15 w600；副标题 12 | |

---

## 2. 五项核心交互的落地方式

| 截图技巧 | 落地 | 关键实现 |
| :-- | :-- | :-- |
| **01 月视图缩放** | 月格三档 `L0 圆点 → L1 事件条 → L2 标题+时间` | `GestureDetector.onScaleUpdate`（`scale` 累计值离散到 0/1/2，250ms 动画过渡）；行高与卡片内容随档位切换；与纵向滑动用 `onScaleStart/Update` 的 `pointerCount` 判定，避免和滚动打架 |
| **02 提醒事项进日历** | 时间轴下方「提醒事项」区 + 时间轴对应位置空心圆 | `TodoAggregator.load(date:)` 复用；`CheckboxListTile` 勾选走 `TodoToggleService`；时间轴用「最近整点插槽」把带时间的待办插进时间轴 |
| **03 出发提醒** | 事件编辑器「提醒」项 = 不提醒/准时/提前 N/出发时间（`travelTime`）；地点字段带定位图标 | 地点先落地为文本（`Schedule.location`），出发提醒本批只做**选项与文案**，真正的路线估算留待 Hermes 接入（见 §4 `/suggestions`） |
| **04 多日历 + 颜色** | 顶栏「日历管理」→ 底部面板：列表（色点＋名称＋共享人数）＋显示/隐藏眼睛＋新建（选色） | 新表 `calendars`；事件卡颜色取 `Schedule.calendarId → calendar.color` |
| **05 跨时区事件** | 编辑器加「时区」项（默认「跟随设备」），事件卡在跨时区时显示双时间 | 数据层 `Schedule.timeZoneId`（IANA，如 `America/New_York`）；本批只存不换算，展示层做 GMT 偏移提示 |
| **06 日程建议（Siri 式）** | 「收件箱」页签：待确认的日程建议卡（来源＋建议时间＋一键加入） | 本地先由 AI 分流/抽取产出草案（复用已有抽取链路），远端走 Hermes `/suggestions`；草案存 `Schedule(draft: true)`，确认后才进日历 |
| **07 事件加附件** | 编辑器「附件」区：图标＋文件名＋大小＋删除；点击调系统文件选择器 | `Schedule.attachments`（JSON）；本批用 `file_picker` 选文件并记录元信息（不做上传，上传走 Hermes `/attachments`） |
| **08 共享日历** | 日历管理面板里每个日历显示共享人与权限（允许编辑/公开日历） | 本批只做**只读展示位**（本地库字段 `sharedCount`/`isShared`），真正的共享同步属 Hermes 契约 §4 |

---

## 3. 数据模型（Drift schema v23）

### 3.1 新表 `calendars`

| 列 | 类型 | 说明 |
| :-- | :-- | :-- |
| `id` | TEXT PK | uuid v7 |
| `name` | TEXT | 工作 / 生活 / 家庭 … |
| `color` | INT | ARGB；卡片与色点同源 |
| `visible` | BOOL | 眼睛开关（false = 月格与时间轴都隐藏） |
| `isDefault` | BOOL | 新建事件默认落在这里（恰一个 true） |
| `source` | TEXT | `local` / `hermes` / `icloud`（订阅源，只读） |
| `sortOrder` | INT | 展示顺序 |
| `sharedCount` | INT | 共享人数（0 = 未共享，只读展示） |
| `deleted` / `createdAt` / `updatedAt` | | 软删除 + 同步时间戳 |

### 3.2 `schedules` 增列（全部可空，幂等 `ADD COLUMN`）

| 列 | 类型 | 用途 |
| :-- | :-- | :-- |
| `calendarId` | TEXT? | 归属日历；null = 默认日历 |
| `location` | TEXT? | 地点（截图里的定位图标） |
| `attachments` | TEXT(JSON) | `[{"name":"Q2项目方案.pdf","size":2516582,"path":"...","mime":"application/pdf"}]` |
| `timeZoneId` | TEXT? | IANA 时区；null = 跟随设备 |
| `draft` | BOOL | 日程建议草案（收件箱待确认） |

### 3.3 迁移（v22 → v23）

1. `createTable(calendars)`（`IF NOT EXISTS` 语义）；
2. 四个新列走 `_addColumnIfMissing`（幂等，历史中断的库也能打开）；
3. 播种：若 `calendars` 为空 → 建「工作 #0A84FF（默认）／生活 #30D158／家庭 #FF9F0A」；
4. 回填：`schedules.calendarId is null` → 默认日历 id；`draft` 默认 false；
5. 写 `app_metadata.calendar_migration_v23` 日志（幂等标记 + 影响行数）。

---

## 4. 远程 Hermes 接口契约

**定位**：本地 Drift 仍是唯一真相源（离线可用）；Hermes 是**可选的同步 + AI 建议**对端（跑在 `192.168.16.81:9119`，Basic Auth + Bearer）。
**原则**：离线优先 / 幂等 / 软删除墓碑 / 最后写入者胜（LWW，比 `updatedAt`，同刻比 `deviceId` 字典序）。

### 4.1 传输与认证

```
Base:   http://192.168.16.81:9119            （设置 → 日历 → Hermes 地址，可改）
Auth:   Authorization: Bearer <HERMES_TOKEN> （面板令牌，与 Dashboard 同一凭据体系）
Header: X-Moodiary-Device: <deviceId>        （安装级 uuid，用于冲突判定与审计）
        X-Moodiary-Client: moodiary-android/2.8.0 (build 1234)
Content-Type: application/json; charset=utf-8
```

### 4.2 端点

| 方法 | 路径 | 说明 |
| :-- | :-- | :-- |
| GET | `/api/calendar/calendars` | 拉取日历清单（含颜色/可见性） |
| GET | `/api/calendar/events?from=&to=&updatedSince=&cursor=` | 增量拉事件（`updatedSince` 用服务端时间；`cursor` 分页） |
| POST | `/api/calendar/events` | 新建（带 `Idempotency-Key`，重发不重复建） |
| PATCH | `/api/calendar/events/{id}` | 局部更新（只发改动字段；`If-Unmodified-Since` 保护并发） |
| DELETE | `/api/calendar/events/{id}` | 软删除（写墓碑） |
| POST | `/api/calendar/events/{id}/attachments` | 上传附件（`multipart/form-data`，字段 `file`） |
| GET | `/api/calendar/events/{id}/attachments/{attachmentId}` | 下载/预览附件 |
| POST | `/api/calendar/suggestions` | **AI 建议**：给一段自然语言/邮件文本，返回事件草案数组（技巧 06） |
| POST | `/api/calendar/travel-time` | 出发时间估算（技巧 03）：`{origin, destination, arriveBy}` → `{departAt, durationMin}` |
| GET | `/api/calendar/share/{calendarId}` | 共享成员与权限（技巧 08） |
| POST | `/api/calendar/wiki/sync` | 销售知识库 ↔ 日程互链（复用本机 AIwiki） |

### 4.3 载荷（事件）

```jsonc
{
  "id": "0192f0a1-...",              // 客户端生成 uuidv7，服务端原样保留（幂等键）
  "calendarId": "work",
  "title": "Q2 项目方案评审会",
  "notes": "带纸质资料",
  "location": "会议室 A",
  "start": "2026-05-06T14:00:00+08:00",   // RFC3339，带偏移
  "end":   "2026-05-06T15:30:00+08:00",
  "allDay": false,
  "timeZoneId": "Asia/Shanghai",          // 可空
  "repeat": { "type": "weekly", "interval": 1, "until": null },  // none|daily|weekly|monthly|yearly
  "remindOffsetMin": 15,                   // 可空；-1 = 出发时间提醒
  "priority": 2,
  "subtasks": [{ "text": "准备材料", "done": false }],
  "attachments": [
    { "id": "att-1", "name": "Q2 项目方案.pdf", "size": 2516582, "mime": "application/pdf" }
  ],
  "linkedDiaryId": "…",                    // 与本项目日记/块的关联（Hermes 只透传）
  "done": false,
  "deleted": false,
  "updatedAt": "2026-05-06T13:58:11+08:00",
  "rev": 7,                                // 服务端单调递增版本，用于 LWW 与游标
  "deviceId": "8f2c…"
}
```

**响应包**

```jsonc
{ "ok": true, "cursor": "eyJ…", "serverTime": "2026-05-06T14:00:00+08:00",
  "events": [ /* 事件数组，同上 */ ],
  "calendars": [ { "id": "work", "name": "工作", "color": "#0A84FF", "visible": true,
                   "isDefault": true, "sharedCount": 4 } ] }
```

**错误**

| HTTP | code | 含义 | 客户端行为 |
| :-- | :-- | :-- | :-- |
| 400 | `invalid_payload` | 字段不合法 | 记日志，不重试 |
| 401 | `unauthorized` | 令牌无效 | 标记同步失败，提示去设置页填令牌 |
| 409 | `conflict` | `If-Unmodified-Since` 失败 | 拉取该条最新版 → LWW 合并 → 重发 |
| 422 | `unprocessable` | 语义冲突（如 end < start） | 提示用户修 |
| 429 | `rate_limited` | 限流（面板 10 次/分钟/IP 同源） | 指数退避（1s→2s→4s，上限 5 分钟） |
| 5xx | — | 服务端故障 | 退避重试；本地照常可用 |

### 4.4 同步时序（客户端）

```
推送：本地 dirty 事件按 updatedAt 升序 PATCH/POST（串行，逐条 Idempotency-Key）
拉取：GET /events?updatedSince=<上次 serverTime>&cursor=… 循环到 cursor 为空
合并：不存在 → 插入；存在 → LWW（rev 更大者胜；相等则 updatedAt；再相等则 deviceId 字典序）
墓碑：deleted=true 且 rev 高于本地 → 本地软删（保留 30 天再物理清理）
触发：应用进入前台 / 下拉刷新 / 事件保存后 5s 去抖 / 「今天」页下拉
失败：写 sync_log（复用现有 SyncRecords 表），UI 只在设置页与同步角标提示，不打断使用
```

### 4.5 `/suggestions` 细节（技巧 06）

```jsonc
// 请求
{ "text": "【携程】您的航班 MU583 5月10日 10:30 上海虹桥T2 …",
  "hint": "flight",              // 可空：邮件/短信/网页
  "locale": "zh-CN", "timeZone": "Asia/Shanghai" }
// 响应
{ "ok": true, "suggestions": [
  { "kind": "flight", "title": "航班：MU583",
    "location": "上海虹桥 T2 → 北京首都 T3",
    "start": "2026-05-10T10:30:00+08:00", "end": "2026-05-10T13:00:00+08:00",
    "references": ["MU583", "5月10日 周五"], "source": "邮件（携程）",
    "confidence": 0.86 } ] }
```

客户端把每条 suggestion 落成 `Schedule(draft: true)`，进「收件箱」页签；用户点「添加到日历」才 `draft=false` 并计入同步。

---

## 5. 分批实施

| 批次 | 内容 | 验收 |
| :-- | :-- | :-- |
| **125.1 ✅ 已落地** | 数据层：`calendars` 表、`schedules` 增列、迁移 v23、`CalendarRepository`、`Schedule` 模型扩展、仓储映射 | `flutter test` 全绿（10 条新测试）；迁移幂等 |
| **125.2 ✅ 已落地** | iOS 风新页：毛玻璃顶栏 + 月网格（捏合三档）+ 吸顶日期头 + 24h 日时间轴 + 事件卡 + 底部「今天/日历/收件箱」胶囊 | 真机走查截图；`flutter test` 796 全绿 |
| **125.3** | 提醒事项并入（时间轴空心圆 + 下方 CheckboxListTile 区） | 勾选写回、跨源待办不丢 |
| **125.4** | 多日历管理与配色（新建/改色/隐藏） | 新日历 → 事件卡变色 → 月格圆点变色 |
| **125.5** | 事件编辑器重做（地点/时区/重复/提醒/附件） | 附件选文件后展示图标+名+大小；可删除 |
| **125.6** | Hermes 契约客户端 + 同步骨架（离线优先，LWW，sync_log） | 契约 JSON 往返单测；断网不崩 |

> **实况（2026-09-22）**：125.1 / 125.2 已落地，125.3 / 125.4 / 125.5 的**主体也已一并做完**
> （提醒事项区与时间轴空心圆、日历管理面板、事件编辑器含附件，均已通过自动化测试与真机走查），
> 剩下 **125.6 Hermes 客户端与同步**、跨时区换算、出发时间估算、共享日历、月网格随滚动折叠。

### 5.1 落地时的两个关键技术结论（别再踩）

1. **捏合手势不能放在滚动视图里**：把月网格放进 `CustomScrollView`/`SingleChildScrollView` 后，
   滚动视图的拖拽识别器会赢下手势竞技场，`onScaleUpdate` 永远收不到回调（已用最小用例复现）。
   现方案：网格放在滚动容器**外面**（`Column` 固定区），时间轴单独一个 `CustomScrollView`，
   日期头用它内部的 `SliverPersistentHeader` 吸顶。
2. **确认弹窗用 `showDialog` + `Navigator.pop`，别用 `Get.dialog` + `Get.back(result:)`**：
   后者在本页面上返回 `null`（真机表现为"点了删除没反应"），改用标准 API 后正常。

---

## 6. 风险与边界

- **捏合缩放与纵向滚动冲突**：用 `onScaleUpdate.pointerCount` 判定，单指走原有点击/滚动，双指才改档位；
- **iOS 观感 vs 项目现有深色 Material 主题**：保留项目主题色系统，只借 iOS 的**结构与质感**（圆角/毛玻璃/分组列表/胶囊分段），避免两套配色体系打架；
- **附件只存元信息**：本批不做上传（依赖 Hermes `/attachments` 与网络条件），先在本地记录路径与大小；
- **时区只存不换算**：跨时区展示先给「GMT±n」提示，真正换算跟随 Hermes 或后续批次；
- **不删旧页**：`lib/pages/home/calendar/` 保持可用，入口切换是一行代码，随时可退。
