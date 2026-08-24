# CRM 右侧栏记录详情页（仿 Twenty）开发设计指南

> 版本：v1.0 · 2026-08-24 · 分支：feat/local-crm-v1
> 依据：Twenty 本地源码实证（`E:\Dev\twenty\packages\twenty-front\src`）+ 用户需求 + 既有进度
> 状态：**设计评审稿，等待确认后开工**

## 一、目标

把 CRM 右侧栏从「单页详情 + 弹窗编辑」升级为 Twenty 式「记录详情页」：

1. 右侧栏/移动详情页内引入二级 Tab 导航：**主页、时间线、任务、更多（笔记、文件/附件等）**，新建、编辑、展示全部在这个详情结构内完成；
2. 主页内分区：标题行（记录名称，原位编辑）→ 主字段区块（主要字段原位编辑）→ 关联字段区块（区块标题 = 字段名，二级显示关联记录）；
3. 关联字段中的具体记录 → 点击直接打开对应的**新详情页**（复用同一结构），带入父页面关联上下文；父详情页退出为 ❌，子详情页为 ← 返回；嵌套先限制 3 层。

本阶段**不写功能代码**，先完成源码对照分析与开发计划确认。

## 二、Twenty 源码实证（本地源码）

以下均取自 `E:\Dev\twenty\packages\twenty-front\src`，与用户描述逐条对照。

### 2.1 记录页整体结构

| 文件 | 作用 |
| :-- | :-- |
| `pages/object-record/RecordShowPage.tsx` | 整页记录页：`PageHeader`（面包屑/关闭）+ `PageCardLayout` + `PageLayoutRecordPageRenderer` |
| `modules/object-record/record-show/components/RecordShowContainer.tsx` | 记录内容容器（整页与右抽屉**共用**）：加载数据 → `ShowPageContainer` → `ShowPageSubContainer` |
| `modules/command-menu/pages/record-page/components/CommandMenuRecordPage.tsx` | **右抽屉里的记录页**：`RecordShowContainer isInRightDrawer={true}`，右抽屉与整页复用同一套渲染 |
| `modules/ui/layout/show-page/components/ShowPageSubContainer.tsx` | 布局中枢：左列（桌面整页的 Summary+Fields）/ TabList / 当前 Tab 卡片渲染 / 右抽屉 Footer |

关键结论：**整页与右抽屉是同一个 `RecordShowContainer`，仅靠 `isInRightDrawer` 参数切换布局**。这正是我们要复用的"同一详情结构"模式。

### 2.2 Tab 是声明式、按对象可配的

`record-show/constants/BaseRecordLayout.ts` 定义基础 Tab：

| Tab | 标题 | 位置 | 桌面整页 | 右抽屉/移动 |
| :-- | :-- | :-- | :-- | :-- |
| fields | Fields | 100 | **隐藏**（左列显示） | 显示 |
| timeline | Timeline | 200 | 显示 | **与 fields 合并进 Home** |
| tasks | Tasks | 300 | 显示 | 显示 |
| notes | Notes | 400 | 显示 | 显示 |
| files | Files | 500 | 显示 | 显示 |

`record-show/hooks/useRecordShowContainerTabs.ts`：

- 每个 Tab 有 `position`（排序）、`Icon`、`cards`（卡片类型数组）、`hide`（条件集合：ifMobile / ifDesktop / ifInRightDrawer / ifFeaturesDisabled / ifRequiredObjectsInactive / ifRelationsMissing）；
- `BASE_RECORD_LAYOUT` 与对象级布局（Company/Person/Note/Task/Workflow…）浅合并，对象可增删改 Tab（如 Company 追加 Emails/Calendar，Note 追加 richText）；
- 右抽屉时把第 1、2 个 Tab 合并为一个 Home（cards 拼接 `[FieldCard, TimelineCard]`），其余 Tab 顺延；
- 只有 1 个可见 Tab 时不渲染 TabList。

`show-page/components/ShowPageSubContainer.tsx` 按当前 activeTab 的 `cards` 渲染对应卡片（`CardComponents` 注册表：FieldCard / TimelineCard / TaskCard / NoteCard / FileCard / EmailCard / CalendarCard…）。

