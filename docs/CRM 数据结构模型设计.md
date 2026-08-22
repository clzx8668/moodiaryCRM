
# CRM 数据结构模型设计

> **定位**：单人使用 · 本地优先 · 隐私安全 · 跨平台（Flutter + Drift）
> **参照**：SuiteCRM / EspoCRM / Twenty CRM 最佳实践
> **项目**：Moodiary CRM 模块
> **版本**：v1.0 · 2026-08-22

---

## 一、设计理念

| 原则 | 说明 |
|:---|:---|
| **本地优先** | 所有数据存储在本地 SQLite（Drift），不依赖云端 |
| **单人简化** | 去掉多租户、审批流、角色权限、线索清洗等组织级概念 |
| **线索与商机合并** | 单人场景下，录入即商机，通过 `stage` 阶段区分生命周期 |
| **多态关联** | Activity 通过 `relatedType + relatedId` 统一关联任意实体 |
| **快照防篡改** | 合同/报价明细中冗余产品名称，防止产品修改后历史数据失真 |
| **冗余换性能** | 合同表冗余 `paidAmount`、`invoicedAmount`，避免实时聚合 |
| **Block 协议兼容** | 每条实体可作为 Block 容器，承载语音转写、AI 摘要等多模态内容 |

---

## 二、ER 关系总览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  ┌──────────────┐  1:N   ┌──────────────┐                              │
│  │   Account    │◀──────│   Contact    │                              │
│  │  (客户/单位)  │        │   (联系人)    │                              │
│  └──────┬───────┘        └──────┬───────┘                              │
│         │ 1:N                   │ 1:N                                  │
│         │                       │                                      │
│         ▼                       ▼                                      │
│  ┌──────────────────────────────────────┐                              │
│  │          Opportunity (商机)           │                              │
│  │  含原线索功能，stage 覆盖全生命周期     │                              │
│  └──────────────┬───────────────────────┘                              │
│                 │ 1:N                                                   │
│                 ▼                                                       │
│  ┌──────────────┐  1:N   ┌──────────────┐                             │
│  │    Quote     │──────▶│  QuoteItem   │                             │
│  │  (报价单)     │        │  (报价明细)   │                             │
│  └──────┬───────┘        └──────────────┘                             │
│         │ 1:1 转合同                                                   │
│         ▼                                                              │
│  ┌──────────────┐  1:N   ┌──────────────┐                             │
│  │   Contract   │──────▶│ContractItem  │                             │
│  │   (合同)      │        │ (合同明细)    │                             │
│  └──┬───┬───┬───┘        └──────────────┘                             │
│     │   │   │                                                         │
│     │   │   └──────────────────────────┐                              │
│     │   │                              ▼                              │
│     │   │                       ┌────────────┐                        │
│     │   │                       │  Warranty  │                        │
│     │   │                       │   (质保)    │                        │
│     │   │                       └─────┬──────┘                        │
│     │   │                             │ 1:N                           │
│     │   ▼                             ▼                               │
│     │  ┌────────────┐          ┌────────────┐                        │
│     │  │  Invoice   │          │ AfterSales │                        │
│     │  │  (发票)     │          │ (售后工单)  │                        │
│     │  └────────────┘          └────────────┘                        │
│     │                                                                 │
│     ▼                                                                 │
│  ┌────────────┐  1:N   ┌────────────┐                                │
│  │PaymentPlan │──────▶│  Payment   │                                │
│  │(回款计划)   │        │ (回款记录)  │                                │
│  └────────────┘        └────────────┘                                │
│                                                                         │
│  ┌────────────┐          ┌────────────┐                               │
│  │  Product   │◀────────│  Category  │                               │
│  │(产品/服务)  │          │  (分类)     │                               │
│  └────────────┘          └────────────┘                               │
│                                                                         │
│  ┌────────────────────────────────────┐                                │
│  │  Activity (跟进记录/活动)           │  ← 多态关联任意实体            │
│  └────────────────────────────────────┘                                │
│                                                                         │
│  ┌────────────┐  N:M    ┌────────────┐                                │
│  │    Tag     │◀──────▶│ EntityTag  │  ← 任意实体可打标签              │
│  └────────────┘         └────────────┘                                │
│                                                                         │
│  ┌────────────┐                                                        │
│  │ Attachment │  ← 合同扫描件/发票照片/产品图片                          │
│  └────────────┘                                                        │
│                                                                         │
│  ┌────────────┐                                                        │
│  │  Reminder  │  ← 回款/质保/跟进到期提醒                               │
│  └────────────┘                                                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 三、核心实体详细设计

### 3.1 Account（客户/账户）

