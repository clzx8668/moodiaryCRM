# Moodiary CRM 数据结构规划指南

> **定位**：本项目 CRM 模块唯一的数据结构权威依据（Data Source of Truth）。
> 开发前先读本指南，字段/枚举/关联/状态机一律以此为准，新增表或字段需同步更新本指南。
> **技术栈**：Flutter + Drift(SQLite) + GetX，本地优先、单人使用。
> **参照**：Twenty CRM / HubSpot / Salesforce Lightning / SuiteCRM。
> **版本**：v1.0 · 2026-08-24

---

## 一、设计定位与总原则

| 原则 | 含义 | 落地规则 |
|:---|:---|:---|
| 本地优先 | 全部数据存本地 SQLite，不依赖云端 | Drift 表即权威；同步（若有）只做增量 |
| 单人简化 | 去多租户/审批流/角色权限 | 无 team/owner 概念，`createdBy` 不建表 |
| 线索并入商机 | 录入即商机，stage 覆盖全生命周期 | 不建 Lead 表 |
| 元数据驱动 | 内置对象强类型，扩展对象元数据驱动 | 内置对象 = 独立表；自定义对象 = `CrmObjectDefs` + `CrmCustomRecords` 宽表 |
| 双向无感关联 | 关联与新建是同一交互流的两个分支 | 见「八、关联交互规范」 |
| 快照防篡改 | 单据明细冗余业务名称 | QuoteItem/ContractItem 存 `productName` |
| 冗余换性能 | 高频聚合值落库 | Contract 冗余 `paidAmount/invoicedAmount`，PaymentPlan 冗余 `paidAmount` |
| 多态关联 | 一张表关联任意实体 | Activity/Attachment/Reminder/Tag 用 `relatedType + relatedId` |
| 允许不完美 | 外键可空、数据渐进补全 | 联系人可无客户、商机可无客户/联系人 |
| 软删除 | 数据不物理删除 | 所有业务表带 `deleted` 布尔（默认 false） |

---

## 二、数据分类统筹（分层模型）

把全部 CRM 对象分为六层，开发时按层归属、按层规划：

| 层 | 分类 | 对象 | 特点 |
|:---|:---|:---|:---|
| L1 核心对象 | 一切业务围绕的主体 | `Account 客户`、`Contact 联系人` | Account 承载 company/person/org，Contact 从属 Account |
| L2 交易对象 | 销售漏斗与签约 | `Opportunity 商机/线索`、`Quote 报价`、`QuoteItem 报价明细`、`Contract 合同`、`ContractItem 合同明细` | Quote 可转 Contract（1:1 派生） |
| L3 财务对象 | 钱与票 | `PaymentPlan 回款计划`、`Payment 回款`、`Invoice 发票` | 三者挂 Contract；Payment 可挂 PaymentPlan/Invoice |
| L4 服务对象 | 交付后服务 | `Warranty 质保`、`AfterSales 售后工单` | 挂 Contract/Product/Account |
| L5 支撑对象 | 基础数据与内容 | `Product 产品/服务`、`ProductCategory 分类`、`Activity 跟进`、`Tag 标签`、`Attachment 附件`、`Reminder 提醒` | Activity/Attachment/Tag/Reminder 多态 |
| L6 扩展对象 | 用户自建 | `CrmObjectDefs 对象定义`、`CrmCustomRecords 自定义记录` | 元数据驱动，JSON 宽表 |

**分类规则（新增对象时先归类再建表）**：

1. 是业务主体？→ L1；是销售流程单据？→ L2；是钱/票？→ L3；是交付后服务？→ L4；是基础/支撑数据？→ L5；用户自定义？→ L6。
2. L1–L5 对象用**强类型独立表**；只有 L6 走元数据引擎。
3. 任何新对象必须落在某一层，并在本指南「对象全景」登记。

---

## 三、对象全景与 ER 关系

