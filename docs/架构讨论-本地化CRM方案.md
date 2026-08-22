# 架构讨论：CRM 本地化实现方案（2026-08-22）

> 状态：讨论中，未落地。本文档记录用户提出的方向性调整与架构分析。
> 参与：用户（产品决策） + 主协调（架构/代码）

## 一、背景与触发

在 P5–P8 完成 Twenty 双向对接后，用户提出质疑：

1. 完全对齐 Twenty 做"双向真同步"并不容易，且为了迎合 Twenty 把本来简单的事情做复杂了；
2. 本应用底层已有标准数据库（Drift/SQLite），开发 CRM 本质就是多几张表 + 关联查询；
3. CRM 的成熟数据模型网上有大量现成实例（SuiteCRM / EspoCRM 等），可以直接参照；
4. 需求不复杂、单用户、无协作，是否可以直接转本地实现，不再依赖 Twenty 作为真相源？

## 二、现状：为对齐 Twenty 付出的复杂度清单

| 复杂度来源 | 说明 |
| :-- | :-- |
| 连接与令牌 | baseUrl/API Key 安全存储、轮换、导入向导、吊销排查 |
| 元数据怪癖 | Twenty metadata 缓存字段不全 → 用 GraphQL schema 合并 + 硬编码补充 |
| 命名差异 | noteTarget 用 targetCompanyId 而非 companyId；metadata 名 ≠ GraphQL 名 |
| 枚举规范 | SELECT 值必须大写蛇形（NOTE/TODO） |
| 复合类型 | FullName/Emails/Phones/Links/Currency/Actor 全部要写可读化格式化 |
| 双向语义 | Diary→note、Todo Block→task 粒度不对齐；删除语义不对称；对账只覆盖 CRM 对象 |
| 通用表 | 自定义对象 moodiaryGeneric + 认领时"升级转换+删除"，产生两份数据与孤儿风险 |
| 网络依赖 | 日常同步依赖内网 Twenty 可达，离线体验割裂 |

结论：以上大部分复杂度，恰恰是"迎合 Twenty"产生的，对单用户本地应用毫无收益。

## 三、Twenty 真正提供的价值（失去它会损失什么）

1. 现成的对象模型与关联（company/person/opportunity/noteTarget…）→ 本地关系表可实现且更简单；
2. 客户时间线（note/task/邮件按关联聚合）→ 本地已有 TimelineItem 合并日记+CRM 的能力；
3. 搜索（全文/向量）→ 本地已有 GlobalSearch + RAG；
4. 视图系统（字段/筛选/排序/看板）→ 本地已用 pluto_grid 实现列配置；
5. 多用户协作 / Web 端 / 邮件捕获 / LinkedIn 等生态 → 用户明确不需要；
6. 多设备访问 → 本地优先应用已有自己的局域网同步 + 备份体系。

结论：对本需求，Twenty 的"价值项"要么本地已有、要么不需要。
唯一需要考虑的是多端/云访问（见开放问题）。

## 四、推荐架构：本地优先 CRM + 可选 Twenty 适配层

核心转变：本地数据库是唯一真相源，Twenty 从"真相源"降级为"可选的镜像/导出目标"。
即"让 Twenty 适配我们"，而不是"我们适配 Twenty"。

```text
┌─────────────────────────────┐
│  本地优先 CRM（Drift 关系表） │  ← 唯一真相源
│  companies / people /       │
│  opportunities / contracts  │
│  crm_links（关联/认领）      │
└──────────┬──────────────────┘
           │ CrmRepository（DAO，统一读写）
           ▼
┌─────────────────────────────┐
│  UI 层（复用）               │
│  智能表格 / CRUD 表单 / 详情   │
│  时间线合并 / 内容关联         │
└──────────┬──────────────────┘
           │ CrmBackend（接口）
           ├── LocalBackend（默认，直接读写本地库）
           └── TwentyBackend（可选适配器，关闭时零开销）
```

