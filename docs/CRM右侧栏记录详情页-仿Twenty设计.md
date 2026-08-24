# CRM 记录详情页（仿 Twenty）开发设计指南

> 版本：v1.1 · 2026-08-24 · 分支：feat/local-crm-v1
> 依据：Twenty 本地源码实证（`E:\Dev\twenty\packages\twenty-front\src`）+ 用户需求
> 原则：**默认遵照 Twenty 的开发思路与成熟方案**；仅在「产品/导航结构差异」上提出适配与更优解（不考虑编程语言差异）。
> 状态：**评审稿 v2，等待确认后开工**

## 一、目标

把 CRM 详情从「单页详情 + 弹窗编辑」升级为 Twenty 式「记录详情页」，桌面右侧栏与移动整页复用同一结构：

1. 详情页顶部：标题行（记录名称，原位编辑）+ 二级 Tab 导航；
2. 内容按 Tab 渲染：字段卡、时间线、任务、笔记、文件/附件；
3. 字段卡 = 主字段区块（全部原位编辑）+ 每个关系字段一个关联区块（标题=字段名 + 记录列表）；
4. 关联记录：chevron 就地展开编辑（Twenty 默认）；chip 打开该记录的完整详情（适配返回）；
5. 新建关联：先建记录并写入父外键 → 打开子详情页继续编辑（Twenty `useAddNewRecordAndOpenRightDrawer` 链路）。

本阶段**不写功能代码**，先完成对照与决策确认。

## 二、Twenty 源码实证（本地源码）

以下均取自 `E:\Dev\twenty\packages\twenty-front\src`。

### 2.1 记录页整体结构

| 文件 | 作用 |
| :-- | :-- |
| `pages/object-record/RecordShowPage.tsx` | 桌面整页：`PageHeader` + `PageCardLayout` + 记录渲染 |
| `modules/object-record/record-show/components/RecordShowContainer.tsx` | 记录内容容器，**整页与右抽屉共用**，仅 `isInRightDrawer` 切换布局 |
| `modules/command-menu/pages/record-page/components/CommandMenuRecordPage.tsx` | 右抽屉记录页：`RecordShowContainer isInRightDrawer={true}` |
| `modules/ui/layout/show-page/components/ShowPageSubContainer.tsx` | 布局中枢：左列(桌面整页 Summary+Fields) / TabList / 当前 Tab 卡片 / 右抽屉 Footer |

### 2.2 Tab 是声明式、按对象可配的

`record-show/constants/BaseRecordLayout.ts` 定义基础 Tab：

| Tab | 标题 | 位置 | 桌面整页 | 右抽屉 | 移动整页 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| fields | Fields | 100 | **隐藏**（左列显示） | 显示 | 显示 |
| timeline | Timeline | 200 | 显示 | **与 fields 合并进 Home** | 显示 |
| tasks | Tasks | 300 | 显示 | 显示 | 显示 |
| notes | Notes | 400 | 显示 | 显示 | 显示 |
| files | Files | 500 | 显示 | 显示 | 显示 |

`record-show/hooks/useRecordShowContainerTabs.ts`：

- 每个 Tab：`position`（排序）、`Icon`、`cards`（卡片数组）、`hide`（条件：ifMobile / ifDesktop / ifInRightDrawer / ifFeaturesDisabled / ifRequiredObjectsInactive / ifRelationsMissing）；
- `BASE_RECORD_LAYOUT` 与对象级布局浅合并（Company 追加 Emails/Calendar，Note/Task 追加 richText，Workflow 替换 cards 等）；
- **右抽屉**把第 1、2 个 Tab（fields+timeline）合并为 Home，cards 拼接 `[FieldCard, TimelineCard]`；**移动端整页不合并**（5 个 Tab）；
- 仅 1 个可见 Tab 时不渲染 TabList；
- 当前 activeTab 的 `cards` 经 `CardComponents` 注册表渲染（FieldCard / TimelineCard / TaskCard / NoteCard / FileCard / EmailCard / CalendarCard…）。

### 2.3 标题行（SummaryCard）

`record-show/components/SummaryCard.tsx` + `ui/layout/show-page/components/ShowPageSummaryCard.tsx`：