> 统一承载公司、个人、单位三种客户类型。

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `name` | TEXT | NOT NULL | 客户名称 |
| `type` | TEXT | NOT NULL | `company` / `person` / `org` |
| `industry` | TEXT | | 行业 |
| `level` | TEXT | DEFAULT `normal` | `vip` / `normal` / `potential` |
| `source` | TEXT | | 来源：`referral` / `ad` / `website` / `exhibition` / `referral` / `other` |
| `phone` | TEXT | | 主联系电话 |
| `email` | TEXT | | 主邮箱 |
| `address` | TEXT | | 地址 |
| `website` | TEXT | | 网址 |
| `creditCode` | TEXT | | 统一社会信用代码（企业客户） |
| `note` | TEXT | | 备注 |
| `status` | TEXT | DEFAULT `active` | `active` / `inactive` / `blacklist` |
| `syncStatus` | INTEGER | DEFAULT 0 | 0未同步 / 1已同步 / 2待推送 / 3冲突 |
| `createdAt` | INTEGER | NOT NULL | Unix 时间戳 |
| `updatedAt` | INTEGER | NOT NULL | Unix 时间戳 |

### 3.2 Contact（联系人）

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `accountId` | TEXT(36) | FK → Account, NULLABLE | 所属客户（独立联系人可为空） |
| `name` | TEXT | NOT NULL | 姓名 |
| `title` | TEXT | | 职位 |
| `department` | TEXT | | 部门 |
| `phone` | TEXT | | 手机 |
| `email` | TEXT | | 邮箱 |
| `wechat` | TEXT | | 微信号 |
| `isPrimary` | BOOL | DEFAULT false | 是否主联系人 |
| `isDecisionMaker` | BOOL | DEFAULT false | 是否决策人 |
| `note` | TEXT | | 备注 |
| `createdAt` | INTEGER | NOT NULL | |
| `updatedAt` | INTEGER | NOT NULL | |

### 3.3 Opportunity（商机）⭐ 合并线索

> **设计决策**：不单独设置 Lead 表。单人场景下，录入即商机，通过 `stage` 的前三个阶段（`newLead → contacted → qualified`）承载原线索职责。

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `name` | TEXT | NOT NULL | 商机名称 |
| `accountId` | TEXT(36) | FK → Account, NULLABLE | 关联客户（初期可为空） |
| `contactId` | TEXT(36) | FK → Contact, NULLABLE | 主联系人 |
| `stage` | TEXT | NOT NULL | 阶段枚举（见下方） |
| `probability` | INTEGER | DEFAULT 0 | 成交概率 0-100 |
| `amount` | REAL | DEFAULT 0.0 | 预计金额 |
| `currency` | TEXT | DEFAULT `CNY` | 币种 |
| `source` | TEXT | | 来源渠道 |
| `leadContactName` | TEXT | NULLABLE | 初始联系人（未关联 Account 时暂存） |
| `leadPhone` | TEXT | NULLABLE | 初始电话 |
| `leadEmail` | TEXT | NULLABLE | 初始邮箱 |
| `expectedCloseDate` | INTEGER | NULLABLE | 预计成交日期 |
| `actualCloseDate` | INTEGER | NULLABLE | 实际成交日期 |
| `lossReason` | TEXT | NULLABLE | 输单/放弃原因 |
| `note` | TEXT | | 备注 |
| `syncStatus` | INTEGER | DEFAULT 0 | 同步状态 |
| `createdAt` | INTEGER | NOT NULL | |
| `updatedAt` | INTEGER | NOT NULL | |

**商机阶段枚举（完整生命周期）：**

```
newLead → contacted → qualified → proposal → negotiation → closedWon
 新线索     已联系      需求确认     方案报价     商务谈判      ✅ 赢单
                                                          ──▶ closedLost  ❌ 输单
                                                          ──▶ abandoned   🗑️ 放弃
```

| 阶段 | 含义 | 对应传统概念 |
|:---|:---|:---|
| `newLead` | 刚录入，待初步联系 | 原 Lead.status = new |
| `contacted` | 已初步沟通 | 原 Lead.status = contacted |
| `qualified` | 确认有真实需求，值得跟进 | 原 Lead → Opportunity 转化点 |
| `proposal` | 方案/报价阶段 | 原 Opportunity |
| `negotiation` | 商务谈判 | 原 Opportunity |
| `closedWon` | 赢单 | 原 Opportunity closed_won |
| `closedLost` | 输单 | 原 Opportunity closed_lost |
| `abandoned` | 放弃/无效 | 原 Lead.status = rejected |

### 3.4 Product（产品/服务）+ Category（分类）