```
Account(客户) 1──N Contact(联系人)
Account 1──N Opportunity(商机) ──N Quote(报价) 1──N QuoteItem
                              Quote ──1:1 转── Contract(合同) 1──N ContractItem
Opportunity ──N Contract（来源商机）
Contract 1──N PaymentPlan(回款计划) ──N Payment(回款)
Contract 1──N Invoice(发票)
Contract 1──N Warranty(质保)
Contract 1──N AfterSales(售后)
Product(产品) 1──N ProductCategory(分类)（两级）
任意实体 ── 多态 ── Activity / Attachment / Reminder / Tag
```

### 内置对象清单（= CRM 顶部 Tab，顺序即 Tab 顺序）

`account 客户 → contact 联系人 → opportunity 机会/线索 → contract 合同 → product 产品 → quote 报价 → paymentPlan 回款计划 → payment 回款 → invoice 发票 → warranty 质保 → afterSales 售后 → activity 跟进 → reminder 提醒`

> Tab 显示顺序与显隐由 `CrmPrefs` 控制（`crmTabVisible_<type>`），数据结构不变。

---

## 四、字段规范与枚举统一

### 4.1 公共字段（所有业务表）

| 字段 | 类型 | 规则 |
|:---|:---|:---|
| `id` | TEXT(36) | 主键，UUID v7（`Uuid().v7()`），不允许空 |
| `createdAt` | DATETIME | 创建时间，插入时写入 |
| `updatedAt` | DATETIME | 更新时间，每次更新写入 |
| `deleted` | BOOL | 软删除标记，默认 false；列表查询一律 `deleted == false` |

### 4.2 枚举统一（禁止散落魔法字符串）

| 枚举 | 取值（存库） | 说明 |
|:---|:---|:---|
| Account.type | `company` / `person` / `org` | 企业 / 个人 / 单位 |
| Account.level | `vip` / `normal` / `potential` | 客户等级 |
| Account.status | `active` / `inactive` / `blacklist` | 客户状态 |
| Opportunity.stage | `newLead` / `contacted` / `qualified` / `proposal` / `negotiation` / `closedWon` / `closedLost` / `abandoned` | 商机全生命周期（合并线索） |
| Opportunity.probability | 0–100 整数 | 成交概率 |
| Contract.status | `draft` / `active` / `completed` / `terminated` / `expired` | 合同状态 |
| Quote.status | `draft` / `sent` / `accepted` / `rejected` / `expired` | 报价状态 |
| PaymentPlan.status | `pending` / `partial` / `completed` / `overdue` | 回款计划状态 |
| Payment.method | `cash` / `transfer` / `check` / `wechat` / `alipay` | 回款方式 |
| Invoice.type | `vat_special` / `vat_normal` / `electronic` | 发票类型 |
| Invoice.status | `pending` / `issued` / `delivered` / `void` | 发票状态 |
| Warranty.status | `active` / `expired` / `void` | 质保状态 |
| AfterSales.type | `repair` / `install` / `consult` / `complaint` / `other` | 工单类型 |
| AfterSales.priority | `low` / `medium` / `high` / `urgent` | 优先级 |
| AfterSales.status | `open` / `inProgress` / `waitingCustomer` / `resolved` / `closed` | 工单状态 |
| Activity.type | `call` / `meeting` / `email` / `wechat` / `visit` / `task` / `note` | 跟进类型 |
| Activity.direction | `inbound` / `outbound` | 方向（可空） |
| Activity.status | `planned` / `completed` / `canceled` | 跟进状态 |
| Reminder.type | `paymentDue` / `warrantyExpire` / `followUp` / `contractExpire` / `custom` | 提醒类型 |
| 币种 | `CNY` / `USD` / `EUR` / `GBP` / `HKD` / `JPY` | 见 `kCurrencies`，默认币种可配（`crmDefaultCurrency`） |

### 4.3 币种与金额