要点：

- CrmBackend 接口：结构同步/数据同步/内容推送都走接口；默认 LocalBackend；
- 现有 Twenty 代码整体收进 TwentyBackend 适配器，默认关闭，需要时再启用；
- 智能表格、列设置、时间线、认领 UI 全部复用，不重写；
- 结构同步概念保留，但含义变为"本地 schema 迁移 + 字段元数据表"。

## 五、本地 CRM 数据模型草案（参照成熟 CRM）

```text
companies      id, name, domainName, address_json, employees,
               linkedin_link, x_link, arr_micros, icp, customer_status, …
people         id, company_id FK, first_name, last_name, job_title,
               emails_json, phones_json, city, wechat, avatar_url, …
opportunities  id, company_id FK, point_of_contact_id FK, name,
               amount_micros, close_date, stage, custom_status, …
contracts      id, company_id FK, name, amount_micros, currency,
               status, due_date, terms, …
payments / invoices / commissions  同构扩展
crm_links      local_id(block/diary) ↔ entity_type + entity_id（认领/时间线）
follow_ups     跟进记录 = Diary（BlockMeta.entityId + 类型标记），时间线合并
```

- 关联查询：company 1:N people / opportunities / contracts；实体 ↔ 日记/待办通过
  crm_links 或 BlockMeta.entityId + entityType（已具备）；
- 通用记录/未关联 = crm_links 中 entity_id 为空的记录，无需自定义对象；
- 认领 = 原地填 entity_id，无迁移、无删除、无孤儿。

## 六、可复用资产（此前工作不白费）

- pluto_grid 智能表格 + 列设置（显隐/排序/恢复默认）→ 直接复用；
- TimelineItem 时间线合并 → 直接复用；
- 字段注册/复合值格式化（formatValue）→ 复用于本地 schema 的展示；
- crm_links 内容映射表 → 演化为本地关联/认领表；
- 内容推送/认领 UI → 演化为本地关联 UI；
- 结构同步的"版本 + 按需刷新"思想 → 复用于本地迁移与字段元数据。

## 七、落地路径（若批准）

| 阶段 | 内容 | 产出 |
| :-- | :-- | :-- |
| A | 本地 CRM schema（Drift 表 + 迁移 v8） + CrmRepository DAO | 数据层 |
| B | UI 从 CrmEntityCache 切换到 Repository（智能表格/表单/详情/时间线） | 功能层 |
| C | 内容关联/认领/跟进 全本地化（crm_links + BlockMeta.entityId） | 关联层 |
| D | CrmBackend 接口 + TwentyBackend 适配器（现有代码收拢，默认关闭） | 兼容层 |
| E | 迁移：本地旧缓存 → 新表；Twenty 测试数据可选导入 | 数据迁移 |

## 八、开放问题（需用户拍板）

1. 多端/云访问：是否还需要手机/电脑/网页访问同一份 CRM？
   - 不需要 → 纯本地 + 局域网同步足够；
   - 需要 → 用本应用自己的同步/备份体系，或保留 Twenty 作为可选镜像。
2. 是否保留 Twenty 导出能力：以后要不要把 CRM 数据"交付"到 Twenty（例如给团队）？
3. 现有 Twenty 测试数据：全部作废重新开始，还是做一次性导入？
4. 范围：本地 CRM 首批做哪些对象（公司/联系人/机会/合同，还是含回款/发票/提成）？

## 九、结论（主协调建议）

支持本地化 CRM 作为主实现：与用户需求（单用户、简单、本地优先）匹配，
可消除 P5–P8 大量"迎合 Twenty"的复杂度；现有资产大部分可复用，改造风险可控。
保留 Twenty 适配层（默认关闭）：用接口隔离，未来需要多端/团队/云时再启用，
避免二次推倒重来。不建议在本地化之前继续追加 Twenty 侧功能。
