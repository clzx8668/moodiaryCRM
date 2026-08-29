# AI × 笔记 核心功能开发计划

---

## 〇、项目总览

| 项 | 内容 |
|:---|:---|
| **产品** | Moodiary — Windows 11 桌面端 |
| **技术栈** | Flutter + Drift(SQLite) + sqlite-vec + DeepSeek API + FFI(Rust) |
| **AI 模型** | DeepSeek（可配置），Embedding 用通义 text-embedding-v3（云端） |
| **核心原则** | 本地优先、快速响应、AI 异步增强、写操作需确认 |

---

## 一、模块总览与优先级

| 优先级 | 模块 | 代号 | 预估工作量 |
|:---|:---|:---|:---|
| **P0** | 快速收集 + AI 自动标签 | `M1-QuickCapture` | 3-4 天 |
| **P0** | AI 任务队列（离线/重试） | `M2-AiTaskQueue` | 2 天 |
| **P1** | 详情页 AI 对话 | `M3-NoteChat` | 5-6 天 |
| **P1** | 全局 AI 助理（FAB + 页面） | `M4-AiAssistant` | 5-6 天 |
| **P2** | 向量搜索引擎（sqlite-vec） | `M5-VectorSearch` | 3-4 天 |
| **P2** | CRM 工具（读 + 写确认） | `M6-CrmTools` | 3-4 天 |
| **P3** | 联网搜索（Skill 插件） | `M7-WebSearch` | 2-3 天 |
| **P3** | Obsidian 对接（只读+渲染+索引） | `M8-Obsidian` | 4-5 天 |

**总预估：27-34 个工作日（约 6-7 周）**

---

## 二、M1 — 快速收集 + AI 自动标签

### 2.1 数据流

```
用户输入 → 立即落库(raw) → 提交 AiTask → 后台 Worker 处理 → 回写标签/分类
```

### 2.2 设置项

```
设置 → AI 处理设置
├── AI 自动标签 [开关，默认开启]
├── AI 自动摘要 [开关，默认关闭]（预留）
└── AI 自动分类 [开关，默认开启]
```

### 2.3 AI 标签 Prompt

```
角色：笔记分类助手
任务：为笔记添加标签和分类

已有标签（共 {n} 个）：
{tag_list}

已有分类：
{category_list}

规则：
1. 从已有标签中选 1-3 个
2. 无合适标签时可新建 1 个，格式 [新:标签名]
3. 从已有分类中选 1 个
4. 生成一句话摘要（≤30字）

笔记内容：
"""{content}"""

返回 JSON：
{"tags":[],"new_tags":[],"category":"","summary":""}
```

### 2.4 执行步骤

| 步骤 | 内容 | 文件 |
|:---|:---|:---|
| 1 | 设置页添加"AI 处理设置"区块，含开关 | `lib/presentation/settings/ai_settings_section.dart` |
| 2 | 新建笔记时，若开关开启，创建 `AiTask(type: autoTag)` | `lib/domain/note/note_service.dart` |
| 3 | 实现 `AiTaskQueueWorker`（监听队列、网络状态、执行任务） | `lib/infrastructure/ai/ai_task_worker.dart` |
| 4 | 实现标签匹配逻辑：全量标签塞 prompt → 解析 JSON → 匹配/新建 | `lib/infrastructure/ai/tagging_service.dart` |
| 5 | 网络恢复后自动执行 `waiting_network` 状态的任务 | `lib/infrastructure/ai/ai_task_worker.dart` |
| 6 | 标签回写笔记，更新笔记状态为 `processed` | `lib/domain/note/note_service.dart` |

---

## 三、M2 — AI 任务队列

### 3.1 数据表

```sql
CREATE TABLE ai_tasks (
  id            TEXT PRIMARY KEY,
  type          TEXT NOT NULL,       -- 'auto_tag'|'auto_summary'|'embedding'|'index'
  ref_id        TEXT NOT NULL,       -- 关联的笔记/客户/文件 ID
  ref_type      TEXT NOT NULL,       -- 'note'|'crm_account'|'obsidian_file'
  payload       TEXT,                -- JSON 额外参数
  status        TEXT NOT NULL DEFAULT 'pending',
                     -- 'pending'|'processing'|'waiting_network'|'done'|'failed'
  retry_count   INTEGER DEFAULT 0,
  max_retries   INTEGER DEFAULT 3,
  error_message TEXT,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);
CREATE INDEX idx_ai_tasks_status ON ai_tasks(status);
CREATE INDEX idx_ai_tasks_ref ON ai_tasks(ref_id, ref_type);
```

