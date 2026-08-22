# Twenty 数据对象对接指导（笔记 / 待办 / 跟进记录 / 通用表）

> 日期：2026-08-22　|　基线：develop（ae71c71）　|　范围：下一阶段「完善与 Twenty 的数据同步与数据展示细节」

## 1. 目标与设计思想

按照最初的开发思想，Moodiary 是「本地优先的记录终端」，Twenty 是业务侧 CRM 数据中心。
本阶段把本应用的**笔记、待办、跟进记录**沉淀为 Twenty 的标准对象，并复用 Twenty 的
`noteTarget` / `taskTarget` 关联机制，让带客户关联的数据自动进入**客户时间线**；
未关联的数据先落入**通用数据表**（`moodiaryGeneric`），后续可在本应用内编辑并「认领关联」。

### 1.1 对象映射总览

| 本应用数据 | Twenty 对象 | 关联方式 | 客户时间线 | 认领后可编辑 |
| :-- | :-- | :-- | :-- | :-- |
| 笔记（Diary） | `note`（标准对象） | `noteTarget` → company/person/opportunity | ✅ | ✅ |
| 待办（Todo Block） | `task`（标准对象） | `taskTarget` → company/person/opportunity | ✅ | ✅ |
| 跟进记录 | `note`（`title` 前缀 `[跟进]` + target） | `noteTarget` → company/person/opportunity | ✅ | ✅ |
| 未关联笔记/待办 | `moodiaryGeneric`（自定义通用表） | 认领后升级为 note/task 并挂 target | 认领后 ✅ | ✅ |

> 降级策略：若 Twenty 尚未创建 `moodiaryGeneric`，未关联数据回退为「无 target 的标准 note/task」，
> 仍可在本应用「内容同步」页认领关联；日志会提示创建通用对象。

## 2. Twenty 侧对象清单

### 2.1 标准对象（Twenty 内置，无需创建）

#### note（笔记）

| 字段 | 类型 | 必填 | 说明 |
| :-- | :-- | :-- | :-- |
| title | TEXT | ✅ | 笔记标题（本应用用日记标题） |
| bodyV2 | RICH_TEXT_V2 | – | 富文本；本应用写入 `{ blocknote: null, markdown: <内容> }` |
| body | RICH_TEXT（deprecated） | – | 兼容旧字段，本应用不写 |
| createdBy | ACTOR | – | API Key 创建时由 Twenty 自动注入（source=API） |
| noteTargets | 1:N → noteTarget | – | 关联目标，进入客户时间线的关键 |

#### task（待办）

| 字段 | 类型 | 必填 | 说明 |
| :-- | :-- | :-- | :-- |
| title | TEXT | ✅ | 任务标题（首条待办行，超 40 字截断） |
| bodyV2 | RICH_TEXT_V2 | – | 完整任务行 Markdown |
| dueAt | DATE_TIME | – | 到期时间（BlockMeta.dueDate） |
| status | SELECT | – | TODO / IN_PROGRESS / DONE（由勾选状态推导） |
| taskTargets | 1:N → taskTarget | – | 关联目标 |

#### noteTarget / taskTarget（关联桥接表，系统对象）

| 字段 | 类型 | 说明 |
| :-- | :-- | :-- |
| noteId / taskId | UUID | 所属笔记/待办 |
| companyId | UUID | 关联客户（公司） |
| personId | UUID | 关联联系人 |
| opportunityId | UUID | 关联商机 |

> 一条 note/task 可挂多个 target（例如同时关联公司 + 联系人），在客户/联系人/商机详情
> 时间线中都会出现。本应用当前自动匹配与认领采用「单主目标」策略（公司优先），
> 结构上已支持多目标，后续可扩展。

### 2.2 自定义对象：moodiaryGeneric（通用数据表）

用于容纳**暂无客户关联**的笔记/待办数据，待用户在本应用内「认领关联」后升级为标准对象。

#### 字段表

| 字段 | 类型 | 必填 | 说明 |
| :-- | :-- | :-- | :-- |
| title | TEXT | ✅ | 标题（日记标题 / 待办首行） |
| content | TEXT | – | 完整内容（Markdown 或任务行） |
| name | TEXT | ✅ | **标签标识字段**：Twenty 自动生成（labelIdentifier），记录在表格/视图中的显示名，应用写入=标题 |
| sourceType | SELECT | ✅ | `NOTE` / `TODO`（Twenty 枚举要求大写蛇形），认领时决定升级为 note 还是 task |
| dueAt | DATE_TIME | – | 待办到期时间 |
| status | SELECT | – | TODO / IN_PROGRESS / DONE |
| 内置 createdAt / updatedAt / createdBy | – | – | Twenty 自动维护 |