**对我们的启示**：内层 Tab 应为**数据驱动配置**（对象类型 → Tab 列表 → 卡片），而不是硬编码 if-else；Tab 显隐条件按「桌面/移动/右抽屉/功能开关/关联缺失」声明。

### 2.3 标题行（SummaryCard）

`record-show/components/SummaryCard.tsx` + `ui/layout/show-page/components/ShowPageSummaryCard.tsx`：

- 头像（对象图标/首字母，联系人可点上传照片）+ 标题（`RecordTitleCell` = **label identifier 字段原位编辑**）+ 「Added <相对时间>」；
- 右抽屉/移动端为横向行（高 77px），桌面左列为纵向居中卡（高 127px）；
- 标题即主字段，编辑走与字段卡相同的 `FieldContext + RecordInlineCell`，失焦/回车提交。

### 2.4 主字段区块（FieldsCard）

`record-show/components/FieldsCard.tsx`：

- 取对象字段：排除 labelIdentifier、createdAt、deletedAt、不可用字段；
- **普通字段** → `PropertyBox` 内逐行 `RecordInlineCell`（标签 + 值，点击原位编辑，失焦保存）；
- **关系字段**分两类：笔记/待办的 targets 用内联 chips；其余关系字段 → 每个关系字段渲染一个**独立区块** `RecordDetailRelationSection`。

### 2.5 关联字段区块（RecordDetailRelationSection）

`record-show/record-detail-section/components/RecordDetailRelationSection.tsx`：

- 区块头：字段标题 + 右上「All (n)」链接（跳到按本记录过滤的索引页）+ 悬停显示 ⊕（to-many 新增）/ ✎（to-one 修改）按钮；
- 列表：最多显示 5 条，每条 = `RecordChip`（头像+名称）+ 悬停「⌄」展开 + 悬停「…」菜单（Detach / Delete）；
- 新增/修改：下拉 `SingleRecordPicker` / `MultipleRecordPicker`（搜索 + 底部「Create new」）；
- **点关联记录本身**：Twenty 当前版本是 `RecordDetailRelationRecordsList` 里 `onClick` → **就地展开**该记录的可编辑字段（chevron 展开 PropertyBox + RecordInlineCell），并支持删除/解除；点 chip 则跳整页。

### 2.6 新建关联并打开右抽屉（带父上下文）

`record-field/meta-types/input/hooks/useAddNewRecordAndOpenRightDrawer.ts`：

- 从父记录的关系区块点「Create new」：先生成新 id → `createOneRecord`（若 MANY_TO_ONE 直接把 `父Id` 写进新记录；若 ONE_TO_MANY 则 update 父记录的 `目标Id`）→ 把右抽屉 `viewableRecordId / viewableRecordNameSingular` 切到新记录 → `openRecordInCommandMenu` 打开；
- 即：**新建关联记录 = 先落库建好关联，再打开它的详情页继续编辑**，与父页面"无感关联"一致。

### 2.7 右抽屉导航

- 右抽屉是**单一内容槽**：`CommandMenuRecordPage` 读取 `viewableRecordId` 渲染对应记录，切换记录时**替换内容**，不是嵌套栈；
- 面包屑/关闭：整页有 `ObjectRecordShowPageBreadcrumb` + 关闭按钮；右抽屉有 Footer（ActionMenu + Open record）；
- 嵌套层级在 Twenty 中**不存在**——点关联记录要么就地展开编辑，要么跳整页。

## 三、用户需求 vs Twenty 实现对照