**Category：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `name` | TEXT | NOT NULL | 分类名称 |
| `parentId` | TEXT(36) | FK → Category, NULLABLE | 父分类（支持两级） |

**Product：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `categoryId` | TEXT(36) | FK → Category, NULLABLE | 分类 |
| `name` | TEXT | NOT NULL | 产品名称 |
| `sku` | TEXT | UNIQUE | 编码 |
| `type` | TEXT | DEFAULT `product` | `product` / `service` |
| `unit` | TEXT | | 单位（个/套/年/次） |
| `price` | REAL | DEFAULT 0.0 | 标准单价 |
| `cost` | REAL | DEFAULT 0.0 | 成本价 |
| `warrantyMonths` | INTEGER | DEFAULT 0 | 默认质保月数 |
| `isActive` | BOOL | DEFAULT true | 是否在售 |
| `note` | TEXT | | 描述 |
| `createdAt` | INTEGER | NOT NULL | |
| `updatedAt` | INTEGER | NOT NULL | |

### 3.5 Quote（报价单）+ QuoteItem（报价明细）

**Quote：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `quoteNo` | TEXT | UNIQUE | 报价单号（自动生成：QT-YYYYMMDD-XXX） |
| `opportunityId` | TEXT(36) | FK → Opportunity | 关联商机 |
| `accountId` | TEXT(36) | FK → Account | 客户 |
| `contactId` | TEXT(36) | FK → Contact, NULLABLE | 联系人 |
| `status` | TEXT | DEFAULT `draft` | `draft` / `sent` / `accepted` / `rejected` / `expired` |
| `totalAmount` | REAL | DEFAULT 0.0 | 总金额 |
| `discountAmount` | REAL | DEFAULT 0.0 | 折扣金额 |
| `validUntil` | INTEGER | NULLABLE | 有效期 |
| `note` | TEXT | | |
| `createdAt` | INTEGER | NOT NULL | |
| `updatedAt` | INTEGER | NOT NULL | |

**QuoteItem：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `quoteId` | TEXT(36) | FK → Quote | 所属报价单 |
| `productId` | TEXT(36) | FK → Product, NULLABLE | 产品 |
| `productName` | TEXT | NOT NULL | 产品名快照 |
| `quantity` | REAL | DEFAULT 1 | 数量 |
| `unitPrice` | REAL | NOT NULL | 单价 |
| `discount` | REAL | DEFAULT 1.0 | 折扣率（1.0=无折扣） |
| `amount` | REAL | NOT NULL | 小计 = quantity × unitPrice × discount |
| `sortOrder` | INTEGER | DEFAULT 0 | 排序 |

### 3.6 Contract（合同）+ ContractItem（合同明细）

**Contract：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `contractNo` | TEXT | UNIQUE | 合同编号（HT-YYYYMMDD-XXX） |
| `name` | TEXT | NOT NULL | 合同名称 |
| `accountId` | TEXT(36) | FK → Account | 客户 |
| `contactId` | TEXT(36) | FK → Contact, NULLABLE | 签约联系人 |
| `opportunityId` | TEXT(36) | FK → Opportunity, NULLABLE | 来源商机 |
| `quoteId` | TEXT(36) | FK → Quote, NULLABLE | 来源报价单 |
| `status` | TEXT | DEFAULT `draft` | `draft` / `active` / `completed` / `terminated` / `expired` |
| `totalAmount` | REAL | DEFAULT 0.0 | 合同总金额 |
| `paidAmount` | REAL | DEFAULT 0.0 | 已回款金额（冗余） |
| `invoicedAmount` | REAL | DEFAULT 0.0 | 已开票金额（冗余） |
| `signDate` | INTEGER | NULLABLE | 签约日期 |
| `startDate` | INTEGER | NULLABLE | 合同开始日期 |
| `endDate` | INTEGER | NULLABLE | 合同结束日期 |
| `warrantyEndDate` | INTEGER | NULLABLE | 质保到期日 |
| `note` | TEXT | | |
| `syncStatus` | INTEGER | DEFAULT 0 | 同步状态 |
| `createdAt` | INTEGER | NOT NULL | |
| `updatedAt` | INTEGER | NOT NULL | |

**ContractItem：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `contractId` | TEXT(36) | FK → Contract | 所属合同 |
| `productId` | TEXT(36) | FK → Product, NULLABLE | 产品 |
| `productName` | TEXT | NOT NULL | 产品名快照 |
| `quantity` | REAL | DEFAULT 1 | 数量 |
| `unitPrice` | REAL | NOT NULL | 单价 |
| `amount` | REAL | NOT NULL | 小计 |
| `warrantyMonths` | INTEGER | DEFAULT 0 | 该项质保月数 |
| `sortOrder` | INTEGER | DEFAULT 0 | 排序 |