- 头像/对象图标 + 标题（`RecordTitleCell` = label identifier 字段原位编辑）+ 「Added <相对时间>」；
- 右抽屉/移动端为横向行（高 77px），桌面左列为纵向居中卡（高 127px）；
- 编辑走与字段卡相同的 `FieldContext + RecordInlineCell`，失焦/回车提交。

### 2.4 主字段区块（FieldsCard）

`record-show/components/FieldsCard.tsx`：

- 取对象字段，排除 labelIdentifier、createdAt、deletedAt、不可用字段；
- 普通字段 → `PropertyBox` 逐行 `RecordInlineCell`（标签+值，点击原位编辑，失焦保存）；
- 关系字段分两类：笔记/待办 targets 用内联 chips；其余 → **每个关系字段一个独立区块** `RecordDetailRelationSection`（FieldCard 底部按字段顺序排列）。

### 2.5 关联字段区块（RecordDetailRelationSection）

`record-show/record-detail-section/components/RecordDetailRelationSection.tsx` + `RecordDetailRelationRecordsList/Item.tsx`：

- 区块头：字段标题 + 右上「All (n)」链接（跳到按本记录过滤的索引页）+ 悬停 ⊕（to-many 新增）/ ✎（to-one 修改）；
- 列表最多 5 条，每条 = `RecordChip`（头像+名称）+ 悬停「⌄」+ 悬停「…」（Detach / Delete）；
- **⌄ 点击 = 就地展开**该关联记录的**全部可编辑字段**（`RecordInlineCell` 逐个渲染），可直接改、失焦保存——不导航、不丢父上下文；
- 新增/修改用下拉 `SingleRecordPicker` / `MultipleRecordPicker`（搜索 + 底部 Create new）；
- 点 chip 本体 → 打开该记录的完整详情（整页路由）。

### 2.6 新建关联并打开详情（带父上下文）

`record-field/meta-types/input/hooks/useAddNewRecordAndOpenRightDrawer.ts`：

- 点「Create new」：生成新 id → `createOneRecord`（MANY_TO_ONE 直接写 `父Id`；ONE_TO_MANY update 父记录的 `目标Id`）→ 右抽屉切换到新记录详情继续编辑；
- 即：**新建关联记录 = 先落库建好关联，再打开它的详情页继续编辑**。

### 2.7 右抽屉导航

- 右抽屉是单一内容槽（`viewableRecordId`），切换记录即替换内容，**无嵌套栈**；
- 桌面整页有面包屑 + 关闭按钮；右抽屉 Footer = ActionMenu + Open record（跳到整页）；
- Twenty 的"深度编辑"靠：就地展开（快改）+ 整页路由（完整详情）。

## 三、默认 Twenty 的落地映射（核心决策表）

| # | 决策点 | Twenty 做法 | 本项目落地 | 说明 |
| :-- | :-- | :-- | :-- | :-- |
| D1 | 桌面右侧栏内层 Tab | Home(Fields+Timeline)/Tasks/Notes/Files | **采纳** | 合并由配置开关 `mergeIntoHome` 控制，若日后要独立时间线，一行配置切换 |
| D2 | 移动整页 Tab | Summary + Fields/Timeline/Tasks/Notes/Files（不合并） | **采纳** | 与 Twenty 一致，移动端不合并 |
| D3 | 标题行 | SummaryCard：头像 + 名称原位编辑 + Added 时间 | **采纳** | 失焦保存 |
| D4 | 主页字段 | FieldsCard：PropertyBox 逐行原位编辑 | **采纳** | 主字段区块（现有 `_buildFields` 演进） |
| D5 | 关联区块 | 每个关系字段一个区块：标题+计数+列表+⊕/✎ 下拉 | **采纳** | 区块标题=字段中文名 |
| D6 | 关联记录快速编辑 | **chevron 就地展开全部字段**（不导航） | **采纳为主路径** | 快改不丢上下文；比弹窗/跳转更贴近 Twenty |
| D7 | 关联记录完整详情 | 点 chip → 整页路由 | **适配**：打开「子详情页」（复用同一 Shell + ← 返回） | 本项目无 Twenty 式整页路由/面包屑，右抽屉内容替换后无法返回，故子详情页+返回是必要适配（导航结构差异，非语言差异） |
| D8 | 嵌套深度 | 无嵌套（就地展开 / 整页） | **默认 1 层**子详情；`maxDepth` 可配 3（原需求备选） | 建议默认浅导航，更贴近 Twenty 哲学；架构已支持任意深度，随时可调 |
| D9 | 新建关联去向 | Create New → 建记录写父外键 → 打开详情继续编辑 | **采纳** | 子详情页（新建态）继续编辑，保存返回父页刷新 |
| D10 | 「All (n)」链接 | 跳到按本记录过滤的索引页 | **采纳** | 关抽屉 → 主 Tab 切换到目标对象 + 应用过滤 |
| D11 | 桌面整页记录视图 | Open record → 整页（左列 Summary+Fields + 右侧 Tab） | **P2 可选项** | 建议做：完全对齐 Twenty 双模式；若不做则保留"子详情页"为主入口 |

