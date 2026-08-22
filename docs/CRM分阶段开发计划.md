# CRM 分阶段开发计划（本地优先）

> 版本：v2.0 · 2026-08-22 · 分支：feat/local-crm-v1
> 依据：[CRM 数据结构模型设计.md](./CRM%20数据结构模型设计.md)（19 表权威模型）
>       + 既有进度（P5–P8、本地化第一步、架构讨论-本地化CRM方案）

## 一、目标与原则

| 原则 | 说明 |
| :-- | :-- |
| 本地优先 | 唯一真相源为本地 Drift；无网络依赖；Twenty 已弃用（代码待清理） |
| 单人简化 | 无多租户/审批流/权限；线索与商机合并（Opportunity.stage 全生命周期） |
| 模型权威 | 以《CRM 数据结构模型设计》19 表为准，逐步落库 |
| 复用优先 | 智能表格/列设置/时间线/仓储层等既有资产直接复用 |
| 增量落地 | 每阶段可独立交付、独立测试、独立验收 |

## 二、现状基线（feat/local-crm-v1）

| 项 | 状态 |
| :-- | :-- |
| schema v8 | CrmCompanies / CrmPeople / CrmOpportunities / CrmContracts + 自定义对象引擎（ObjectDefs/CustomRecords）+ CrmEntityLinks |
| CrmLocalRepository | 基础对象 CRUD/搜索、自定义对象、关联、统计 |
| CRM 首页 | 本地 Tab（基础对象 + 自定义对象），智能表格 + 列设置 + CRUD |
| 测试 | 153 通过；analyze 0 error；Windows 构建 ✅ |

## 三、与设计文档的差异与适配决策（需确认）

| 决策点 | 设计文档 | 现状 | 建议 |
| :-- | :-- | :-- | :-- |
| R0 对象实现方式 | 19 表全部强类型 | 4 基础表强类型 + 自定义对象引擎 | **标准对象全部强类型**（含回款/发票/质保/售后等，按文档）；**自定义对象引擎保留**，用于用户自建对象。两者并存 |
| R1 客户模型 | Account 统一承载 company/person/org | CrmCompanies / CrmPeople 分离 | **按文档演进为 Account + Contact**（Contact 属 Account）；v9 迁移合并现有两表 |
| R2 状态管理 | Riverpod + Stream | GetX | 适配：DAO 提供 `Stream`，UI 用 GetX `Rx`/`StreamBuilder` 订阅（不引入 Riverpod） |
| R3 时间戳 | INTEGER Unix | DateTime | 适配：统一 DateTime（现有风格） |
| R4 枚举 | Drift textEnum | String + 常量 | 适配：String 列 + 常量集合（与现有代码一致，便于自定义扩展） |
| R5 跟进记录 | Activity 多态表（call/meeting/…） | CrmEntityLinks（日记/待办关联） | 两者并存：Activity 承载业务跟进记录；CrmEntityLinks 承载日记/待办关联；时间线合并 |
| R6 单号 | 编号规则 QT/HT/AS-YYYYMMDD-XXX | 无 | 按文档实现，当日自增 |

> 结论：设计文档是权威数据模型；本计划按 R0–R6 适配后分阶段落地。R1 需要用户确认是否接受
> "Account 统一 + Contact 从属"（会重构现有 Company/Person 两表）。

## 四、阶段总览

| 阶段 | 名称 | 核心产出 | 依赖 |
| :-- | :-- | :-- | :-- |
| S0 | 决策与基座 | R0–R6 拍板；同步日志落盘；Twenty 遗留代码收拢；schema v9 迁移框架 | - |
| S1 | 核心对象 | Account / Contact / Opportunity（含线索 stage 全生命周期）+ 仓储 + 首页 Tab + CRUD + 列设置 + 搜索 | S0 |
| S2 | 产品与销售流程 | Product / Category / Quote / QuoteItem / Contract / ContractItem + 单号 + 报价转合同 | S1 |
| S3 | 财务回款 | PaymentPlan / Payment / Invoice + 合同冗余金额维护 + 到期提醒 | S2 |
| S4 | 售后服务 | Warranty / AfterSales + 质保到期提醒 | S2 |
| S5 | 通用支撑 | Activity 跟进/时间线、Tag/EntityTag、Attachment、Reminder、日历联动 | S1–S4 |
| S6 | 体验与生态 | 看板、AI 辅助录入、PDF 导出、备份纳入、多设备同步预留 | S3–S5 |