### 3.7 PaymentPlan（回款计划）+ Payment（回款记录）

**PaymentPlan：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `contractId` | TEXT(36) | FK → Contract | 所属合同 |
| `planName` | TEXT | NOT NULL | 期次名称（首付款/进度款/尾款） |
| `planAmount` | REAL | NOT NULL | 计划金额 |
| `paidAmount` | REAL | DEFAULT 0.0 | 已收金额（冗余） |
| `planDate` | INTEGER | NOT NULL | 计划回款日期 |
| `status` | TEXT | DEFAULT `pending` | `pending` / `partial` / `completed` / `overdue` |

**Payment：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `contractId` | TEXT(36) | FK → Contract | 所属合同 |
| `planId` | TEXT(36) | FK → PaymentPlan, NULLABLE | 关联回款计划（临时回款可为空） |
| `amount` | REAL | NOT NULL | 实际回款金额 |
| `paymentDate` | INTEGER | NOT NULL | 回款日期 |
| `method` | TEXT | NOT NULL | `cash` / `transfer` / `check` / `wechat` / `alipay` |
| `invoiceId` | TEXT(36) | FK → Invoice, NULLABLE | 关联发票 |
| `note` | TEXT | | 备注 |
| `createdAt` | INTEGER | NOT NULL | |

### 3.8 Invoice（发票）

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `contractId` | TEXT(36) | FK → Contract | 所属合同 |
| `invoiceNo` | TEXT | NULLABLE | 发票号 |
| `type` | TEXT | NOT NULL | `vat_special` / `vat_normal` / `electronic` |
| `amount` | REAL | NOT NULL | 开票金额 |
| `taxRate` | REAL | DEFAULT 0.13 | 税率 |
| `issueDate` | INTEGER | NULLABLE | 开票日期 |
| `status` | TEXT | DEFAULT `pending` | `pending` / `issued` / `delivered` / `void` |
| `receiverName` | TEXT | NULLABLE | 收票人 |
| `note` | TEXT | | |
| `createdAt` | INTEGER | NOT NULL | |

### 3.9 Warranty（质保）

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `contractId` | TEXT(36) | FK → Contract | 所属合同 |
| `contractItemId` | TEXT(36) | FK → ContractItem, NULLABLE | 关联合同明细项 |
| `productId` | TEXT(36) | FK → Product, NULLABLE | 质保产品 |
| `serialNo` | TEXT | NULLABLE | 设备序列号 |
| `startDate` | INTEGER | NOT NULL | 质保开始日 |
| `endDate` | INTEGER | NOT NULL | 质保到期日 |
| `status` | TEXT | DEFAULT `active` | `active` / `expired` / `void` |
| `note` | TEXT | | |
| `createdAt` | INTEGER | NOT NULL | |

### 3.10 AfterSales（售后工单）

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `ticketNo` | TEXT | UNIQUE | 工单号（AS-YYYYMMDD-XXX） |
| `accountId` | TEXT(36) | FK → Account | 客户 |
| `contactId` | TEXT(36) | FK → Contact, NULLABLE | 报修联系人 |
| `contractId` | TEXT(36) | FK → Contract, NULLABLE | 关联合同 |
| `warrantyId` | TEXT(36) | FK → Warranty, NULLABLE | 关联质保 |
| `type` | TEXT | NOT NULL | `repair` / `install` / `consult` / `complaint` / `other` |
| `priority` | TEXT | DEFAULT `medium` | `low` / `medium` / `high` / `urgent` |
| `status` | TEXT | DEFAULT `open` | `open` / `in_progress` / `waiting_customer` / `resolved` / `closed` |
| `subject` | TEXT | NOT NULL | 主题 |
| `description` | TEXT | | 问题描述 |
| `resolution` | TEXT | | 解决方案 |
| `resolvedAt` | INTEGER | NULLABLE | 解决时间 |
| `closedAt` | INTEGER | NULLABLE | 关闭时间 |
| `note` | TEXT | | |
| `createdAt` | INTEGER | NOT NULL | |
| `updatedAt` | INTEGER | NOT NULL | |

### 3.11 Activity（跟进记录 / 活动）

