# moodiaryCRM 交接文档（Trae 续接用）

> 生成时间：2026-08-31（批次 25-29 收敛后更新）· 分支 `feat/local-crm-v1` ·
> 版本 `2.11.0+94`（tag `v2.11.0`，远端已同步）· 工作区干净
>
> 本文件是**新对话一站式衔接**：Trae 打开本仓库后先读本文件 + `AGENTS.md` + `docs/开发进度.md` 尾部，
> 即可直接继续开发。本文件自包含当前进度、验证基线、已知边界与下一步候选。

---

## 1. 项目速览

- **产品**：MoodiaryCRM——本地优先的智能日记 + 轻量 CRM（AI 增强）。
- **技术栈**：Flutter 3.41.0 / Dart 3.11（`.fvmrc`）、GetX、Drift(SQLite)、
  flutter_rust_bridge 2.11.1（Rust 1.96，`rust/` crate `moodiary_rust`）、
  pluto_grid 8.1（CRM 智能表格）、Ktor 3 + Kotlin 2.0.21 + MongoDB（`server/` 脚手架）。
- **目标平台**：Windows 桌面 + Android（iOS/macOS 骨架存在，未重点验证）。
- **主要目录**：
  - `lib/features/`：新功能代码（block / smart_canvas / crm / ai / rag / quick_capture /
    search / command_palette / voice / sync_events / sync_log / attachment 等）；
  - `lib/pages/`：页面（home 首页 / edit 编辑器 / diary_details 旧详情等）；
  - `lib/components/`：共享组件（diary_card 三视图卡片、diary_tab_view 首页列表等）；
  - `lib/persistence/`：Drift 表与 IsarUtil（兼容层，仍叫 IsarUtil）；
  - `rust/src/api/`：FFI 契约（ffi_api.rs、event_bus.rs、sync_events.rs）；
  - `docs/`：架构与进度文档（本文件、开发进度.md、二次开发计划.md 等）。

## 2. 环境与命令（Windows PowerShell）

```powershell
# flutter 命令在本沙箱需提权运行（写入 SDK 缓存）
& 'D:\flutter\3.41.0\bin\flutter.bat' pub get
& 'D:\flutter\3.41.0\bin\flutter.bat' analyze --no-pub
& 'D:\flutter\3.41.0\bin\flutter.bat' test --exclude-tags integration --no-pub
& 'D:\flutter\3.41.0\bin\flutter.bat' build windows --debug
& 'D:\flutter\3.41.0\bin\flutter.bat' build apk --debug
cd rust; cargo test
```

- pub 源：本机默认中国镜像会把 `flutter_inappwebview` 解析到不兼容新版；`pubspec.yaml`
  已用 `dependency_overrides` 锁定（js 0.6.7 / web 1.1.1 / inappwebview 全家 beta.2）。
- MuMuPlayer 12 真机模拟：`adb` 自动注册 `emulator-5556`；掉线时
  `adb connect 127.0.0.1:7555`。项目 `abiFilters` 含 `arm64-v8a, x86_64`。
- Windows 构建前先关闭运行中的 `mood_diary.exe`（否则锁 PDB/exe）。
- frb 绑定变更后：`flutter_rust_bridge_codegen generate`（本机 2.11.1 已装，nightly 就绪）。

## 3. 核心架构要点（改代码前必读）

### 3.1 双模态数据模型（Diary + Block）
- **Diary** = 一条记录集合（标题/正文/标签/分类/心情）；**Block** = 挂在该日记下的
  子笔记/卡片（`block.diaryId`，含 text / todo / image / chart / smartEntity / aiStream）。
- `Diary.content` 是 Block 的**聚合投影**（`MarkdownProjection.aggregate` 排除 AI 对话块）；
  详情页打开时 `ensureInitialBlock` 把正文物化为 `source=initial` 块。
- 详情页 = `SmartCanvasPage`（`lib/features/smart_canvas/`），块列表已 SliverList 虚拟化、
  桌面 720px 阅读宽度、长文折叠（高度限制 + 渐变遮罩 + 箭头按钮）。

### 3.2 全局唯一 Markdown 编辑器（重要，勿再引入第二套）
- **`EditPage`（`lib/pages/edit/`）是唯一日记/子笔记编辑器**，所有入口统一走
  `EditArguments`（`lib/pages/edit/edit_arguments.dart`）：
  - 新建：`EditArguments(type, categoryId)`；
  - 整篇编辑：`EditArguments(diary)`；
  - 子笔记编辑：`EditArguments(diary, blockId, initialContent)`；
  - 追加子笔记：`EditArguments(diary, blockId: '')`；
  - 笔记整合：`EditArguments(diary, consolidate: true)`（保存融合全文后软删子笔记，
    保留 AI 对话块）。