#### 创建方式 A：Twenty 界面（推荐首次）

1. 登录 Twenty → 右上角 **Settings** → **Data model**；
2. 点击 **Create object**：
   - 单数名 `moodiaryGeneric`，复数名 `moodiaryGenerics`；
   - 标签：单数「Moodiary 通用记录」，复数「Moodiary 通用记录」；
   - 图标任意（建议 `IconInbox`），描述「未关联笔记/待办的通用数据表，认领后升级为标准对象」；
3. 添加字段：
   - `title` → 文本（Text），默认作为标签标识符；
   - `content` → 多行文本；
   - `sourceType` → 单选（Select），选项 `NOTE`（笔记）/ `TODO`（待办），默认 `NOTE`；
   - `dueAt` → 日期时间（DateTime），可空；
   - `status` → 单选（Select），选项 `TODO` / `IN_PROGRESS` / `DONE`，默认 `TODO`；
4. **Save**。Twenty 自动执行 workspace migration，对象即刻可用。

#### 创建方式 B：Metadata GraphQL API（可脚本化）

Metadata 端点：`{TWENTY_BASE_URL}/metadata`（部分版本为 `/metadata/graphql`，
以实例实际路由为准；本测试环境 2026-08-22 为 `/metadata`），
请求头 `Authorization: Bearer <API Key>`。

```bash
# 1) 创建对象
curl -X POST http://10.200.245.54:3000/metadata \
  -H "Authorization: Bearer $TWENTY_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "query": "mutation CreateObject($input: CreateOneObjectInput!) { createOneObject(input: $input) { id nameSingular namePlural labelSingular labelPlural } }",
    "variables": {
      "input": {
        "object": {
          "nameSingular": "moodiaryGeneric",
          "namePlural": "moodiaryGenerics",
          "labelSingular": "Moodiary 通用记录",
          "labelPlural": "Moodiary 通用记录",
          "description": "未关联笔记/待办的通用数据表，认领后升级为标准对象",
          "icon": "IconInbox"
        }
      }
    }
  }'
```

拿到返回的 `id`（objectMetadataId）后创建字段：

```bash
# 2) 创建字段 title（TEXT）
curl -X POST http://10.200.245.54:3000/metadata \
  -H "Authorization: Bearer $TWENTY_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "query": "mutation CreateField($input: CreateOneFieldMetadataInput!) { createOneField(input: $input) { id name label type } }",
    "variables": {
      "input": {
        "field": {
          "objectMetadataId": "<OBJECT_METADATA_ID>",
          "name": "title",
          "label": "Title",
          "type": "TEXT"
        }
      }
    }
  }'

# 3) content（TEXT）
#    同上，type: "TEXT", name: "content", label: "Content"

# 4) sourceType（SELECT，带选项；注意 SELECT 默认值需带引号字符串，如 "'NOTE'"）
#    同上，type: "SELECT", name: "sourceType", label: "Source Type",
#    options: [{"value":"NOTE","label":"笔记","position":0,"color":"sky"},
#              {"value":"TODO","label":"待办","position":1,"color":"green"}],
#    defaultValue: "'NOTE'"

# 5) dueAt（DATE_TIME）
#    同上，type: "DATE_TIME", name: "dueAt", label: "Due At"

# 6) status（SELECT）
#    options: TODO / IN_PROGRESS / DONE，默认值 "'TODO'"
```

> 权限要求：调用 `/metadata/graphql` 需要 API Key 具备 **Data model** 管理权限
> （Settings → Permissions / API Key 创建时勾选）。若 Key 只有业务数据权限，
> 请使用方式 A 在界面创建对象。

> 注意：创建对象时若未指定标签标识字段，Twenty 会自动新增 `name` 字段作为
> labelIdentifier。写入通用记录必须同时提供 `name`（显示名），否则记录在
> Twenty 表格中显示为空白。

## 3. 关联与客户时间线机制

1. **自动关联**：本应用推送笔记/待办时，先用本地 CRM 缓存做名称匹配
   （文本中出现客户/联系人/机会名称，公司 > 联系人 > 机会），命中即创建
   `noteTarget` / `taskTarget`，数据自动出现在对应客户/联系人/商机详情的时间线；