### 3.2 Worker 逻辑

```
循环（每 5 秒 或 事件驱动）：
  1. 查询 status='pending' 的任务（按 created_at ASC）
  2. 检查网络
     - 有网 → 执行
     - 无网 → 标记 waiting_network
  3. 执行失败 → retry_count++ → 未超限则重新 pending → 超限则 failed
  4. 网络恢复事件 → 批量将 waiting_network → pending
```

### 3.3 执行步骤

| 步骤 | 内容 |
|:---|:---|
| 1 | 建表 `ai_tasks`，Drift DAO |
| 2 | 实现 `AiTaskQueueWorker`（单例，App 启动时初始化） |
| 3 | 接入网络状态监听（`connectivity_plus`） |
| 4 | 实现指数退避重试（1s → 2s → 4s） |
| 5 | 提供手动重试入口（设置页可查看失败任务） |

---

## 四、M3 — 详情页 AI 对话

### 4.1 数据表

```sql
-- 对话线程（每篇笔记一个）
CREATE TABLE ai_conversations (
  id          TEXT PRIMARY KEY,
  note_id     TEXT NOT NULL,
  title       TEXT,
  model       TEXT,                -- 使用的模型标识
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL,
  FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
);

-- 对话消息
CREATE TABLE ai_messages (
  id              TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  role            TEXT NOT NULL,    -- 'system'|'user'|'assistant'|'tool'
  content         TEXT NOT NULL,
  tool_calls      TEXT,            -- JSON: [{name, arguments}]
  tool_result     TEXT,            -- JSON: {name, result}
  attachments     TEXT,            -- JSON: [{type, name, path}]
  created_at      INTEGER NOT NULL,
  FOREIGN KEY (conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE
);
CREATE INDEX idx_messages_conv ON ai_messages(conversation_id, created_at);
```

### 4.2 上下文组装（Context Builder）

```dart
List<Map<String, dynamic>> buildContext({
  required Note note,
  required List<AiMessage> history,    // 最近 20 轮
  List<Attachment>? attachments,        // 📎 附加内容
  String? searchResult,                 // 联网搜索结果
}) {
  final messages = <Map<String, dynamic>>[];
  
  // 1. System Prompt
  messages.add({
    'role': 'system',
    'content': '''
你是用户的私人笔记助手。

当前笔记内容：
---
${note.content}
---
笔记标签：${note.tags.join(', ')}
创建时间：${note.createdAt}

规则：
- 回答默认围绕本笔记展开
- 如果用户提供了附加资料，优先参考
- 如果用户要求联网搜索，调用 web_search 工具
- 如果需要查询其他笔记或 CRM，调用对应工具
- 保持简洁、实用、有洞察
''',
  });
  
  // 2. 附加知识（如果有）
  if (attachments != null && attachments.isNotEmpty) {
    messages.add({
      'role': 'system',
      'content': '用户附加了以下参考资料：\n${_formatAttachments(attachments)}',
    });
  }
  
  // 3. 搜索结果（如果有）
  if (searchResult != null) {
    messages.add({
      'role': 'system',
      'content': '联网搜索结果：\n$searchResult',
    });
  }
  
  // 4. 历史对话（最近 20 轮）
  for (final msg in history.take(20)) {
    messages.add({'role': msg.role, 'content': msg.content});
  }
  
  return messages;
}
```

### 4.3 📎 附加知识选择器

```
点击 📎 → 弹出 BottomSheet：
├── 📄 选择本地文件（PDF/TXT/MD）
├── 📝 选择已有笔记（搜索 + 多选）
├── 🏷️ 选择某标签下的笔记
├── 👤 选择 CRM 客户档案
└── 📁 选择 Obsidian 文件
```

选中后 → 内容提取 → 作为 `attachments` 存入消息记录 → 注入上下文

### 4.4 Function Calling 工具定义