- 金额字段统一 REAL，配套 `currency` 列（表级）或 `<字段>Currency` 映射键。
- 新建默认币种 = `CrmPrefs.defaultCurrency()`；无独立币种列的金额字段落库 `currency` 列。
- 展示用 `CrmCurrencyAmountField` 复合组件（币种下拉 | 金额输入），表单不再单独出现币种行。

### 4.4 字段命名

- 字段名 camelCase，外键 `<关联对象小写>Id`（`accountId`、`contactId`、`opportunityId`、`contractId`、`planId`、`productId`、`quoteId`、`warrantyId`、`invoiceId`）。
- 关系字段名（UI 层 relation 字段）用对象语义名（`account`、`contact`、`contract`…），通过 `kRelationDefs` 映射到外键与方向。
- 时间字段 `<名词>Date`（`signDate`）或 `<动词>At`（`scheduledAt`）；创建/更新固定 `createdAt`/`updatedAt`。

---

## 五、关联关系矩阵（双向）

> 方向语义：`A ← B` 表示 B 持有指向 A 的外键。`kRelationDefs` 中 `currentIsParent=true` 表示当前实体是父（多值，如 Account 下的 Contacts），`false` 表示当前是子（单值，如 Contact 的所属客户）。

| 父实体 | 子实体 | 外键 | 关系 | 说明 |
|:---|:---|:---|:---|:---|
| Account 客户 | Contact 联系人 | contact.accountId | 1:N | 联系人可无客户（可空） |
| Account 客户 | Opportunity 商机 | opportunity.accountId | 1:N | 可空 |
| Account 客户 | Contract 合同 | contract.accountId | 1:N | 可空 |
| Account 客户 | Quote 报价 | quote.accountId | 1:N | 可空 |
| Account 客户 | AfterSales 售后 | afterSales.accountId | 1:N | 必填 |
| Contact 联系人 | Opportunity 商机 | opportunity.contactId | 1:N | 主联系人 |
| Contact 联系人 | Contract 合同 | contract.contactId | 1:N | 签约联系人 |
| Contact 联系人 | Quote 报价 | quote.contactId | 1:N | 可空 |
| Contact 联系人 | AfterSales 售后 | afterSales.contactId | 1:N | 可空 |
| Opportunity 商机 | Quote 报价 | quote.opportunityId | 1:N | 可空 |
| Opportunity 商机 | Contract 合同 | contract.opportunityId | 1:N | 来源商机 |
| Quote 报价 | Contract 合同 | contract.quoteId | 1:1 | 转合同派生 |
| Contract 合同 | PaymentPlan 回款计划 | paymentPlan.contractId | 1:N | 必填 |
| Contract 合同 | Payment 回款 | payment.contractId | 1:N | 必填 |
| Contract 合同 | Invoice 发票 | invoice.contractId | 1:N | 必填 |
| Contract 合同 | Warranty 质保 | warranty.contractId | 1:N | 必填 |
| Contract 合同 | AfterSales 售后 | afterSales.contractId | 1:N | 可空 |
| PaymentPlan 回款计划 | Payment 回款 | payment.planId | 1:N | 临时回款可空 |
| Invoice 发票 | Payment 回款 | payment.invoiceId | 1:N | 可空 |
| Product 产品 | Warranty 质保 | warranty.productId | 1:N | 可空 |
| Product 产品 | QuoteItem/ContractItem | item.productId | 1:N | 快照 productName |
| 任意实体 | Activity/Attachment/Reminder/Tag | relatedType + relatedId | 多态 | 不建外键，靠类型+ID |

### 关联规则（双向无感）

