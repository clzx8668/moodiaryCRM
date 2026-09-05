# AI × 笔记 核心功能开发计划（定稿 · 结合 moodiaryCRM 现状）

> 定稿时间：2026-08-29 · 依据原稿 + 用户两轮指示 + 项目现状
> 状态：**Q1-Q8 决策已全部确认，进入按优先级执行阶段**

---

## 〇、已确认决策（Q1-Q8）

| # | 决策点 | 结论 |
| :-- | :-- | :-- |
| Q1 | Obsidian 入口 | 首页顶部 tab 行（现仅「全部」+ 分类）预设**常驻「Obsidian」子页**：
       设置页配置本地 Vault 目录并开启开关后才显示；Obsidian 子页内**右侧抽屉**
       显示文件夹目录树 |
| Q2 | 向量选型 | **保留现有** Rust 内存余弦（`LocalVectorIndex` + Drift `BlockEmbeddings`），
       够用先用；trait 已依赖倒置，后续可平滑换 LanceDB/sqlite-vec |
| Q3 | 详情页对话存储 | **维持 Block 方案**（`source=ai` + role），不统一到独立会话表 |
| Q4 | 全局 AI 入口 | 已有底部导航 Tab（`AiHomePage`），**不做**桌面 FAB / 额外快捷键入口 |
| Q5 | CRM 工具 | **读 + 写一起做**：`crm_query` 读；`crm_create/update/delete` 写 +
       确认卡片 + 操作日志 |
| Q6 | 联网搜索 | 多引擎可选：**DuckDuckGo(Free) 默认零配置**；可选 SearXNG(填 URL) /
       Tavily(填 Key) / Bing(填 Key) / Custom(填 Endpoint+Key)；设置页带「测试连接」 |
| Q7 | 自动标签 | **保存后异步回写**（不阻塞保存）；摘要功能默认关、留开关 |
| Q8 | 优先级 | P0 队列+标签 → P1 联网+工具 → P1 附加知识 → P2 Obsidian → P2 CRM 写 →
       P3 向量升级，符合预期 |

**附加指示**：快速收集维持现状（纯输入 + 附件 + 语音），**不做复合 AI 提问**；
所有 AI 交流统一到 `AiHomePage`（AI 助手页）。

## 一、现状能力映射（原 8 模块 → 当前实现 → 修订动作）

| 原模块 | 当前项目现状 | 修订动作 |
| :-- | :-- | :-- |
| M1 快速收集+AI自动标签 | 快速收集已实现（模板/附件/语音）；AI 自动标签未实现 | 快速收集**维持现状**；AI 自动标签/分类/摘要做成独立异步能力 |
| M2 AI 任务队列 | 未实现 | 新建 `ai_tasks` 表 + 单例 Worker（异步底座） |
| M3 详情页 AI 对话 | 已实现（`source=ai` Block 瀑布流 + 持久化） | 增强：📎 附加知识选择器 + 上下文注入 + 工具调用；存储保持 Block |
| M4 全局 AI 助理 | 已实现 `AiHomePage`（会话表/RAG/引用溯源；联网占位） | 增强：真实联网（M7）+ 工具执行器（note_search/crm_query/web_search）；入口不变 |
| M5 向量搜索引擎 | 已实现（RagService + BlockEmbeddings + Rust LocalVectorIndex） | **保留现有**，本期不换 sqlite-vec |
| M6 CRM 工具 | 未实现 | 新建 `CrmToolService`：读 + 写（确认卡片）+ 操作日志 |
| M7 联网搜索 | 占位开关 | 实现多引擎 `SearchSkill`（DuckDuckGo 默认） |
| M8 Obsidian 对接 | 未实现 | 只读 Vault + 文件树抽屉 + Markdown/双链渲染 + 向量索引 |

## 二、模块与优先级（已确认）

| 优先级 | 模块 | 内容 | 与现状关系 |
| :-- | :-- | :-- | :-- |
| **P0** | M2 AI 任务队列 | `ai_tasks` 表 + 单例 Worker（pending/重试/离线等待/手动重试） | 全新，异步底座 |
| **P0** | M1-AI 自动标签/分类/摘要 | 设置页「AI 处理设置」开关（标签默认开/分类默认开/摘要默认关）；
       快速收集与新建保存后提交任务，异步回写标签/分类/摘要 | 挂在 M2 上 |
| **P1** | M7 联网搜索 | 多引擎 `SearchSkill`（DDG 默认 / SearXNG / Tavily / Bing / Custom）+
       设置页配置与测试连接；助手页真实联网 | 替换占位开关 |