```dart
final toolDefinitions = [
  {
    'type': 'function',
    'function': {
      'name': 'note_search',
      'description': '搜索用户的其他笔记',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '搜索关键词'},
          'tag': {'type': 'string', 'description': '按标签过滤'},
          'date_range': {'type': 'string', 'description': '时间范围，如"上周""本月"'},
        },
        'required': ['query'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'web_search',
      'description': '联网搜索最新信息',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': '搜索问题'},
        },
        'required': ['query'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'crm_query',
      'description': '查询CRM中的客户、合同、商机信息',
      'parameters': {
        'type': 'object',
        'properties': {
          'entity': {'type': 'string', 'enum': ['account','contact','contract','opportunity']},
          'keyword': {'type': 'string'},
        },
        'required': ['entity'],
      },
    },
  },
];
```

### 4.5 执行步骤

| 步骤 | 内容 |
|:---|:---|
| 1 | 建表 `ai_conversations` + `ai_messages` |
| 2 | 笔记详情页底部添加"AI 对话"面板（可折叠） |
| 3 | 实现 `ContextBuilder`（组装 system + history + attachments） |
| 4 | 实现 `NoteChatService`（调 DeepSeek API，streaming） |
| 5 | 实现 Function Calling 循环（tool_calls → 执行 → 回填 → 再调用） |
| 6 | 实现 📎 附加知识选择器 UI |
| 7 | 对话历史落库 + 重新打开时恢复 |
| 8 | 联网搜索手动触发按钮（🔍） |

---

## 五、M4 — 全局 AI 助理

### 5.1 入口

- **FAB 按钮**：全局悬浮，点击展开对话面板
- **专属页面**：侧边栏/导航中的"AI 助理"入口，全屏对话 + 历史记录

### 5.2 与详情页对话的区别

| | 详情页对话 (M3) | 全局助理 (M4) |
|:---|:---|:---|
| 上下文 | 绑定单篇笔记 | 无固定笔记，全局搜索 |
| 工具 | 笔记搜索 + 联网 | 笔记搜索 + CRM + 联网 + Obsidian |
| 对话线程 | 每篇笔记一个 | 全局多个独立对话 |
| 目的 | 围绕一篇笔记深入 | 跨笔记/跨模块的问答和操作 |

### 5.3 全局助理的 System Prompt

```
你是用户的私人 AI 助理，名字叫"小墨"。

你拥有以下能力：
1. 搜索用户的所有笔记（通过 note_search 工具）
2. 查询和操作 CRM 系统（通过 crm_query / crm_write 工具）
3. 联网搜索最新信息（通过 web_search 工具）
4. 搜索用户的 Obsidian 知识库（通过 obsidian_search 工具）

规则：
- 回答要准确、简洁、实用
- 涉及数据查询时，先调用工具获取，不要编造
- 写操作（修改/创建）必须先展示确认卡片
- 如果不确定，主动询问用户
```

### 5.4 执行步骤

| 步骤 | 内容 |
|:---|:---|
| 1 | 全局助理页面 UI（对话列表 + 对话详情） |
| 2 | FAB 按钮 + 快捷唤起（双击或快捷键） |
| 3 | 复用 M3 的 `ContextBuilder`，去掉笔记绑定 |
| 4 | 注册全部工具（note_search, crm_query, crm_write, web_search, obsidian_search） |
| 5 | 对话线程管理（新建/切换/删除） |
| 6 | 历史记录落库（复用 `ai_conversations` 表，`note_id` 为 null） |

---

## 六、M5 — 向量搜索引擎（sqlite-vec）

### 6.1 架构

```
┌──────────────────────────────────────────┐
│            VectorSearchService            │
├──────────────────────────────────────────┤
│  sqlite-vec 表: vec_documents            │
│  ┌────────────────────────────────────┐  │
│  │ id (TEXT)                          │  │
│  │ source_type ('note'|'crm'|'obs')  │  │
│  │ source_id (TEXT)                   │  │
│  │ chunk_text (TEXT)                  │  │
│  │ embedding (FLOAT32[1024])         │  │
│  │ metadata (TEXT/JSON)              │  │
│  └────────────────────────────────────┘  │
│                                          │
│  Embedding: 通义 text-embedding-v3       │
│  维度: 1024                              │
│  切分: 按段落，每段 ≤ 512 字              │
└──────────────────────────────────────────┘
```