- **标题 = 集合标题**：任何入口编辑 AppBar 标题都写回 `Diary.title`，与正文互不干扰。
- 已删除冗余 `BlockMarkdownEditorPage`，不要再新建独立编辑器。

### 3.3 首页三视图（列表 / 网格 / 块）
- 三视图共用 `DiaryTabViewLogic.diaryList` 同源数据；排序/标签筛选三视图一致。
- **多选删除**：长按（移动）/右键（PC）进入多选，操作条为
  `SliverPersistentHeader(pinned)` 吸顶（仅激活时出现、行高 32 紧凑）；
  删除走回收站 + 软删子块 + `DiaryLogic.refreshAll`。
- 卡片只显示正文预览（不显示标题）。

### 3.4 CRM（本地优先 + Twenty 对齐）
- 本地对象：客户/联系人/机会/合同/产品/报价/回款计划/回款/发票/质保/售后/跟进/提醒。
- 表格 `CrmSmartTable`（pluto_grid）：复选框首列、列设置/宽度记忆、原位编辑失焦保存、
  详情右侧栏、新增表单、CSV 导出、批量删除；`BusinessObjectsPage` 复用同一 Tab。
- Twenty 同步：`CrmSyncService` + GraphQL（token 存 secure storage，不入 git）。

### 3.5 Rust / FFI
- `rust/src/api/ffi_api.rs`：同步进度/AI/文件三条事件流（`sync_progress_stream` 等）；
- **优雅收尾**：`event_bus::shutdown_all()` drop 发送端 → 循环退出；
  `shutdown()` FFI 已生成；退出清理顺序 `rust_ffi.shutdown()` → `RustLib.dispose()`。

### 3.6 AI 能力
- 多服务商（DeepSeek 等）OpenAI 兼容；`AiCompositeProvider` 主备切换；
  模板 AI（流式→转正）、详情页 AI 对话（持久化 `source=ai` 块 + 瀑布流气泡）、
  AI 助手页（知识库 RAG + 联网开关 + 引用溯源）。
- **AI×笔记（P0-P3 五轮已全部完成 + 批次27-29 增强）**：AI 任务队列 + 自动标签/分类/
  自动摘要（`ai_tasks` + `AiTaskQueueWorker` + `tagging_service`，摘要写入
  `Diary.summary`）；多引擎联网搜索（DDG 默认 / SearXNG / Tavily / Bing / Custom）；
  `ToolExecutor` 工具集（`note_search` / `crm_query` /
  `crm_create|update|delete`（写需确认卡片，`onCrmWriteConfirm` 回调）/
  `web_search` / `obsidian_search`）；详情页 📎 附加知识选择器（文件/笔记/CRM/Obsidian）；
  Obsidian 只读接入（首页 tab 子页 + 文件树抽屉 + 双链跳转 + 30s 轮询监听 +
  手动「向量化到知识库」）。
- **语音识别**：`speech_to_text 7.4.0`（Android 系统语音 / Windows SAPI）；
  `lib/features/voice/speech_service.dart`；详情页/快速收集长按「按住 说话」识别填入输入框。

## 4. 当前进度（自 v2.9.0 起已完成）

| 批次 | 内容 |
| :-- | :-- |
| 12 | 编辑器统一 + 笔记整合 + 首页去标题；追加空白编辑器；展开全文响应修复 +
      主流折叠交互；标题写回集合标题；三视图多选 + 操作条吸顶紧凑 |
| 13 | 卡片点击被 SelectionArea 拦截修复；Rust `shutdown` 优雅收尾（frb 重新生成）；
      全局 ⌘K 命令面板（跨日记/子笔记/CRM） |
| 14 | ⌘K 增强（分组 / ↑↓+Enter / 最近记录）；语音识别接入；详情页输入条桌面宽度对齐；
      CRM 对象管理页批量删除 |
| 15 | 溢出修复：输入条功能栏可收缩（11px）、AI 助手上下文栏横向滚动（54px）、
      AI 助手空态可滚动（10px） |