1. 一个子实体只能有一个父（单值外键）；修改 = 覆盖，无需先解绑。
2. 父删除不级联删子：子实体外键置空（变为独立记录）。
3. 关联写入统一走 `CrmEntityLinker.link(parentType, parentId, targetType, targetId)`；`parentId=''` 表示解除关联。
4. 详情/新增的关系字段编辑统一走 `CrmEntityFieldUpdater` 外键写入或 `CrmEntityLinker`，禁止 UI 直接改库。
5. 事务原子性：创建 + 关联必须同一事务（`createCrmEntity` 创建 → link，失败整体回滚语义由调用方保证）。
6. 防重复：新建联系人/客户前按 name/phone 查重，提示「使用已有 / 仍然新建」，不阻断。

---

## 六、核心对象字段规范（开发遵循）

### Account（L1，客户/账户，统一承载 company/person/org）

`id, name, type, industry, level, source, phone, email, address, website, creditCode, note, status, createdAt, updatedAt, deleted`

### Contact（L1，联系人，从属 Account）

`id, accountId(可空), name, title, department, phone, email, wechat, isPrimary, isDecisionMaker, note, createdAt, updatedAt, deleted`

### Opportunity（L2，商机/线索，stage 覆盖全生命周期）

`id, name, accountId(可空), contactId(可空), stage, probability, amount, currency, source, leadContactName, leadPhone, leadEmail, expectedCloseDate, actualCloseDate, lossReason, note, createdAt, updatedAt, deleted`

> `lead*` 为线索暂存字段：商机未关联 Account/Contact 时可暂存联系人信息；关联后保留（历史快照），不强制清空。

### Quote + QuoteItem（L2，报价）

Quote：`id, quoteNo(自动 QT-YYYYMMDD-XXX), opportunityId, accountId, contactId, status, currency, totalAmount, discountAmount, validUntil, note, createdAt, updatedAt, deleted`

QuoteItem：`id, quoteId, productId(可空), productName(快照), quantity, unitPrice, discount, amount(=quantity×unitPrice×discount), sortOrder`

### Contract + ContractItem（L2，合同）

Contract：`id, contractNo(自动 HT-YYYYMMDD-XXX), name, accountId, contactId, opportunityId, quoteId, status, currency, totalAmount, paidAmount(冗余), invoicedAmount(冗余), signDate, startDate, endDate, warrantyEndDate, note, createdAt, updatedAt, deleted`

ContractItem：`id, contractId, productId(可空), productName(快照), quantity, unitPrice, amount, warrantyMonths, sortOrder`

### L3 财务对象

- PaymentPlan：`id, contractId, planName, planAmount, paidAmount(冗余), planDate, status`
- Payment：`id, contractId, planId(可空), amount, currency, paymentDate, method, invoiceId(可空), note, createdAt`
- Invoice：`id, contractId, invoiceNo, type, amount, currency, taxRate, issueDate, status, receiverName, note, createdAt`

> 写入 Payment 时同步累加 Contract.paidAmount、PaymentPlan.paidAmount；写入 Invoice 时同步累加 Contract.invoicedAmount（财务一致性规则）。

### L4 服务对象

- Warranty：`id, contractId, contractItemId(可空), productId(可空), serialNo, startDate, endDate, status, note, createdAt`
- AfterSales：`id, ticketNo(自动 AS-YYYYMMDD-XXX), accountId, contactId(可空), contractId(可空), warrantyId(可空), type, priority, status, subject, description, resolution, resolvedAt, closedAt, note, createdAt, updatedAt, deleted`

### L5 支撑对象

- Product：`id, categoryId(可空), name, sku, type, unit, currency, price, cost, warrantyMonths, isActive, note, createdAt, updatedAt, deleted`
- ProductCategory：`id, name, parentId(可空，两级)`
- Activity：`id, type, direction(可空), relatedType, relatedId, subject, content, status, scheduledAt(可空), completedAt(可空), createdAt`（多态）
- Tag / EntityTag：`Tag(id, name唯一, color)`；`EntityTag(entityType, entityId, tagId)` 联合主键（多态 N:M）
- Attachment：`id, relatedType, relatedId, fileName, filePath, mimeType, fileSize, createdAt`（多态；文件存沙盒，表内记路径）
- Reminder：`id, relatedType(可空), relatedId(可空), type, title, remindAt, isCompleted, createdAt`（多态）
- QuoteVersion：`id, quoteId, versionNo, snapshotJson{quote,items}, createdAt`（报价版本快照）