### 6.2 索引触发时机

| 事件 | 动作 |
|:---|:---|
| 笔记保存 | 重新向量化该笔记 |
| 笔记删除 | 删除对应向量 |
| CRM 客户/合同保存 | 重新向量化 |
| Obsidian 文件变更 | 增量向量化 |
| 标签创建/修改 | 向量化标签名（用于语义匹配） |

### 6.3 搜索接口

```dart
class VectorSearchService {
  /// 语义搜索
  Future<List<SearchHit>> search(
    String query, {
    String? sourceType,     // 'note'|'crm'|'obsidian'
    String? filterTag,
    DateTime? after,
    DateTime? before,
    int topK = 5,
  }) async {
    // 1. query → embedding（调通义）
    // 2. sqlite-vec KNN 查询
    // 3. 按 sourceType/filter 后过滤
    // 4. 返回结果
  }
}
```

### 6.4 执行步骤

| 步骤 | 内容 |
|:---|:---|
| 1 | 引入 `sqlite-vec` Flutter 绑定 |
| 2 | 建向量表 `vec_documents` |
| 3 | 实现 `EmbeddingService`（调通义 API） |
| 4 | 实现 `VectorSearchService`（索引 + 查询） |
| 5 | 在笔记保存/删除时触发向量化（通过 AiTask） |
| 6 | 在 CRM 保存时触发向量化 |
| 7 | 提供全局搜索接口供 M4 调用 |

---

## 七、M6 — CRM 工具（AI 可调用）

### 7.1 读操作（自由调用）

```dart
// AI 调用示例
// 用户："张总的合同金额是多少？"
// AI → tool_call: crm_query(entity: 'contract', keyword: '张总')
// 返回 → {客户: 张总, 合同: 年度服务, 金额: 500000, 到期: 2026-12-31}
```

### 7.2 写操作（需确认）

```
AI 生成操作建议 → 渲染确认卡片 → 用户点击"确认" → 执行 → 反馈结果
```

**确认卡片 UI**：
```
┌─────────────────────────────────────┐
│ 🤖 AI 建议执行：                     │
│                                     │
│ 操作：修改合同金额                    │
│ 目标：张总 - 年度服务合同             │
│ 变更：金额 50万 → 60万              │
│                                     │
│         [取消]    [✓ 确认执行]       │
└─────────────────────────────────────┘
```

### 7.3 工具定义

```dart
// 读
'crm_query': {entity, keyword, phone, id}
// 写（需确认）
'crm_create': {entity, fields}
'crm_update': {entity, id, fields}
'crm_delete': {entity, id}
```

### 7.4 执行步骤

| 步骤 | 内容 |
|:---|:---|
| 1 | 实现 `CrmToolService`（封装所有 CRM 读写操作） |
| 2 | 实现 `CrmQueryTool`（读，直接返回） |
| 3 | 实现 `CrmWriteTool`（写，返回确认卡片数据） |
| 4 | 确认卡片 UI 组件 |
| 5 | 确认后执行 + 结果反馈给 AI |
| 6 | 操作日志记录（谁在什么时间改了什么） |

---

## 八、M7 — 联网搜索（Skill 插件）

### 8.1 可插拔接口

```dart
/// 搜索 Skill 抽象接口
abstract class SearchSkill {
  String get id;              // 'bing' | 'serpapi' | 'custom'
  String get displayName;
  
  Future<List<SearchResult>> search(String query, {int maxResults = 5});
  
  /// 验证配置是否有效
  Future<bool> validateConfig();
}

class SearchResult {
  final String title;
  final String url;
  final String snippet;
}
```

### 8.2 第一期实现：Bing

```dart
class BingSearchSkill extends SearchSkill {
  @override
  String get id => 'bing';
  
  @override
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    // GET https://api.bing.microsoft.com/v7.0/search
    // Headers: Ocp-Apim-Subscription-Key: {apiKey}
    // Params: q={query}, count={maxResults}, mkt=zh-CN
  }
}
```

### 8.3 设置页配置

```
设置 → AI 设置 → 联网搜索
├── 启用联网搜索 [开关]
├── 搜索引擎 [Bing ▾]
├── API Key [________________]
└── [测试连接] 按钮
```

### 8.4 触发方式