| # | 用户需求 | Twenty 实际 | 差异与决策 |
| :-- | :-- | :-- | :-- |
| 1 | 主页面 Tab（客户/联系人/机会/合同）不变 | 对象索引 Tab | 完全一致，不动 |
| 2 | 右侧栏引入二级 Tab：主页/时间线/任务/更多 | 右抽屉 Tab：Home(=Fields+Timeline)/Tasks/Notes/Files | **按用户需求分 4 个 Tab**（主页=Fields 单独、时间线单独、任务、更多=笔记+文件/附件合并）；保留 Twenty 的声明式 Tab 框架，后续可随时调整合并策略 |
| 3 | 标题行 = 记录名称，原位编辑 | SummaryCard 标题 = RecordTitleCell 原位编辑 | 一致，直接采用 |
| 4 | 主页内分区：主字段区块 + 关联字段区块 | FieldsCard = PropertyBox + 每个关系字段一个 RelationSection | 一致，直接采用 |
| 5 | 关联区块点具体记录 → 打开**新的右侧栏详情页**，带父上下文，嵌套 3 层 | 点记录 = 就地展开编辑 / 跳整页；无嵌套栈 | **本项目增强**：采用嵌套详情栈（现有 `_PanelFrame` 已是 Offstage 栈，天然支持）；父 ❌、子 ← |
| 6 | 详情页内新建/编辑同一套结构 | 新建 = 先落库建关联再打开右抽屉 | 一致；我们沿用 2.6 的"先建关联再进详情"链路 |
| 7 | 移动端用弹出详情页 | 移动端整页复用 ShowPage 结构 | 一致：同一详情组件，移动端全屏展示 |
| 8 | 少用弹窗、原位编辑、失焦保存 | RecordInlineCell 全字段原位编辑 | 一致，延续当前实现 |

## 四、落地设计（Flutter 侧）

### 4.1 详情页统一结构（ShowPage 结构）

```
CrmRecordDetailShell（新，替代当前侧栏/移动页各自拼装）
├─ 顶部栏：面包屑/层级指示 + 对象图标 + 操作（附件/删除/关闭或返回）
├─ Summary 标题行：头像/图标 + 名称（原位编辑）+ 创建时间
├─ 二级 TabList：主页 | 时间线 | 任务 | 更多
└─ 当前 Tab 内容卡片区
```

- 桌面：右侧栏承载（`CrmEntitySidePanel` 演进）；移动：整页（`CrmEntityDetailPage` 演进）；
- 两者共用 `CrmRecordDetailShell`，行为一致。

### 4.2 内层 Tab 配置（数据驱动）

新增 `CrmRecordDetailTabs` 配置模型（对应 Twenty `RecordLayout`）：

- 每个对象类型一份 Tab 配置：`id / title / icon / cards / hide`；
- `hide` 支持：`ifMobile / ifDesktop / ifInRightDrawer / 关联缺失 / 功能开关`；
- 默认配置：主页(FieldsCard)、时间线(TimelineCard)、任务(TaskCard)、更多(笔记+文件/附件)；
- 卡片按类型注册到 `CardComponents` 式映射表；
- 仅 1 个可见 Tab 时不渲染 TabList（沿用 Twenty 规则）。

### 4.3 主页内容布局

- **标题行**：`RecordTitleCell` 等价物——名称字段原位编辑，失焦保存并刷新；
- **主字段区块**：现有 `CrmEntityDetailView._buildFields()` 保留（原位编辑、无铅笔、失焦保存）；
- **关联字段区块**：每个关系字段一个区块，区块标题 = 字段中文名 + 计数；区块内为关联记录卡片列表（头像+名称+关键摘要），无记录时显示空态提示；
- 区块顺序、显隐按字段定义顺序（沿用列设置/字段顺序能力）。

### 4.4 关联区块交互

| 动作 | 行为 |
| :-- | :-- |
| 点已有关联记录 | 打开该对象的**子详情页**（新帧），带入父上下文（如 `from: 客户-XXX`） |
| 区块 ⊕ 新增 | 打开目标对象的**子详情页（新建态）**，父关联上下文预填（参照 2.6：先建记录并写父外键，再进详情继续编辑） |
| 区块 ✎ 修改(to-one) | 原位下拉选择已有/新建（沿用 `CrmRelationSearchField`） |
| 记录项「…」菜单 | 解除关联 / 删除（Twenty 对齐，保留确认） |

### 4.5 嵌套导航栈（3 层）

- 现有 `_PanelFrame`（`crm_object_table_tab.dart`）已是 Offstage 栈：`detail/columns/create` 三种帧。扩展为**同构 detail 栈**：每层都是 `CrmRecordDetailShell`；
- 帧增加：`isRoot` 标记 + 父上下文（`parentLabel`）+ 关联目标字段（用于新建预填）；
- 根详情页（从表格行进入）：❌ 关闭；子详情页：← 返回上一层；栈深上限 3，超出时子层级操作改为"就地展开编辑"（Twenty 默认交互）作为兜底；
- 返回后父页自动刷新关联区块（沿用 refreshTick 机制）。