> 通过 `relatedType + relatedId` 多态关联任意实体，一张表覆盖所有交互记录。

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `type` | TEXT | NOT NULL | `call` / `meeting` / `email` / `wechat` / `visit` / `task` / `note` |
| `direction` | TEXT | NULLABLE | `inbound` / `outbound`（通话/邮件方向） |
| `relatedType` | TEXT | NOT NULL | `account` / `contact` / `opportunity` / `contract` / `aftersales` |
| `relatedId` | TEXT | NOT NULL | 关联实体 ID |
| `subject` | TEXT | NOT NULL | 主题 |
| `content` | TEXT | | 内容（支持 Markdown） |
| `status` | TEXT | DEFAULT `completed` | `planned` / `completed` / `canceled` |
| `scheduledAt` | INTEGER | NULLABLE | 计划时间 |
| `completedAt` | INTEGER | NULLABLE | 完成时间 |
| `createdAt` | INTEGER | NOT NULL | |

### 3.12 Tag + EntityTag（标签系统）

**Tag：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `name` | TEXT | UNIQUE | 标签名 |
| `color` | TEXT | DEFAULT `#4CAF50` | 颜色 |

**EntityTag（多对多中间表）：**

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `entityType` | TEXT | NOT NULL | 实体类型 |
| `entityId` | TEXT | NOT NULL | 实体 ID |
| `tagId` | TEXT(36) | FK → Tag | 标签 ID |
| | | PK(`entityType`, `entityId`, `tagId`) | 联合主键 |

### 3.13 Attachment（附件）

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `relatedType` | TEXT | NOT NULL | 关联实体类型 |
| `relatedId` | TEXT | NOT NULL | 关联实体 ID |
| `fileName` | TEXT | NOT NULL | 文件名 |
| `filePath` | TEXT | NOT NULL | 本地沙盒路径 |
| `mimeType` | TEXT | | MIME 类型 |
| `fileSize` | INTEGER | | 文件大小（bytes） |
| `createdAt` | INTEGER | NOT NULL | |

### 3.14 Reminder（提醒）

| 字段 | 类型 | 约束 | 说明 |
|:---|:---|:---|:---|
| `id` | TEXT(36) | PK | UUID |
| `relatedType` | TEXT | NOT NULL | 关联实体类型 |
| `relatedId` | TEXT | NOT NULL | 关联实体 ID |
| `type` | TEXT | NOT NULL | `payment_due` / `warranty_expire` / `follow_up` / `contract_expire` / `custom` |
| `title` | TEXT | NOT NULL | 提醒标题 |
| `remindAt` | INTEGER | NOT NULL | 提醒时间 |
| `isCompleted` | BOOL | DEFAULT false | 是否已处理 |
| `createdAt` | INTEGER | NOT NULL | |

---

## 四、核心业务逻辑流程

### 4.1 商机全生命周期

```
录入商机 (stage=newLead)
  │
  ├── 初步联系 (stage=contacted)
  │     └── 记录 Activity (type=call/wechat/visit)
  │
  ├── 确认需求 (stage=qualified)  ← 原"线索转化"节点
  │     ├── 创建/关联 Account
  │     ├── 创建/关联 Contact
  │     ├── 清空 lead* 临时字段
  │     └── 记录 Activity
  │
  ├── 方案报价 (stage=proposal)
  │     ├── 创建 Quote + QuoteItem
  │     └── 记录 Activity
  │
  ├── 商务谈判 (stage=negotiation)
  │     ├── 修改 Quote / 重新报价
  │     └── 记录 Activity
  │
  ├── ✅ 赢单 (stage=closedWon)
  │     ├── 创建 Contract（从 Quote 导入明细）
  │     ├── 创建 PaymentPlan（回款计划）
  │     ├── 创建 Warranty（质保）
  │     └── 记录 Activity
  │
  ├── ❌ 输单 (stage=closedLost)
  │     └── 记录 lossReason + Activity
  │
  └── 🗑️ 放弃 (stage=abandoned)
        └── 记录原因 + Activity
```

### 4.2 合同履约流程

```
Contract (status=draft)
  │
  ├──▶ status = 'active'（签约生效）
  │     │
  │     ├── 回款跟踪
  │     │     ├── PaymentPlan 按期跟踪
  │     │     ├── 收到 Payment → 更新 plan.paidAmount
  │     │     ├── 更新 contract.paidAmount（累加）
  │     │     └── 全部收完 → 所有 plan.status = 'completed'
  │     │
  │     ├── 开票管理
  │     │     ├── 创建 Invoice
  │     │     ├── 更新 contract.invoicedAmount（累加）
  │     │     └── Payment 可关联 Invoice
  │     │
  │     └── 质保计时
  │           └── Warranty.status = 'active'
  │
  ├──▶ status = 'completed'（履约完毕）
  │     条件：paidAmount == totalAmount 且 所有 Invoice 已交付
  │
  └──▶ status = 'terminated'（提前终止）
        └── 可关联 AfterSales 工单
```

### 4.3 售后闭环流程