- **自动**：AI 通过 Function Calling 判断需要搜索时调用
- **手动**：对话输入框旁的 🔍 按钮，强制对当前问题搜索

### 8.5 执行步骤

| 步骤 | 内容 |
|:---|:---|
| 1 | 定义 `SearchSkill` 抽象接口 |
| 2 | 实现 `BingSearchSkill` |
| 3 | 设置页配置 UI |
| 4 | 注册为 AI 工具（`web_search`） |
| 5 | 搜索结果格式化后注入上下文 |
| 6 | 手动搜索按钮 |

---

## 九、M8 — Obsidian 对接

### 9.1 功能范围（本期）

- ✅ 配置 Vault 路径
- ✅ 文件树浏览
- ✅ Markdown 渲染（含双链 `[[xxx]]`）
- ✅ 向量化索引（供 AI 搜索）
- ❌ 双向同步（由外部工具完成，不在本期范围）

### 9.2 设置

```
设置 → 数据源 → Obsidian
├── 启用 Obsidian [开关]
├── Vault 路径 [D:\MyVault]  [浏览...]
├── 索引状态：已索引 342 个文件
└── [重新索引] 按钮
```

### 9.3 笔记中的 Obsidian 子页面

```
笔记详情页 → 底部 Tab 或侧边栏 → "Obsidian" Tab
┌─────────────────────────────────────┐
│ 📁 文件树                            │
│ ├── 日记/                           │
│ │   ├── 2026-08-28.md  ← 点击     │
│ │   └── 2026-08-29.md              │
│ ├── 项目/                           │
│ └── 收藏/                           │
│                                     │
│ 选中文件后 → Markdown 渲染区         │
│ 支持 [[双链]] 点击跳转               │
└─────────────────────────────────────┘
```

### 9.4 技术实现

| 功能 | 实现 |
|:---|:---|
| 文件树 | `dart:io` 递归扫描，缓存到内存/Drift |
| Markdown 渲染 | 复用已有渲染组件 + 扩展双链解析 |
| 双链跳转 | 正则 `$$$$(.+?)$$$$` → 查找对应 .md → 导航 |
| 文件监听 | `FileSystemWatcher` 监听变更 → 增量索引 |
| 向量化 | 按段落切分 → 通义 Embedding → 存入 sqlite-vec |

### 9.5 执行步骤

| 步骤 | 内容 |
|:---|:---|
| 1 | 设置页添加 Obsidian 配置（路径选择） |
| 2 | 实现文件树扫描 + 缓存 |
| 3 | 文件树 UI 组件 |
| 4 | Markdown 渲染 + 双链解析 |
| 5 | 向量化索引（文件变更时增量） |
| 6 | 注册 `obsidian_search` 工具供 AI 调用 |

---

## 十、文件结构（新增/修改）

