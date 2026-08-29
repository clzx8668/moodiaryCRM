# AI × 笔记 核心功能开发计划（修订版 · 结合 moodiaryCRM 现状）

> 修订时间：2026-08-29 · 依据原稿《AI × 笔记 核心功能开发计划.md》+ 用户指示 + 项目现状
> 原则：**不是全新开发**，而是「已实现能力增强 + 缺口补齐」，全部与现有模块融会贯通；
> 拿不定主意的决策点在文末「待讨论问题」清单，讨论确定后再执行。

---

## 〇、用户指示（本次修订的硬约束）

1. **Obsidian 入口**：首页 Tab 可新增一页专门渲染 Obsidian，也可考虑左侧抽屉显示
   Obsidian 文件目录树（二选一或结合，见 Q1）。
2. **快速收集不做复合 AI 提问**：快速收集保持「纯输入 + 附件 + 语音」；全局 AI 交流
   统一到 **AI 助手页**（`AiHomePage`）。
3. **其余模块与已实现功能匹配结合**，避免重复建设。

## 一、现状能力映射（原 8 模块 → 当前实现 → 修订动作）

| 原模块 | 当前项目现状 | 修订动作 |
| :-- | :-- | :-- |
| M1 快速收集+AI自动标签 | 快速收集已实现（模板/附件/语音）；**AI 自动标签未实现** | 按指示砍掉「快速收集内 AI 提问」；**AI 自动标签/摘要/分类**做成独立异步能力（见修订 M1） |
| M2 AI 任务队列 | **未实现**（无 ai_tasks 表/Worker） | 新建任务队列，作为自动标签/向量化/摘要的统一异步底座 |
| M3 详情页 AI 对话 | **已实现**：详情页底部输入条 → `source=ai` Block 持久化（role=user/assistant）+ 瀑布流气泡（`canvas_datasource.createChatBlock`） | 增强：📎 附加知识选择器、上下文注入、可选工具调用；**存储方案待讨论**（Q3） |
| M4 全局 AI 助理 | **已实现**：`AiHomePage`（独立会话表 `AiChatSession/AiChatMessageRecord`、RAG 知识库、引用溯源、联网开关**占位**） | 增强：真实联网搜索（M7）、Function Calling 工具（note_search/crm_query）、可选 FAB 快捷入口 |
| M5 向量搜索引擎 | **已实现**：`RagService` + Drift `BlockEmbeddings`（base64 f32）+ Rust `LocalVectorIndex`（余弦，trait 可替换） | 保留现有实现；Embedding 走现有可配 `AiProvider.embed`；**是否引入 sqlite-vec 待讨论**（Q2） |
| M6 CRM 工具 | **未实现**（CRM 本地仓库/表格已完善，但无 AI 可调工具） | 新建 `CrmToolService`：读工具优先；写工具 + 确认卡片**范围待讨论**（Q5） |
| M7 联网搜索 | **占位**：AI 助手页「联网：开/关」开关，提示"接入中" | 实现可插拔 `SearchSkill`（Bing 优先），注册 `web_search` 工具；**API/触发方式待讨论**（Q6） |
| M8 Obsidian 对接 | **未实现** | 只读 Vault + 文件树 + Markdown/双链渲染 + 向量索引；**入口形态待讨论**（Q1） |

## 二、修订后模块与优先级（建议）