| **P1** | M4 全局 AI 助理增强 | Function Calling：`note_search` / `crm_query`（读）/ `web_search`；
       工具执行器；会话线程沿用现有 | 增强现有 AiHomePage |
| **P1** | M3 详情页对话增强 | 📎 附加知识选择器（文件/笔记/CRM/Obsidian）+ 注入上下文；
       工具调用与 M4 共用执行器 | 增强现有 SmartCanvas 对话 |
| **P2** | M8 Obsidian | 首页 tab 行「Obsidian」子页（配置+开关后显示）+ 右侧抽屉文件树 +
       双链渲染 + 向量索引 + `obsidian_search` 工具 | 全新 |
| **P2** | M6 CRM 工具 | `crm_query`（读）+ `crm_create/update/delete`（写，确认卡片）+
       操作日志 | 在 P1 读工具基础上扩展写 |
| **P3** | M5 向量升级 | 保留现有；trait 可替换（后续 LanceDB/sqlite-vec） | 已有，仅升级预留 |

## 三、各模块落地要点（结合现有代码）

### 修订 M2 — AI 任务队列（P0，全新）
- 新表 `ai_tasks`（type: auto_tag/auto_classify/auto_summary/embedding/index；
  ref_id/ref_type；status: pending/processing/waiting_network/done/failed；retry_count；
  error_message；created_at/updated_at；索引 status、ref）。
- 单例 `AiTaskQueueWorker`：`main.dart` 启动初始化；轮询/事件驱动；接入
  `connectivity_plus`（已有）；指数退避 1s→2s→4s，上限 3 次；网络恢复批量
  waiting_network→pending；设置页可查看失败任务并手动重试。
- 设置页（`lib/pages/home/setting/`）新增「AI 处理设置」区块。
- 提交点：快速收集保存（`quick_capture_saver.dart`）、新建/编辑日记保存
  （`EditLogic.saveDiary`）、CRM 保存（可选）。全程异步不阻塞 UI。

### 修订 M1 — AI 自动标签/分类/摘要（P0，挂在 M2）
- `lib/features/ai/tagging_service.dart`：Prompt 含已有标签/分类列表，返回 JSON
  `{"tags":[],"new_tags":[],"category":"","summary":""}`；解析后回写
  `IsarUtil.updateADiary`。
- 与「模板 AI」（扩写/润色等，用户主动流式）区分：自动标签为保存后异步非流式。

### 修订 M7 — 联网搜索（P1）
- `lib/features/ai/search/search_skill.dart`（抽象：id/displayName/search/validateConfig）
  + `duckduckgo_search_skill.dart`（默认，零配置）+ `searxng_search_skill.dart` +
  `tavily_search_skill.dart` + `bing_search_skill.dart` + `custom_search_skill.dart`。
- 设置页「AI 设置 → 联网搜索」：启用开关 + 搜索引擎下拉（DDG 默认）+ 按引擎显示
  URL/Key 输入 + 「测试连接」。
- AI 助手页占位开关接真实服务；结果格式化注入 system 上下文。
- 触发：手动 🔍 + AI 工具 `web_search`。

### 修订 M4 — 全局 AI 助理增强（P1）
- 在现有 `AiHomePage` 上扩展（不新建页面、不加 FAB）：
  - `lib/features/ai/tool_executor.dart`：Function Calling 循环（DeepSeek OpenAI 兼容：
    tool_calls → 执行 → 回填 → 再调用）；
  - 工具：`note_search`（复用 `GlobalSearchService`）、`crm_query`（读，复用
    `CrmLocalRepository`）、`web_search`（M7）；
  - 会话线程管理沿用现有 AiChatSession（历史话题 UI 已有）。

### 修订 M3 — 详情页对话增强（P1）
- 保留 `source=ai` Block 瀑布流；增强：
  - 📎 附加知识选择器：文件（file_picker）/ 已有笔记（搜索多选）/ CRM 客户 / Obsidian；
  - 选中内容提取后注入上下文（复用 `RagService.buildContext` 思路）；
  - 工具调用与 M4 共用执行器。

### 修订 M8 — Obsidian 对接（P2）
- **入口**：首页顶部 tab 行（`diary_view.dart` 的分类 tab 行）预设「Obsidian」常驻子页；
  设置页「数据源 → Obsidian」配置 Vault 路径 + 启用开关，开启后 tab 显示。
- Obsidian 子页内：**右侧抽屉**（`Drawer`/`EndDrawer`）显示文件夹目录树；主区
  Markdown 渲染（复用 `MarkdownContentView` 扩展 `[[双链]]` 解析跳转）。