```
AfterSales (status=open)
  │
  ├── 判断质保
  │     ├── 关联 Warranty → 在保 → 免费维修
  │     └── 过保 → 生成新 Quote → 新 Contract（增购/维修合同）
  │
  ├── 处理过程
  │     ├── status = 'in_progress'
  │     ├── 记录 Activity（处理记录）
  │     └── 如需等待客户 → status = 'waiting_customer'
  │
  ├── 解决
  │     ├── status = 'resolved'
  │     ├── 填写 resolution
  │     └── 记录 resolvedAt
  │
  └── 关闭
        ├── status = 'closed'
        ├── 记录 closedAt
        └── 关联 Activity 归入客户时间线
```

### 4.4 提醒触发规则

| 提醒类型 | 触发条件 | 提前时间 |
|:---|:---|:---|
| `payment_due` | PaymentPlan.planDate 临近且 status ≠ completed | 提前 3 天 |
| `warranty_expire` | Warranty.endDate 临近且 status = active | 提前 30 天 |
| `follow_up` | Opportunity 超过 N 天无 Activity | 可配置（默认 7 天） |
| `contract_expire` | Contract.endDate 临近且 status = active | 提前 30 天 |

---

## 五、编号规则

| 实体 | 格式 | 示例 |
|:---|:---|:---|
| 报价单 | `QT-YYYYMMDD-XXX` | QT-20260822-001 |
| 合同 | `HT-YYYYMMDD-XXX` | HT-20260822-001 |
| 售后工单 | `AS-YYYYMMDD-XXX` | AS-20260822-001 |
| 发票 | 手动录入 | 04412345 |

> `XXX` 为当日自增序号，从 001 开始。

---

## 六、索引设计

```sql
-- 高频查询索引
CREATE INDEX idx_contact_account ON contacts(account_id);
CREATE INDEX idx_opportunity_account ON opportunities(account_id);
CREATE INDEX idx_opportunity_stage ON opportunities(stage);
CREATE INDEX idx_contract_account ON contracts(account_id);
CREATE INDEX idx_contract_status ON contracts(status);
CREATE INDEX idx_payment_contract ON payments(contract_id);
CREATE INDEX idx_invoice_contract ON invoices(contract_id);
CREATE INDEX idx_warranty_contract ON warranties(contract_id);
CREATE INDEX idx_warranty_end ON warranties(end_date);
CREATE INDEX idx_aftersales_account ON after_sales(account_id);
CREATE INDEX idx_aftersales_status ON after_sales(status);
CREATE INDEX idx_activity_related ON activities(related_type, related_id);
CREATE INDEX idx_activity_scheduled ON activities(scheduled_at);
CREATE INDEX idx_reminder_time ON reminders(remind_at, is_completed);
CREATE INDEX idx_entity_tag ON entity_tags(entity_type, entity_id);
CREATE INDEX idx_attachment_related ON attachments(related_type, related_id);
CREATE INDEX idx_payment_plan_contract ON payment_plans(contract_id);
CREATE INDEX idx_payment_plan_date ON payment_plans(plan_date);
```

---

## 七、Drift 表定义代码

### 7.1 枚举定义

```dart
// lib/src/db/crm_enums.dart

enum AccountType { company, person, org }
enum AccountLevel { vip, normal, potential }
enum AccountStatus { active, inactive, blacklist }

enum OpportunityStage {
  newLead,       // 新线索
  contacted,     // 已联系
  qualified,     // 需求确认
  proposal,      // 方案报价
  negotiation,   // 商务谈判
  closedWon,     // 赢单
  closedLost,    // 输单
  abandoned,     // 放弃
}

enum QuoteStatus { draft, sent, accepted, rejected, expired }
enum ContractStatus { draft, active, completed, terminated, expired }
enum PaymentPlanStatus { pending, partial, completed, overdue }
enum PaymentMethod { cash, transfer, check, wechat, alipay }
enum InvoiceType { vatSpecial, vatNormal, electronic }
enum InvoiceStatus { pending, issued, delivered, void_ }
enum WarrantyStatus { active, expired, void_ }
enum AfterSalesType { repair, install, consult, complaint, other }
enum AfterSalesStatus { open, inProgress, waitingCustomer, resolved, closed }
enum Priority { low, medium, high, urgent }
enum ActivityType { call, meeting, email, wechat, visit, task, note }
enum ActivityDirection { inbound, outbound }
enum ActivityStatus { planned, completed, canceled }
enum ProductType { product, service }
enum ReminderType { paymentDue, warrantyExpire, followUp, contractExpire, custom }
```

### 7.2 表定义