## 四、落地设计（Flutter 侧）

### 4.1 详情页统一结构（ShowPage 结构）

```
CrmRecordDetailShell（新）
├─ 顶部栏：层级指示（根 ❌ / 子 ←）+ 对象图标 + 操作（附件/删除/Open record）
├─ Summary 标题行：头像/图标 + 名称（原位编辑）+ 创建时间
├─ 二级 TabList（配置驱动）
└─ 当前 Tab 卡片区（CardComponents 注册表渲染）
```

- 桌面：右侧栏承载（`CrmEntitySidePanel` 演进）；移动：整页（`CrmEntityDetailPage` 演进）；两者共用 Shell。

### 4.2 Tab 配置（数据驱动，对齐 Twenty RecordLayout）

新增 `CrmRecordDetailTabs` 配置模型：

- 每对象一份：`id / title / icon / cards / hide / mergeIntoHome`；
- `hide` 条件：`ifMobile / ifDesktop / ifInRightDrawer / 关联缺失 / 功能开关`；
- 基础配置 = fields/timeline/tasks/notes/files；对象级覆盖（如客户追加 emails/calendar 暂不启用，保留扩展点）；
- 右抽屉：`mergeIntoHome=true` → Home(FieldCard+TimelineCard) + Tasks/Notes/Files；
- 移动整页：不合并，5 Tab；
- 仅 1 个可见 Tab 时不渲染 TabList。

### 4.3 Summary 标题行

- 头像（对象图标/首字母）+ 名称（label identifier 字段，原位编辑，失焦保存）+ Added 时间；
- 桌面右抽屉横向行（77px 等价）；移动端同构。

### 4.4 FieldsCard（主页内容）

- 主字段区块：PropertyBox 逐行原位编辑（沿用 `_buildFields`，无铅笔、失焦保存）；
- 每个关系字段一个 `RecordDetailRelationSection` 区块：标题=字段中文名 + 计数 + 记录列表 + ⊕/✎；
- 区块顺序按字段定义顺序（沿用列设置/字段顺序能力）。

### 4.5 关联区块交互

| 元素 | 行为 |
| :-- | :-- |
| ⌄ chevron | **就地展开**该关联记录全部字段（原位编辑、失焦保存）——主路径 |
| chip（名称/头像） | 打开该记录的**子详情页**（同 Shell + ← 返回 + 父上下文） |
| ⊕（to-many）/ ✎（to-one） | 下拉搜索选择已有 / Create new（沿用 `CrmRelationSearchField`） |
| Create new | 先建记录+写父外键 → 打开子详情页（新建态）继续编辑 → 返回父页刷新 |
| … 菜单 | Detach（解除）/ Delete（删除+确认） |
| All (n) | 关抽屉 → 主 Tab 切换目标对象 + 过滤当前记录 |

### 4.6 子详情页与导航

- 详情栈复用 `_PanelFrame`（Offstage）：每层都是 `CrmRecordDetailShell`；
- 帧属性：`isRoot`（根 ❌ 关闭；子 ← 返回）+ `parentLabel`（父上下文提示）+ 新建预填字段；
- 默认 `maxDepth=1`（子详情页内不再下钻，继续点关联 → 就地展开）；可配置 `maxDepth=3` 测试（原需求）；
- 超出 maxDepth：一律回落「就地展开编辑」；
- 返回后父页自动刷新关联区块（沿用 refreshTick）。

### 4.7 移动端