```
lib/
├── domain/
│   ├── ai/
│   │   ├── ai_task.dart                  // AiTask 实体
│   │   ├── ai_conversation.dart          // 对话线程实体
│   │   ├── ai_message.dart               // 对话消息实体
│   │   └── search_result.dart            // 搜索结果实体
│   └── note/
│       └── note_service.dart             // 修改：保存时提交 AI 任务
│
├── application/
│   ├── ai/
│   │   ├── ai_task_worker.dart           // 任务队列 Worker
│   │   ├── tagging_service.dart          // AI 标签服务
│   │   ├── context_builder.dart          // 上下文组装器
│   │   ├── note_chat_service.dart        // 详情页对话服务
│   │   ├── assistant_service.dart        // 全局助理服务
│   │   ├── tool_executor.dart            // Function Calling 执行器
│   │   └── tools/
│   │       ├── note_search_tool.dart
│   │       ├── crm_query_tool.dart
│   │       ├── crm_write_tool.dart
│   │       ├── web_search_tool.dart
│   │       └── obsidian_search_tool.dart
│   └── vector/
│       ├── vector_search_service.dart    // sqlite-vec 封装
│       ├── embedding_service.dart        // 通义 Embedding
│       └── chunk_splitter.dart           // 文本切分
│
├── infrastructure/
│   ├── ai/
│   │   ├── deepseek_client.dart          // DeepSeek API 封装
│   │   ├── tongyi_embedding_client.dart  // 通义 Embedding API
│   │   └── search_skills/
│   │       ├── search_skill.dart         // 抽象接口
│   │       ├── bing_search_skill.dart    // Bing 实现
│   │       └── custom_search_skill.dart  // 自定义（预留）
│   ├── obsidian/
│   │   ├── obsidian_service.dart         // 文件读取/监听
│   │   ├── obsidian_parser.dart          // 双链解析
│   │   └── obsidian_indexer.dart         // 向量化索引
│   └── crm/
│       └── crm_tool_service.dart         // CRM 读写封装
│
├── presentation/
│   ├── ai_chat/
│   │   ├── note_chat_panel.dart          // 详情页 AI 对话面板
│   │   ├── assistant_page.dart           // 全局助理页面
│   │   ├── assistant_fab.dart            // FAB 按钮
│   │   ├── chat_message_widget.dart      // 消息气泡
│   │   ├── attachment_picker.dart        // 📎 选择器
│   │   ├── crm_confirm_card.dart         // CRM 写操作确认卡片
│   │   └── search_result_widget.dart     // 搜索结果展示
│   ├── obsidian/
│   │   ├── obsidian_page.dart            // Obsidian 子页面
│   │   ├── file_tree_widget.dart         // 文件树
│   │   └── obsidian_md_renderer.dart     // Markdown + 双链渲染
│   └── settings/
│       ├── ai_settings_section.dart      // AI 处理设置
│       └── obsidian_settings_section.dart // Obsidian 配置
│
└── database/
    ├── tables/
    │   ├── ai_tasks_table.dart
    │   ├── ai_conversations_table.dart
    │   ├── ai_messages_table.dart
    │   └── vec_documents_table.dart      // sqlite-vec
    └── app_database.dart                 // 新增表注册
```

---

## 十一、里程碑与交付节奏

```
Week 1 (Day 1-5)
├── M2: AI 任务队列 ✅
├── M1: 快速收集 + AI 标签 ✅
└── 交付：新建笔记后自动打标签，离线可重试

Week 2-3 (Day 6-11)
├── M5: sqlite-vec 向量搜索 ✅
├── M3: 详情页 AI 对话（基础版）✅
└── 交付：笔记详情页可与 AI 对话，上下文包含笔记内容

Week 3-4 (Day 12-17)
├── M3 完善：📎附加知识 + 联网搜索 + Function Calling ✅
├── M4: 全局 AI 助理 ✅
└── 交付：FAB 唤起 AI 助理，可搜索笔记、调用工具

Week 5 (Day 18-22)
├── M6: CRM 工具（读 + 写确认）✅
├── M7: 联网搜索 Skill ✅
└── 交付：AI 可查询/操作 CRM，可联网搜索

Week 6-7 (Day 23-29)
├── M8: Obsidian 对接 ✅
├── 全部集成测试 + Bug 修复
└── 交付：完整 AI 功能上线
```

---

## 十二、技术依赖汇总

| 依赖 | 用途 | 新增/已有 |
|:---|:---|:---|
| `sqlite-vec` | 向量搜索 | **新增** |
| `http` / `dio` | API 调用 | 已有 |
| `connectivity_plus` | 网络状态监听 | **新增**（如未有） |
| `file_picker` | 文件选择 | 已有 |
| `path` | 路径处理 | 已有 |
| `watcher` | 文件系统监听 | **新增** |
| 通义 text-embedding-v3 | 向量化 | **新增**（API） |
| DeepSeek API | LLM 对话 | 已有 |
| Bing Search API | 联网搜索 | **新增**（API） |

---

## 十三、核心约束与原则

1. **快速响应**：用户操作（保存、切换）永远不等 AI，AI 全部异步
2. **离线可用**：无网时笔记正常使用，AI 任务排队等待
3. **数据安全**：CRM 写操作必须用户确认，绝不静默修改
4. **可配置**：模型、搜索引擎、开关全部在设置页可调
5. **渐进增强**：AI 功能是锦上添花，不是必要路径，关闭所有 AI 开关后应用完全可用
6. **上下文窗口**：笔记全文注入（你的长度在 128K 内），不做摘要截断
7. **对话落库**：所有对话持久化，重新打开可恢复

---

*本文档为开发执行的唯一参考。每个模块的"执行步骤"即为 AI 编码助手的任务指令，按顺序逐步实现。*