### L6 扩展对象（元数据驱动）

- CrmObjectDefs：`id(对象键), labelSingular, labelPlural, icon, fieldsJson[{name,label,type,options,required,order}], builtin, createdAt, updatedAt`
- CrmCustomRecords：`id, objectId, label(展示名), dataJson(Map 宽表), createdAt, updatedAt, deleted`

> 内置对象 `builtin=true` 不允许删除；自定义对象删除 = 同时删其全部记录（同一事务）。

---

## 七、通用开发规范

1. **新增表/字段流程**：改 `app_database.dart` → `dart run build_runner build` → 同步更新本指南 → 必要时补迁移（`migration.dart`）。
2. **软删除**：删除一律置 `deleted=true`，物理删除仅限自定义对象级联与清空数据。
3. **外键可空性**：子侧外键默认可空（允许渐进补全）；仅业务强相关（Payment/Invoice/Warranty → Contract）必填。
4. **多态字段**：`relatedType` 用小写对象键（`account/contact/opportunity/contract/quote/paymentPlan/payment/invoice/warranty/afterSales/custom:<id>`）。
5. **冗余字段**：只允许单向冗余（Contract ← 流水聚合、PaymentPlan ← Payment 聚合、明细快照 productName），写入方负责同步，读取不实时聚合。
6. **编号生成**：`QT-/HT-/AS-YYYYMMDD-XXX`，同一前缀+日期内序号递增，冲突重试。
7. **关系字段 UI**：一律用统一关联交互（见第八章），不在 UI 手写外键赋值。
8. **视图数据**：表格/详情展示用 `CrmEntityCache` 快照 + `accountToDataMap/contactToDataMap/...` 映射；关系列填充对象名称（`joinRelationNames`）。
9. **Preference 键**：新增键必须进 `PrefUtil.prefAllowList` 或使用现有前缀（`crmTabVisible_`、`crmTableColumns_`、`crmTableHidden_`、`crmTableColumnsCustomized_`、`crmFieldMeta_`）。

---

## 八、双向无感关联交互规范（Twenty 风格）

**目标**：用户不应感知"关联"和"新建"是两个独立操作。

### 8.1 交互状态机

```
显示当前值 → 点击展开搜索 → 输入≥1字符(300ms 防抖) → 结果列表
  ├─ 选已有记录 → 立即关联（乐观更新，UI 即时刷新）
  ├─ 无匹配 → 「未找到 xxx」+「+ 新建 xxx」(预填搜索词)
  └─ 点新建 → 内联极简表单（1-2 必填字段）→ 创建即关联 → 回填显示
```

### 8.2 落地组件（本项目技术栈，非 Riverpod）

| 场景 | 组件/位置 | 说明 |
|:---|:---|:---|
| 子侧关系字段（联系人所属客户等） | `CrmEntityDetailView._buildRelationTile` | 原位下拉：选已有/取消关联/新增并挂到 |
| 父侧关系字段（客户联系人等） | 同上（`currentIsParent=true`） | 显示对象名称列表，下拉新增/关联已有 |
| 新增表单关系选择 | `CrmCreateFormPanel._relationInput` | 下拉候选（含「不关联」），保存写外键 |
| 详情关联业务区 | `_assocSection` + `_assocPicker` | 按类型分组新增/关联已有 |
| 关联写入 | `CrmEntityLinker` / `CrmEntityFieldUpdater` | 统一外键写入，支持解除 |
| 新建并关联 | `createCrmEntity` + `_LinkContext`（正向/反向） | 创建后自动 link，逐层返回 |