## 五、任务分解

### S0 决策与基座（0.5–1 迭代）

| ID | 任务 | 产出 | 验收 |
| :-- | :-- | :-- | :-- |
| S0.1 | 用户确认 R0–R6（尤其 R1 Account 统一模型） | 决策记录 | 计划冻结 |
| S0.2 | 修复同步日志落盘（attachLogFile 到应用支持目录） | 日志可查 | 重启后日志保留 |
| S0.3 | 收拢/删除 Twenty 遗留（CrmSyncService/CrmFieldRegistry/CrmContentSync 等），保留导出钩子 | 代码瘦身 | analyze 0 error |
| S0.4 | schema v9 迁移框架：Account/Contact 演进 + 枚举常量文件 | crm_enums.dart + 迁移 | 迁移幂等、旧数据无损 |

### S1 核心对象（1–2 迭代）

| ID | 任务 | 产出 | 验收 |
| :-- | :-- | :-- | :-- |
| S1.1 | Account 表 + 仓储（统一类型 company/person/org，含行业/等级/来源/状态） | DAO + 单测 | CRUD/搜索/软删 |
| S1.2 | Contact 表 + 仓储（从属 Account，主联系人/决策人标记） | DAO + 单测 | 按客户筛选 |
| S1.3 | Opportunity 表 + 仓储（stage 8 阶段、概率/金额/预计与实际成交/输单原因/线索暂存字段） | DAO + 单测 | 阶段流转 |
| S1.4 | 首页 Tab 切换为 Account/Contact/Opportunity + 既有智能表格/列设置/CRUD 接入 | UI | 三对象可增删改查 |
| S1.5 | 实体详情页 v1：字段展示 + 相关日记（CrmEntityLinks） | 详情页 | 下钻可用 |

### S2 产品与销售流程（2 迭代）

| ID | 任务 | 产出 | 验收 |
| :-- | :-- | :-- | :-- |
| S2.1 | Category/Product 表 + 仓储（分类两级、SKU 唯一、产品/服务、质保月数） | DAO + 单测 | 产品 CRUD |
| S2.2 | Quote/QuoteItem 表 + 仓储（单号 QT-、明细小计、折扣） | DAO + 单测 | 报价单 CRUD |
| S2.3 | Contract/ContractItem 表 + 仓储（单号 HT-、冗余 paid/invoiced、质保到期） | DAO + 单测 | 合同 CRUD |
| S2.4 | 报价转合同流程（Quote accepted → 生成 Contract + 明细快照） | 流程 + 单测 | 一次生成、幂等 |
| S2.5 | 报价/合同管理页（Tab + 智能表格 + 明细编辑） | UI | 可编辑明细行 |

### S3 财务回款（2 迭代）

| ID | 任务 | 产出 | 验收 |
| :-- | :-- | :-- | :-- |
| S3.1 | PaymentPlan 表 + 仓储（期次/计划金额/已收/状态） | DAO + 单测 | 计划 CRUD |
| S3.2 | Payment 表 + 仓储（回款方式、关联计划/发票） | DAO + 单测 | 回款 CRUD |
| S3.3 | Invoice 表 + 仓储（发票类型/税率/状态/收票人） | DAO + 单测 | 发票 CRUD |
| S3.4 | 冗余金额维护：回款/开票自动累加 Contract.paidAmount/invoicedAmount | 事务 + 单测 | 一致性 |
| S3.5 | 到期提醒（Reminder 驱动，回款/合同到期） | 提醒列表 | 到期可查 |