| 优先级 | 模块 | 内容 | 与现状关系 |
| :-- | :-- | :-- | :-- |
| **P0** | M2 AI 任务队列 | `ai_tasks` 表 + 单例 Worker（pending/重试/离线等待） | 全新，异步底座 |
| **P0** | M1-AI 自动标签/分类/摘要 | 设置页「AI 处理设置」开关；快速收集/新建保存后提交任务，后台打标签+分类+摘要 | 挂在 M2 上 |
| **P1** | M7 联网搜索 | `SearchSkill` 抽象 + Bing 实现 + 设置页配置 + 助手页真实联网 | 替换占位开关 |
| **P1** | M4 全局 AI 助理增强 | Function Calling：`note_search` / `crm_query`（读）/ `web_search`；FAB 快捷入口（可选） | 增强现有 AiHomePage |
| **P1** | M3 详情页对话增强 | 📎 附加知识选择器（文件/笔记/CRM/Obsidian）+ 注入上下文；工具调用（与 M4 共用执行器） | 增强现有 SmartCanvas 对话 |
| **P2** | M8 Obsidian | 配置 Vault → 文件树 → 双链渲染 → 向量索引 → `obsidian_search` 工具 | 全新，入口先定 Q1 |
| **P2** | M6 CRM 写工具 | `crm_create/update/delete` + 确认卡片 + 操作日志 | 在 P1 读工具基础上扩展 |
| **P3** | M5 向量升级 | 按 Q2 结论：保留 LocalVectorIndex 或引入 sqlite-vec/LanceDB | 已有，仅升级 |

## 三、各模块落地要点（结合现有代码）

### 修订 M2 — AI 任务队列（P0，全新）
- 新表 `ai_tasks`（type: auto_tag/auto_summary/auto_classify/embedding/index；
  ref_id/ref_type；status: pending/processing/waiting_network/done/failed；retry）。
- 单例 `AiTaskQueueWorker`：App 启动初始化（`main.dart`），轮询/事件驱动，接入
  `connectivity_plus`（pubspec 已有）；指数退避 1s→2s→4s，上限 3 次。
- 设置页（`lib/pages/home/setting/`）加「AI 处理设置」区块：自动标签（默认开）、
  自动分类（默认开）、自动摘要（默认关，预留）。
- 快速收集保存（`quick_capture_saver.dart`）与新建日记保存后提交任务；回写标签/分类
  走现有 `IsarUtil.updateADiary`，全程异步不阻塞 UI。

### 修订 M1 — AI 自动标签/分类/摘要（P0，挂在 M2）
- Prompt 复用原稿思路（已有标签/分类列表 + 返回 JSON），新增
  `lib/features/ai/tagging_service.dart`（或并入 rag/ai 目录）。
- 注意与现有「模板 AI」（扩写/润色等）区分：模板是用户主动触发、流式；
  自动标签是保存后异步、非流式。

### 修订 M7 — 联网搜索（P1）
- `lib/features/ai/search/search_skill.dart` 抽象 + `bing_search_skill.dart`；
  设置页「AI 设置 → 联网搜索」（启用开关 / 引擎 / API Key / 测试连接）。
- AI 助手页把占位开关接到真实服务；结果格式化注入 system 上下文。
- 触发：手动 🔍 + AI 工具 `web_search`（需 M4 工具执行器）。

### 修订 M4 — 全局 AI 助理增强（P1）
- 在现有 `AiHomePage` 上扩展（不新建页面）：
  - 工具执行器 `lib/features/ai/tool_executor.dart`（Function Calling 循环：
    tool_calls → 执行 → 回填 → 再调用；DeepSeek OpenAI 兼容）；
  - 工具：`note_search`（复用 `GlobalSearchService`）、`crm_query`（读，复用
    `CrmLocalRepository`）、`web_search`（M7）；
  - 会话线程管理已具备（AiChatSession），补充多会话列表 UI 已有（历史话题）。
- FAB 全局入口：待讨论（Q4 附带：是否在桌面导航加独立入口）。

### 修订 M3 — 详情页对话增强（P1）
- 保留现有 `source=ai` Block 瀑布流（已持久化、已分区）；增强：
  - 📎 附加知识选择器：文件（file_picker 已有）/ 笔记（搜索多选）/ CRM 客户 / Obsidian；
  - 选中内容提取后注入上下文（复用 `RagService.buildContext` 思路）；
  - 工具调用与 M4 共用执行器。
- 存储是否迁移到独立会话表：**Q3 讨论**（当前 Block 方案与助手页会话表不统一）。

### 修订 M8 — Obsidian 对接（P2）
- 设置页「数据源 → Obsidian」：启用开关 + Vault 路径选择 + 索引状态 + 重新索引。
- 入口（Q1 定）：首页 Tab（桌面 NavigationRail 第 7 项）/ 左侧抽屉文件树 /
  详情页内嵌，需结合移动端底部导航拥挤度决定。