```dart
// lib/src/db/crm_tables.dart

import 'package:drift/drift.dart';
import 'crm_enums.dart';

// ============ 客户 ============
@DataClassName('AccountEntity')
class Accounts extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get name => text()();
  TextColumn get type => textEnum<AccountType>()();
  TextColumn get industry => text().nullable()();
  TextColumn get level => textEnum<AccountLevel>().withDefault(const Constant(AccountLevel.normal))();
  TextColumn get source => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get creditCode => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get status => textEnum<AccountStatus>().withDefault(const Constant(AccountStatus.active))();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 联系人 ============
@DataClassName('ContactEntity')
class Contacts extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get name => text()();
  TextColumn get title => text().nullable()();
  TextColumn get department => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get wechat => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get isDecisionMaker => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 商机（含线索） ============
@DataClassName('OpportunityEntity')
class Opportunities extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get name => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get stage => textEnum<OpportunityStage>()();
  IntColumn get probability => integer().withDefault(const Constant(0))();
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get source => text().nullable()();
  TextColumn get leadContactName => text().nullable()();
  TextColumn get leadPhone => text().nullable()();
  TextColumn get leadEmail => text().nullable()();
  IntColumn get expectedCloseDate => integer().nullable()();
  IntColumn get actualCloseDate => integer().nullable()();
  TextColumn get lossReason => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 产品分类 ============
@DataClassName('CategoryEntity')
class Categories extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 产品 ============
@DataClassName('ProductEntity')
class Products extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get sku => text().unique().nullable()();
  TextColumn get type => textEnum<ProductType>().withDefault(const Constant(ProductType.product))();
  TextColumn get unit => text().nullable()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  RealColumn get cost => real().withDefault(const Constant(0.0))();
  IntColumn get warrantyMonths => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 报价单 ============
@DataClassName('QuoteEntity')
class Quotes extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get quoteNo => text().unique()();
  TextColumn get opportunityId => text().references(Opportunities, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get status => textEnum<QuoteStatus>().withDefault(const Constant(QuoteStatus.draft))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  IntColumn get validUntil => integer().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 报价明细 ============
@DataClassName('QuoteItemEntity')
class QuoteItems extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get quoteId => text().references(Quotes, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get productName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(1.0))();
  RealColumn get amount => real()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 合同 ============
@DataClassName('ContractEntity')
class Contracts extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get contractNo => text().unique()();
  TextColumn get name => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get opportunityId => text().nullable().references(Opportunities, #id)();
  TextColumn get quoteId => text().nullable().references(Quotes, #id)();
  TextColumn get status => textEnum<ContractStatus>().withDefault(const Constant(ContractStatus.draft))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get invoicedAmount => real().withDefault(const Constant(0.0))();
  IntColumn get signDate => integer().nullable()();
  IntColumn get startDate => integer().nullable()();
  IntColumn get endDate => integer().nullable()();
  IntColumn get warrantyEndDate => integer().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 合同明细 ============
@DataClassName('ContractItemEntity')
class ContractItems extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get contractId => text().references(Contracts, #id)();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get productName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real()();
  RealColumn get amount => real()();
  IntColumn get warrantyMonths => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 回款计划 ============
@DataClassName('PaymentPlanEntity')
class PaymentPlans extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get contractId => text().references(Contracts, #id)();
  TextColumn get planName => text()();
  RealColumn get planAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  IntColumn get planDate => integer()();
  TextColumn get status => textEnum<PaymentPlanStatus>().withDefault(const Constant(PaymentPlanStatus.pending))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 回款记录 ============
@DataClassName('PaymentEntity')
class Payments extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get contractId => text().references(Contracts, #id)();
  TextColumn get planId => text().nullable().references(PaymentPlans, #id)();
  RealColumn get amount => real()();
  IntColumn get paymentDate => integer()();
  TextColumn get method => textEnum<PaymentMethod>()();
  TextColumn get invoiceId => text().nullable();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 发票 ============
@DataClassName('InvoiceEntity')
class Invoices extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get contractId => text().references(Contracts, #id)();
  TextColumn get invoiceNo => text().nullable()();
  TextColumn get type => textEnum<InvoiceType>()();
  RealColumn get amount => real()();
  RealColumn get taxRate => real().withDefault(const Constant(0.13))();
  IntColumn get issueDate => integer().nullable()();
  TextColumn get status => textEnum<InvoiceStatus>().withDefault(const Constant(InvoiceStatus.pending))();
  TextColumn get receiverName => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 质保 ============
@DataClassName('WarrantyEntity')
class Warranties extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get contractId => text().references(Contracts, #id)();
  TextColumn get contractItemId => text().nullable()();
  TextColumn get productId => text().nullable().references(Products, #id)();
  TextColumn get serialNo => text().nullable()();
  IntColumn get startDate => integer()();
  IntColumn get endDate => integer()();
  TextColumn get status => textEnum<WarrantyStatus>().withDefault(const Constant(WarrantyStatus.active))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 售后工单 ============
@DataClassName('AfterSalesEntity')
class AfterSales extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get ticketNo => text().unique()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get contactId => text().nullable().references(Contacts, #id)();
  TextColumn get contractId => text().nullable().references(Contracts, #id)();
  TextColumn get warrantyId => text().nullable().references(Warranties, #id)();
  TextColumn get type => textEnum<AfterSalesType>()();
  TextColumn get priority => textEnum<Priority>().withDefault(const Constant(Priority.medium))();
  TextColumn get status => textEnum<AfterSalesStatus>().withDefault(const Constant(AfterSalesStatus.open))();
  TextColumn get subject => text()();
  TextColumn get description => text().nullable()();
  TextColumn get resolution => text().nullable()();
  IntColumn get resolvedAt => integer().nullable()();
  IntColumn get closedAt => integer().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 活动/跟进记录 ============
@DataClassName('ActivityEntity')
class Activities extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get type => textEnum<ActivityType>()();
  TextColumn get direction => textEnum<ActivityDirection>().nullable()();
  TextColumn get relatedType => text()();
  TextColumn get relatedId => text()();
  TextColumn get subject => text()();
  TextColumn get content => text().nullable()();
  TextColumn get status => textEnum<ActivityStatus>().withDefault(const Constant(ActivityStatus.completed))();
  IntColumn get scheduledAt => integer().nullable()();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 标签 ============
@DataClassName('TagEntity')
class Tags extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get name => text().unique()();
  TextColumn get color => text().withDefault(const Constant('#4CAF50'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 实体-标签关联 ============
@DataClassName('EntityTagEntity')
class EntityTags extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {entityType, entityId, tagId};
}

// ============ 附件 ============
@DataClassName('AttachmentEntity')
class Attachments extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get relatedType => text()();
  TextColumn get relatedId => text()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============ 提醒 ============
@DataClassName('ReminderEntity')
class Reminders extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get relatedType => text()();
  TextColumn get relatedId => text()();
  TextColumn get type => textEnum<ReminderType>()();
  TextColumn get title => text()();
  IntColumn get remindAt => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

## 八、实体统计

| 类别 | 实体 | 数量 |
|:---|:---|:---|
| 核心业务 | Account, Contact, Opportunity, Product, Category | 5 |
| 销售流程 | Quote, QuoteItem, Contract, ContractItem | 4 |
| 财务回款 | PaymentPlan, Payment, Invoice | 3 |
| 售后服务 | Warranty, AfterSales | 2 |
| 通用支撑 | Activity, Tag, EntityTag, Attachment, Reminder | 5 |
| **合计** | | **19 张表** |

---

## 九、与 Moodiary 项目整合要点

| 整合点 | 说明 |
|:---|:---|
| **语音输入** | Sherpa-ONNX + SenseVoice-Small 识别结果写入 Activity.content 或实体 note 字段 |
| **Block 协议** | 每条实体可关联 Block 容器，承载富文本、语音转写、AI 摘要 |
| **Rust 同步引擎** | 通过 `syncStatus` 字段标记同步状态，moodiary_rust FFI 层处理冲突合并 |
| **Drift 响应式** | 所有 DAO 返回 `Stream<List<T>>`，UI 层通过 Riverpod 自动刷新 |
| **附件沙盒** | 合同扫描件、发票照片存入 `getApplicationDocumentsDirectory()`，路径记录在 Attachment 表 |
| **本地通知** | Reminder 表驱动 `flutter_local_notifications`，实现回款/质保到期提醒 |

---

## 十、后续扩展方向（v2.0+）

| 方向 | 说明 |
|:---|:---|
| **数据看板** | 商机漏斗图、月度回款统计、售后工单分布、客户等级占比 |
| **AI 辅助** | 语音录入自动提取客户名/金额/需求，填充商机字段 |
| **导出** | 合同/报价单导出为 PDF（`pdf` 包） |
| **数据备份** | 整库导出为加密文件，支持 WebDAV/本地恢复 |
| **多设备同步** | 基于 CRDT 或自研 Rust 同步协议，实现手机↔电脑数据同步 |
| **日历视图** | Activity.scheduledAt + Reminder.remindAt 投射到日历组件 |

---

> **文档版本**：v1.0 | **最后更新**：2026-08-22 | **适用项目**：Moodiary CRM 模块