### S4 售后服务（1–2 迭代）

| ID | 任务 | 产出 | 验收 |
| :-- | :-- | :-- | :-- |
| S4.1 | Warranty 表 + 仓储（序列号、起止、状态） | DAO + 单测 | 质保 CRUD |
| S4.2 | AfterSales 表 + 仓储（工单号 AS-、类型/优先级/状态流转） | DAO + 单测 | 工单流转 |
| S4.3 | 售后/质保管理页 + 到期提醒 | UI | 可操作 |

### S5 通用支撑（2 迭代）

| ID | 任务 | 产出 | 验收 |
| :-- | :-- | :-- | :-- |
| S5.1 | Activity 表 + 仓储（多态 relatedType/relatedId、类型/方向/状态/计划时间） | DAO + 单测 | 跟进 CRUD |
| S5.2 | 时间线合并：Activity + 日记/待办关联（CrmEntityLinks）+ 实体事件 | 时间线组件 | 实体页时间线 |
| S5.3 | Tag/EntityTag（任意实体打标） | DAO + 单测 | 打标/筛选 |
| S5.4 | Attachment（附件沙盒：文档目录 + 路径记录） | DAO + 附件管理 | 上传/清理 |
| S5.5 | Reminder + 本地通知（回款/质保/跟进/合同到期） | 通知集成 | 到点提醒 |
| S5.6 | 日历联动：Activity.scheduledAt/Reminder 投射到日历页 | 日历聚合扩展 | 日历可见 |

### S6 体验与生态（持续迭代）

| ID | 任务 | 产出 |
| :-- | :-- | :-- |
| S6.1 | 数据看板：商机漏斗、月度回款、售后分布、客户等级占比 | 看板页 |
| S6.2 | AI 辅助录入：语音/文本 → 提取客户名/金额/需求，填充实体（复用 AI/模型管理） | AI 填充 |
| S6.3 | PDF 导出：报价/合同/发票 | 导出 |
| S6.4 | 备份纳入：本地 CRM 进入全量导入导出（Markdown+JSON） | 备份扩展 |
| S6.5 | 多设备同步预留：CrmEntityLinks/Activity 纳入 Rust 同步 DTO；CRDT 评估 | 设计文档 |

## 六、横切要求（每阶段必做）

1. 数据层改动后 `dart run build_runner build` + 迁移幂等；
2. `dart analyze` 0 error；`flutter test` 全绿（仓储/流程单测 ≥ 每阶段新增 5 例）；
3. 涉及 UI 的提交补 widget 冒烟测试（列设置/CRUD 对话框）；
4. 关键流程（报价转合同、金额冗余、时间线合并）写纯逻辑单测；
5. 每阶段更新 docs/开发进度.md。

## 七、里程碑验收

| 里程碑 | 出口 |
| :-- | :-- |
| M-CRM1（S1 后） | 客户/联系人/机会 可演示：增删改查、阶段流转、下钻相关日记 |
| M-CRM2（S2–S3 后） | 产品→报价→合同→回款/发票 全链路可走通，金额自动汇总 |
| M-CRM3（S4–S5 后） | 售后/质保 + 跟进时间线 + 标签附件 + 提醒日历 完整可用 |
| M-CRM4（S6 后） | 看板/AI/PDF/备份 全齐，达到单人多设备可用 |

## 八、风险与待决

| 项 | 说明 |
| :-- | :-- |
| R1 迁移 | Company/Person → Account/Contact 涉及现有数据迁移，需用户确认后做 v9 |
| 自定义对象引擎定位 | 保留但仅用于用户自建对象；标准对象一律强类型 |
| 多设备 | 依赖自研同步；阶段 S6.5 仅预留设计，不承诺 CRDT 完成时间 |
| 本地通知 | Windows 需 flutter_local_notifications 支持验证 |