- 实现：`obsidian_service`（递归扫描 + 缓存 + watcher 监听）、`obsidian_parser`；
  向量化接入现有 BlockEmbeddings 机制（source=obsidian）；注册 `obsidian_search` 工具。
- 本期只读不写、不做双向同步。

### 修订 M6 — CRM 工具（P2）
- `CrmToolService`：`crm_query`（entity/keyword/phone/id）读，返回格式化结果；
- `crm_create/update/delete`：返回「确认卡片」数据 → UI 确认 → 执行 →
  结果回填 AI；操作日志记 `SyncLogService`。
- 确认卡片 UI 组件（`lib/features/crm/widgets/`）。

### 修订 M5 — 向量搜索（P3，已有）
- 保持 `RagService + BlockEmbeddings + Rust LocalVectorIndex`；后续可平滑替换。

## 四、里程碑（按 P0→P3 顺序执行）

```
第 1 轮：M2 任务队列 + M1 自动标签/分类/摘要（异步增强底座）✅
         （2026-08-29 已完成：标签/分类已实现，摘要开关预留）
第 2 轮：M7 联网搜索 + M4 工具执行器（note_search / crm_query / web_search）
         （2026-08-29 已完成：多引擎搜索 + 设置页配置 + 手动🔍 +
           completeChat 工具协商 + 3 工具；CRM 写工具待第 5 轮）
第 3 轮：M3 📎 附加知识 + 详情页工具接入
         （2026-08-29 已完成：文件/笔记/CRM 选择器 + 附加知识注入 + 详情页工具协商；
           Obsidian 资料待第 4 轮接入）
第 4 轮：M8 Obsidian（tab 子页 + 右侧抽屉文件树 + 双链 + obsidian_search）✅
         （2026-08-30 已完成：启用开关 + Vault 路径配置 + 递归扫描 + 文件树抽屉 +
           Markdown/双链渲染 + obsidian_search 工具；向量索引留后续增强）
第 5 轮：M6 CRM 写工具 + 确认卡片；M5 保持现状 ✅
         （2026-08-30 已完成：crm_create/update/delete 工具 + 确认卡片
           （取消则回填 AI，未注册回调安全拒绝）+ SyncLogService 操作日志；
           AI 助手页与详情页两处链路接入；测试 198 全绿 + 双端构建通过。
           AI×笔记 P0-P3 五轮全部完成）
```

## 五、执行约定

1. 每轮完成后更新 `docs/开发进度.md` 并提交（`feat/<任务ID>` 分支规范）；
2. 新增依赖需确认（本期可能新增：联网搜索/任务队列复用已有 dio/connectivity_plus；
   Obsidian 文件监听用 `watcher` 或自实现轮询；不引入 sqlite-vec）；
3. 所有 AI 功能受「模块开关」控制，关闭后应用完全可用（渐进增强原则）。

---

## 六、G 系列（对标得到大脑）状态

> 2026-09-05 立项：P0–P3 五轮（M1–M8）已全部完成并收尾为 v2.18.1+104；
> 后续 AI 相关开发转入 G 系列，总纲与决策见《对标得到大脑-产品闭环与开发指导.md》。

| G 轮 | AI 相关内容 | 状态 |
| :-- | :-- | :-- |
| G0 | 范式重排（移动端 Get 式底部栏 + 聊一聊入口） | 完成（批次 38/38-1） |
| G1 | 链接采集（识别/提取/平台服务/保真落库/快速收集入口） | 完成（批次 39） |
| G2 | AiSkill 技能（点评/发芽/拷问/打磨成稿）+ 作品层 WORKS | 完成（批次 40） |
| G3 | 主题知识库集合、智能关联（建议制）、DIGEST 日报/周报 | 引擎完成（批次 41），UI 关联/多类型待续 |
| G4 | CLI/MCP/生态（可选） | 未开始 |

**既有决策增补（D 系列）**

| # | 决策点 | 结论 |
| :-- | :-- | :-- |
| D9 | 四大技能是否全做 | 全做；点评/发芽/拷问走新框架，润色与打磨成稿合并进作品层 |
| D10 | 知识库与分类关系 | 共存三层：分类=固定树、标签=扁平、知识库=灵活主题集合（挂现有 KnowledgeBases） |
| D12 | 智能关联时机 | 保存后异步入队 + 去重，UI 先“建议后确认”，不自动写死 |
| D13 | 日报形态 | 静默生成，可选通知，不打断工作 |