| 16 | ⌘K 关键词高亮/新建命令；语音按住说话；桌面右键菜单；CRM 字段校验 |
| 17 | CRM 商机看板视图（Kanban，按阶段分列拖拽改阶段） |
| 18 | 知识库可索引内容拓宽（RAG 覆盖日记/子笔记/CRM/更多格式） |
| 19 | AI×笔记 P0：M2 任务队列 + M1 自动标签/分类（异步底座） |
| 20 | AI×笔记 P1：M7 多引擎联网 + M4 工具执行器（note_search/crm_query/web_search） |
| 21 | AI×笔记 P1：M3 详情页 📎 附加知识 + 工具协商 |
| 22 | AI×笔记 P2：M8 Obsidian（tab 子页 + 文件树抽屉 + 双链 + obsidian_search） |
| 23 | AI×笔记 P2：M6 CRM 写工具 + 确认卡片（最后一轮，**计划收官**） |
| 24 | Windows 显示/滚动态收敛（debug 首帧断言兜底 + 间隙 0 + 目录树 180px）+ 宽度拖动持久化 |
| 25 | 输入框打磨（去胶囊小圆角/右对齐/宽度统一 760）+ 心情回写集合并即时刷新 + 目录树默认折叠 |
| 26 | 日记页动态配色（标签颜色/自定义背景色/柔和背景+AppBar 微着色）+ 分类/标签创建弹窗色块 |
| 27 | 工程收敛（bump `2.11.0+94` / tag / push）+ 自动摘要真实实现（`Diary.summary`） |
| 28 | Obsidian 三件套：30s 轮询监听 + Vault 向量化到知识库 + 📎 附加知识接入 Obsidian |
| 29 | 子笔记编辑时分类/标签回写集合 + 多端一致性复查（PC 右键分类重命名/删除） |

**验证基线**：`flutter analyze` 0 error（仅存量 2 条 info：
`prefer_if_null_operators` crm_entity_detail_view.dart:554、`CorePalette` theme_util.dart:337）；
`flutter test` 207/207；`cargo test` 18/18；`flutter build windows --debug` ✅；
`flutter build apk --debug` ✅。

## 5. 已知边界 / 待办

### 已知边界
- 标题/心情/分类/标签已按「集合标题」原则在子笔记/追加/整合编辑时回写集合；
  「日记信息」里的日期/天气暂不随子笔记编辑回写。
- 语音识别依赖设备系统语音服务（Android 需 Google 语音、Windows 需系统语音识别）；
  MuMu 模拟器上可能不可用。
- 详情页卡片正文关闭文本选择（`selectable: false`）以保点击进编辑器，复制走卡片按钮。
- Android 构建有 NDK 版本 warning（28.0 vs 插件期望 28.2），不影响构建。
- Obsidian 只读接入：已有 30s 轮询监听 + 「向量化到知识库」（手动触发）；
  无双向同步；大 Vault 首次扫描较慢。
- CRM 写工具仅落本地库（不自动推 Twenty 远端），操作日志在「同步日志」页可见。
- Windows 控制台偶现 `accessibility_bridge.cc` 报错为 Flutter 引擎级无害日志
  （3.44+ 已修，可忽略或升级 SDK）；debug 多 tab 偶发滚动断言为旧架构特性，release 不崩。

### 下一步候选（按建议顺序）
1. **多端一致性持续细化**（本轮已修分类右键）：剩余桌面 hover/右键/手势细节。
2. **Obsidian 增强（可选）**：向量化改自动（文件变化即增量索引）、双链反向索引。
3. **CRM 深化（纯本地，Twenty 暂停）**：回款/发票/提成字段表单校验、合同金额联动、
   本地统计看板。
4. **RAG/M5 升级**：`LocalVectorIndex` 平滑替换 LanceDB（P3 预留，需新增依赖，单独排期）。
5. **新话题细节开发**：由用户指定方向（首页/详情页/编辑页/快速收集等）。
6. **版本收敛**：下一轮收尾时 bump + tag + push。

## 6. 硬性规则（沿用 AGENTS.md）
1. 新功能代码放 `lib/features/` 或 `rust/src/` 新模块，不散落进上游 `lib/pages/`；
2. 分支 `feat/<任务ID>`，提交规范 `<type>(<scope>): <subject>`；
3. 测试门禁：改 Rust 必须 `cargo test`；改 Flutter 必须 `flutter analyze`；
   改 server 必须 `gradlew test`；
4. Drift / json_serializable 模型改动后必须 `dart run build_runner build --delete-conflicting-outputs`；
5. 不随意放宽上游 lock 版本约束；新增依赖需主协调批准；
6. 涉及数据迁移的变更必须幂等 + 写迁移日志；
7. 每轮完成更新 `docs/开发进度.md`。