2. **未关联**：写入 `moodiaryGeneric`（或降级为无 target 的标准对象），本地映射标记为
   `generic`（未认领）；
3. **认领关联**：在「内容同步」页选中记录 → 选择目标实体 → 应用在 Twenty 内
   完成「升级为标准 note/task + 创建 target + 删除通用记录」，客户时间线随即出现；
4. **取消关联**：删除对应 target，记录回到未认领状态；
5. **跟进记录**：从客户详情发起的跟进，创建 `note` 且 `title` 以 `[跟进]` 开头，
   与同一实体建 target，进入时间线的「跟进记录」位置。

## 4. 标准 GraphQL 操作命令（业务端点 `/graphql`）

以下为应用内 `TwentyApiClient` 使用的等价命令，供人工验证/调试。

### 4.1 创建笔记并关联客户

```graphql
mutation CreateNoteAndTarget {
  createNote(data: { title: "客户拜访纪要", bodyV2: { markdown: "- [ ] 回访\n- 补充合同细节" } }) {
    id title
  }
}
```

拿到 noteId 后：

```graphql
mutation CreateNoteTarget($noteId: ID!, $companyId: ID!) {
  createNoteTarget(data: { noteId: $noteId, companyId: $companyId }) {
    id noteId companyId
  }
}
```

### 4.2 创建待办并关联联系人

```graphql
mutation CreateTask {
  createTask(data: {
    title: "跟进报价",
    dueAt: "2026-08-30T08:00:00.000Z",
    status: "TODO",
    bodyV2: { markdown: "- [ ] 跟进报价\n- [ ] 确认到货" }
  }) { id title dueAt status }
}
```

### 4.3 写入通用数据表

```graphql
mutation CreateGeneric {
  createMoodiaryGeneric(data: {
    title: "灵感片段",
    content: "周末想清楚的产品方向",
    sourceType: "NOTE"
  }) { id title sourceType }
}
```

### 4.4 查询笔记（含关联目标摘要）

```graphql
query ListNotes($first: Int!) {
  notes(first: $first) {
    edges { node { id title createdAt } }
    pageInfo { endCursor hasNextPage }
  }
}
```

## 5. 对接要求

1. **权限**：业务端点 `/graphql` 的 API Key 需可读可写 `note`、`task`、
   `noteTarget`、`taskTarget` 及自定义对象；metadata 端点权限见 2.2；
2. **命名约定**：自定义对象固定为 `moodiaryGeneric`（代码常量，勿改）；
   `sourceType` 取值固定 `NOTE` / `TODO`（Twenty SELECT 枚举要求大写蛇形）；`status` 取值对齐 Twenty 任务枚举；
3. **幂等**：本地 `crm_content_links` 表以 `(localType, localId)` 唯一约束，
   同一本地记录重复推送只会更新远端对象，不会重复创建；
4. **冲突策略**：沿用 LWW（Last-Write-Wins）+ 对账；内容以本地最近修改为准，
   Twenty 侧手改内容在下次推送时被本地覆盖（如需反向同步再扩展对账）；
5. **安全**：`config/twenty.local.json` 与 API Key 不入 git；应用内令牌走
   `flutter_secure_storage`；
6. **降级**：`moodiaryGeneric` 不存在时不阻塞推送，回退无 target 标准对象，
   并写入同步日志提示创建；
7. **删除**：删除本地记录不清除 Twenty 数据（默认保守）；「内容同步」页提供
   显式删除远端对象入口。

## 6. 本应用实现清单

| 模块 | 说明 |
| :-- | :-- |
| `lib/features/crm/crm_content_sync_service.dart` | 推送/自动匹配/认领/拉取/删除 |
| `lib/features/crm/twenty_api.dart` | note/task/target CRUD + introspection |
| `lib/persistence/app_database.dart` | `crm_content_links` 映射表（schema v7） |
| 设置 → CRM 同步 → 内容同步 | 一键推送、未关联清单、认领、远端删除 |
| CRM 顶部 Tab 表格 | 客户/联系人/机会/合同等主对象智能表格（见开发进度） |

验收：`flutter analyze` 0 error；`flutter test` 全绿；真实 Twenty 环境完成
「推送 → 时间线出现 → 认领 → 目标详情可见」闭环。