### 8.3 规则

1. 搜索：按名称（联系人含手机/邮箱）`updatedAt DESC` 排序，限 20 条；空输入显示最近 5 条（Phase 2）。
2. 选择即保存：无独立"保存关联"按钮。
3. 新建最少字段：联系人 `name`（+手机/职位可选）；客户 `name`（+类型可选）。
4. 创建即关联：公司侧新建联系人自动带 `accountId`；联系人侧新建公司后回填 `accountId`。
5. 防重复：按 name/phone 查重，提示「使用已有 / 仍然新建」。
6. 键盘导航：↑↓ 选择、Enter 确认、Esc 关闭（Phase 2）。
7. 桌面右侧栏面板栈 + Offstage 保留层级，返回记住回程；移动端走整页导航栈。

---

## 九、与主流 CRM 对照

| 本项目 | Twenty | HubSpot | Salesforce |
|:---|:---|:---|:---|
| Account（company/person/org） | Company / Person | Company / Contact | Account / Contact |
| Opportunity（合并 Lead） | Opportunity | Deal + Lead | Opportunity + Lead |
| Quote / Contract | Quote / Contract | Quote | Quote / Contract |
| PaymentPlan / Payment / Invoice | 无内建 | 自定义 | 自定义 |
| Warranty / AfterSales | 无内建 | 自定义 | Case |
| Activity（多态跟进） | Timeline Activities | Engagements | Task/Event |
| Tag（多态） | Favorites + Tags | Properties | Tags |
| Attachment（多态） | Attachments | Files | Notes/Attachment |
| Reminder | 无内建 | Tasks | Activities |
| 自定义对象 | Custom Objects | Custom Objects | Custom Objects |

---

## 十、数据生命周期与维护

### 10.1 商机状态机

```
newLead → contacted → qualified → proposal → negotiation → closedWon ✅
                              └──────────────→ closedLost ❌ / abandoned 🗑️
```

### 10.2 合同履约

```
draft → active → completed / terminated / expired
active 期间：PaymentPlan 按期跟踪、Payment 累加 paidAmount、Invoice 累加 invoicedAmount
到期：endDate 触发 contractExpire 提醒；质保：warrantyEndDate 触发 warrantyExpire
```

### 10.3 级联规则

- 删除 Account：不删 Contact/Opportunity/Contract/Quote，外键置空（独立记录）。
- 删除 Contact：Opportunity/Contract/Quote 的 contactId 置空。
- 删除 Contract：PaymentPlan/Payment/Invoice/Warranty/AfterSales 保留（历史凭证），contractId 置空或保留引用按业务判断（默认保留引用）。
- 删除自定义对象：级联删除其全部记录。

### 10.4 数据维护

- 演示数据：`CrmDemoData.seed` 每表 5–10 条带关联，仅供验证。
- 数据健康：见数据健康度页（孤儿附件、缺外键等）。
- 备份：全量导入导出已支持（`CrmBackupCodec`）。

---

## 十一、开发遵循清单（Checklist）

- [ ] 新对象先归类到 L1–L6，再决定强类型表 or 元数据引擎
- [ ] 枚举取值抄自本指南 4.2，不发明新魔法字符串
- [ ] 外键命名 `<对象>Id`，关系字段注册进 `kRelationDefs`
- [ ] 所有业务表带 `createdAt/updatedAt/deleted`
- [ ] 金额带币种；明细冗余业务名称快照
- [ ] 关联写入走 `CrmEntityLinker`/`CrmEntityFieldUpdater`，不手写 SQL
- [ ] 新增 Pref 键进 `PrefUtil` 白名单
- [ ] 新增表/字段后同步更新本指南
- [ ] 改动后：`dart analyze` 0 error → `flutter test` → Windows 构建 → 提交

---

> **文档版本**：v1.0 | **最后更新**：2026-08-24 | **状态**：生效中