- 实现：`obsidian_service`（递归扫描 + 缓存 + watcher 监听）、`obsidian_parser`
  （`[[双链]]` 解析）、渲染复用 `MarkdownContentView` 扩展双链、向量化接入现有
  BlockEmbeddings 机制（source=obsidian）。
- 本期只读不写、不做双向同步。

### 修订 M6 — CRM 工具（P2）
- `CrmToolService`：读工具（query：entity/keyword/phone/id）返回格式化结果；
- 写工具（create/update/delete）返回「确认卡片」数据 → UI 确认 → 执行 →
  结果回填 AI；操作日志记 `SyncLogService`。

### 修订 M5 — 向量搜索（P3，已有）
- 保持 `RagService + BlockEmbeddings + Rust LocalVectorIndex`；trait 已依赖倒置，
  后续可平滑换 LanceDB/sqlite-vec；Q2 定是否本期换。

## 四、里程碑建议（讨论后调整）

```
第 1 轮：M2 任务队列 + M1 自动标签/分类/摘要（异步增强底座）✅
第 2 轮：M7 联网搜索 + M4 工具执行器（note_search / crm_query / web_search）
第 3 轮：M3 📎 附加知识 + 详情页工具接入；FAB/入口增强
第 4 轮：M8 Obsidian（入口先定 Q1）+ obsidian_search
第 5 轮：M6 CRM 写工具 + 确认卡片；M5 向量升级（Q2 结论）
```

## 五、待讨论问题清单（先定再执行）

- **Q1（Obsidian 入口形态）**：首页新增 Tab 页 vs 左侧抽屉文件树 vs 详情页内嵌？
  桌面 NavigationRail 已有 6 项、移动底部导航 6 项较满。倾向：
  A. 桌面端 NavigationRail 加第 7 项「Obsidian」；移动端底部导航改为「更多」收纳或抽屉；
  B. 桌面端左侧二级抽屉（贴近 Obsidian 风格），移动端隐藏；
  C. 两者结合（桌面抽屉 + Tab 快捷入口）。
- **Q2（向量搜索选型）**：保留现有 `LocalVectorIndex`（Rust 内存余弦，已工作）
  还是本期引入 sqlite-vec/LanceDB？Embedding 继续走现有可配 `AiProvider.embed`
  （OpenAI 兼容，可填通义 text-embedding-v3 端点），还是单独封装通义 SDK？
- **Q3（详情页对话存储）**：详情页对话现在存 `source=ai` Block（与笔记同表）；
  AI 助手页用独立会话表（AiChatSession）。是否把详情页对话也统一到会话表
  （多线程/标题/清理更优，但需迁移现有 Block 数据），还是保持 Block 方案
  （与笔记捆绑、展示自然）？
- **Q4（全局 AI 入口）**：AI 助手页已有底部导航 Tab。是否再加桌面 FAB/快捷键
  （⌘K 已能跳？）？「全局悬浮 FAB」与原稿一致还是去掉？
- **Q5（CRM 写工具范围）**：本期是否包含 CRM 写操作（create/update/delete +
  确认卡片），还是先只做读工具（query）？写操作确认卡片 UI 投入约 1-2 天。
- **Q6（联网搜索实现）**：Bing Search API（需 Key）是否可接受？还是优先接
  免费/无 Key 方案（如 DuckDuckGo HTML 解析，稳定性差）？自动搜索与手动 🔍 都做？
- **Q7（自动标签写入策略）**：AI 自动标签/分类是「保存后异步回写」（推荐），
  还是「保存前等待 AI 确认」？摘要功能本期做还是预留开关？
- **Q8（优先级最终确认）**：建议顺序 P0 队列+标签 → P1 联网+工具 → P1 附加知识 →
  P2 Obsidian → P2 CRM 写 → P3 向量升级，是否符合你的预期？

---

*本修订版为讨论稿，待 Q1-Q8 确定后固化并逐步实施；每模块实施后更新 `docs/开发进度.md`。*