- 复用同一 Shell + 同一 Tab 配置（不合并 = 5 Tab）；
- 子详情页用 Navigator 推新页（同 Shell），返回刷新；
- 与桌面行为一致（maxDepth 同配置）。

### 4.8 桌面整页记录视图（P2 可选项）

- 右抽屉 Footer「Open record」→ Navigator 推整页记录视图（宽屏两栏：左列 Summary+Fields 348px + 右侧 Tab Timeline/Tasks/Notes/Files）——完全对齐 Twenty 桌面整页；
- 不启用时，子详情页即完整详情入口。

## 五、现有代码映射（复用点）

| 现状文件 | 在本设计中的角色 |
| :-- | :-- |
| `crm_entity_side_panel.dart` | 演进为 `CrmRecordDetailShell` 桌面承载（header ❌/← + 附件/删除 + Open record） |
| `crm_entity_detail_view.dart` | 拆分为卡片：主字段卡（保留）+ 关联区块卡（抽取）+ 时间线卡/笔记/附件卡 |
| `crm_entity_detail_page.dart` | 移动端复用同一 Shell |
| `crm_object_table_tab.dart::_PanelFrame` | 扩展为 detail 栈（isRoot + parentLabel + maxDepth） |
| `widgets/crm_relation_search_field.dart` | 关联选择/新建链路保留（对接 ⊕/✎/Create new） |
| `crm_home_page.dart`（kCrmTabs） | 主页面 Tab 不动；All(n) 跳转目标 |
| `docs/CRM数据结构规划指南.md`（L1–L6） | 关系字段/区块顺序依据 |

## 六、任务分解（确认后执行）

### P0 详情结构 + Tab 配置（1 迭代）

| ID | 任务 | 验收 |
| :-- | :-- | :-- |
| P0.1 | 新增 `CrmRecordDetailShell`：header（❌/←）+ Summary 标题行（原位编辑）+ 二级 TabList | 桌面右抽屉/移动整页均可用 |
| P0.2 | `CrmRecordDetailTabs` 配置模型 + CardComponents 注册表，接入主字段/时间线/笔记/附件 | 右抽屉 Home 合并生效；移动端 5 Tab |
| P0.3 | FieldsCard 抽取：主字段区块 + 关联区块（标题/计数/列表/⊕/✎） | 主页布局 = 标题行 + 主字段 + 关联区块 |

### P1 关联交互（1 迭代）

| ID | 任务 | 验收 |
| :-- | :-- | :-- |
| P1.1 | chevron 就地展开关联记录全部字段（原位编辑/失焦保存） | 不导航即可编辑关联记录 |
| P1.2 | chip 打开子详情页（同 Shell + ← 返回 + 父上下文），maxDepth 配置生效 | 返回后父关联区块即时刷新 |
| P1.3 | Create new 链路：先建记录+写父外键 → 子详情页（新建态）→ 保存返回刷新 | 新建落库且父侧已关联 |
| P1.4 | … 菜单 Detach/Delete + All(n) 过滤跳转 | 操作即时刷新 |

### P2 打磨与可选（1 迭代）

| ID | 任务 | 验收 |
| :-- | :-- | :-- |
| P2.1 | 移动端 Navigator 下钻 + 返回刷新 | 与桌面一致 |
| P2.2 | Tab 显隐按对象/终端/关联缺失配置 | 不同对象 Tab 集合正确 |
| P2.3 | （可选）桌面整页记录视图 Open record（两栏布局） | 对齐 Twenty 桌面整页 |
| P2.4 | 全量回归 + analyze + 文档更新 | 单测全绿、0 error |

## 七、待确认点

1. **D1/D2**：右抽屉采纳 Twenty 的四 Tab（Home 合并 Fields+Timeline）、移动端五 Tab——接受？（合并是可配置开关，随时可拆）
2. **D6/D7**：关联记录以「chevron 就地展开」为主路径、「点名称打开子详情页（← 返回）」为完整详情入口——接受？
3. **D8**：嵌套深度默认 1 层（Twenty 浅导航），`maxDepth=3` 作为可配置选项留给你测试——接受，还是直接默认 3 层？
4. **D9**：新建关联 → 子详情页（新建态）继续编辑，返回父页刷新——接受？
5. **D11**：桌面整页记录视图（Open record，两栏布局）列入 P2——做还是不做？