### 4.6 移动端适配

- 移动端全屏详情页复用同一 Shell + 同一 Tab 配置；
- 关联下钻在移动端用 Navigator 推新页（同一 Shell），返回后刷新；
- 嵌套上限同样 3 层。

## 五、现有代码映射（复用点）

| 现状文件 | 在本设计中的角色 |
| :-- | :-- |
| `crm_entity_side_panel.dart` | 演进为 `CrmRecordDetailShell` 的桌面承载（header 改造：❌/← + 附件/删除） |
| `crm_entity_detail_view.dart` | 主体拆分为卡片：主字段卡（保留）+ 关联区块卡（抽取）+ 时间线卡/笔记/附件卡 |
| `crm_entity_detail_page.dart` | 移动端复用同一 Shell |
| `crm_object_table_tab.dart::_PanelFrame` | 扩展为嵌套 detail 栈（isRoot + 父上下文 + 上限 3） |
| `widgets/crm_relation_search_field.dart` | 关联字段原位选择/新建链路保留，接 4.4 |
| `crm_home_page.dart`（kCrmTabs） | 主页面 Tab 不动 |
| `docs/CRM数据结构规划指南.md`（L1–L6） | 关系字段/区块顺序的依据 |

## 六、任务分解（确认后执行）

### P0 详情结构 + 内层 Tab（1 迭代）

| ID | 任务 | 验收 |
| :-- | :-- | :-- |
| P0.1 | 新增 `CrmRecordDetailShell`：header（❌/← 按层级）+ Summary 标题行（原位编辑）+ 二级 TabList | 桌面右侧栏/移动整页均显示 主页/时间线/任务/更多 |
| P0.2 | Tab 配置模型 + 卡片注册表，接入现有主字段/时间线/笔记/附件区块 | 4 个 Tab 可切换，内容正确 |
| P0.3 | 主字段卡、关联区块卡抽取为独立卡片组件 | 主页布局 = 标题行 + 主字段 + 关联区块 |

### P1 关联下钻嵌套栈（1 迭代）

| ID | 任务 | 验收 |
| :-- | :-- | :-- |
| P1.1 | `_PanelFrame` 支持同构 detail 栈：isRoot + 父上下文 + 栈深 3 | 客户→联系人→机会 可逐层打开/返回 |
| P1.2 | 点关联记录打开子详情页，返回自动刷新父关联区块 | 返回后计数/列表即时更新 |
| P1.3 | 区块 ⊕ 新建：先建关联再进子详情（新建态）继续编辑 | 新建记录落库且父侧已关联 |
| P1.4 | 超 3 层兜底：就地展开编辑（Twenty 默认） | 第 4 层不再嵌套 |

### P2 细节打磨（1 迭代）

| ID | 任务 | 验收 |
| :-- | :-- | :-- |
| P2.1 | Tab 显隐按对象/终端/关联缺失配置（对齐 Twenty hide 条件） | 不同对象 Tab 集合正确 |
| P2.2 | 关系区块「…」菜单：解除/删除 + 确认 | 操作后即时刷新 |
| P2.3 | 移动端 Navigator 下钻 + 返回刷新 | 与桌面行为一致 |
| P2.4 | 全量回归 + analyze + 文档更新 | 单测全绿、0 error |

## 七、待确认点

1. 内层 Tab 采用**用户方案**（主页/时间线/任务/更多，时间线独立成 Tab），而非 Twenty 右抽屉的「Fields+Timeline 合并 Home」——确认？
2. 嵌套详情栈 3 层为**本项目增强**（Twenty 为就地展开/跳整页），确认按此实现？
3. 「更多」Tab 内笔记与文件/附件以**分区卡片**形式并列展示，确认？
4. 关联区块计数上限是否沿用 Twenty「列表显示 5 条 + All(n) 链接」（本项目中 All 链接 → 过滤后的表格页）？
