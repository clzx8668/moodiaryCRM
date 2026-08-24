
# CRM 双向无感关联设计指南

> **适用项目**：Moodiary CRM 模块（Flutter + Drift + Riverpod）
> **参照**：Twenty CRM / HubSpot / Salesforce Lightning
> **版本**：v1.0 · 2026-08-24
> **目标读者**：AI 代码生成引擎 / 开发者

---

## 一、问题定义

### 1.1 核心矛盾

CRM 中「公司（Account）」与「联系人（Contact）」是 1:N 关系。用户需要在两个方向上完成关联操作：

| 方向 | 用户意图 | 传统做法（差体验） | 目标做法（丝滑） |
|:---|:---|:---|:---|
| 公司 → 联系人 | "给这个公司加个联系人" | 跳转联系人新建页 → 保存 → 返回 | 在当前页搜索/新建，不离开 |
| 联系人 → 公司 | "这个联系人属于哪个公司" | 跳转公司选择页 → 选择 → 返回 | 在当前页搜索/新建，不离开 |

### 1.2 用户体验目标

> **用户不应感知到"关联"和"新建"是两个独立操作。它们应该是同一个交互流的两个分支。**

具体表现为：
- 用户在字段中输入关键词
- 下拉实时搜索已有实体
- 有匹配 → 点选即完成关联
- 无匹配 → 出现"+ 新建"选项 → 点击弹出极简表单 → 保存后自动回填
- **全程不离开当前页面，不超过 2 次点击**

---

## 二、Twenty CRM 案例分析

### 2.1 Twenty 的技术实现（源码分析）

Twenty 使用 React + Apollo GraphQL，其关联字段的核心组件是 `RelationPicker`：

```
twenty/packages/twenty-front/src/modules/object-record/relation-picker/
├── RelationPicker.tsx          // 主组件：搜索 + 选择 + 新建
├── RelationPickerSearchBar.tsx // 搜索输入（防抖 300ms）
├── RelationPickerResult.tsx    // 搜索结果列表
├── RelationPickerCreate.tsx    // 内联新建入口
└── RelationPickerEmpty.tsx     // 空状态提示
```

### 2.2 Twenty 的关键设计决策

| 决策 | 实现方式 | 为什么 |
|:---|:---|:---|
| **搜索是实时的** | 输入 ≥1 字符即触发搜索，300ms 防抖 | 减少等待感 |
| **新建是内联的** | 点击"+ 新建"后，原地展开极简表单或弹出 Modal | 不打断上下文 |
| **新建字段最少化** | 联系人新建只需 `name`；公司新建只需 `name` | 降低认知负担，其余字段后续补全 |
| **创建即关联** | 新建时自动注入 `accountId`（从公司侧）或回填 `contactId`（从联系人侧） | 原子操作，无需二次绑定 |
| **乐观更新** | 选择/创建后立即更新 UI，不等 GraphQL 响应 | 感知零延迟 |
| **防重复** | 新建时检查同名实体，提示"是否使用已有的？" | 避免脏数据 |
| **最近优先** | 搜索结果按 `updatedAt DESC` 排序 | 高频实体排前面 |
| **键盘导航** | ↑↓ 选择、Enter 确认、Esc 关闭 | 效率用户友好 |

### 2.3 Twenty 的数据流（GraphQL 层面）

```
[用户选择已有联系人]
  → Mutation: updateOneContact({ id, data: { accountId } })
  → Optimistic UI update
  → Server confirm

[用户内联新建联系人]
  → Mutation: createOneContact({ name, phone, accountId })
  → 返回新 contact.id
  → Optimistic UI update（将新联系人插入列表）
  → Server confirm
```

### 2.4 Twenty 的 UX 细节

1. **搜索框聚焦时**：显示最近关联的 5 条记录（无需输入）
2. **无结果时**：显示 `未找到 "xxx"，点击新建`
3. **新建表单**：仅 2-3 个字段，底部有"创建"和"取消"
4. **创建成功后**：Modal 关闭，Combobox 自动显示新创建的实体名称
5. **取消操作**：不产生任何数据变更，回到搜索状态

---

## 三、数据层设计

### 3.1 表结构要求

```dart
// ✅ 联系人的 accountId 必须可空（允许先创建后关联）
TextColumn get accountId => text().nullable().references(Accounts, #id)();

// ✅ 商机的 lead* 字段允许暂存未正式关联的信息
TextColumn get leadContactName => text().nullable()();
TextColumn get leadPhone => text().nullable()();
```

### 3.2 关联规则

| 规则 | 说明 |
|:---|:---|
| 一个联系人只能属于一个公司 | `accountId` 是单值外键 |
| 联系人可以没有公司 | `accountId` 为 NULL 表示独立联系人 |
| 修改公司 = 覆盖 | 选择新公司时直接覆盖旧值，无需先解绑 |
| 公司删除不级联删联系人 | 联系人变为"独立联系人"（accountId → NULL） |

---

## 四、核心组件设计：`EntityRelationField`

### 4.1 组件职责

这是实现双向无感关联的**唯一核心组件**，在以下位置复用：

| 使用场景 | 位置 | 关联方向 |
|:---|:---|:---|
| 公司详情页 → 联系人字段 | `AccountDetailPage` | Account → Contact |
| 联系人详情页 → 公司字段 | `ContactDetailPage` | Contact → Account |
| 商机详情页 → 客户字段 | `OpportunityDetailPage` | Opportunity → Account |
| 商机详情页 → 联系人字段 | `OpportunityDetailPage` | Opportunity → Contact |
| 合同详情页 → 客户字段 | `ContractDetailPage` | Contract → Account |

### 4.2 组件接口定义

```dart
/// 双向无感关联字段
/// 支持：搜索已有 + 选择关联 + 内联新建
class EntityRelationField<T> extends StatefulWidget {
  /// 字段标签（如"联系人""所属公司"）
  final String label;

  /// 当前已关联的实体（为 null 表示未关联）
  final T? currentValue;

  /// 搜索函数：输入关键词，返回匹配列表（限 20 条）
  final Future<List<T>> Function(String query) onSearch;

  /// 获取显示文本
  final String Function(T entity) displayText;

  /// 获取实体 ID
  final String Function(T entity) entityId;

  /// 选中已有实体时的回调（执行关联）
  final ValueChanged<T> onSelect;

  /// 清除关联时的回调
  final VoidCallback? onClear;

  /// 新建表单构建器（返回一个 Widget，通常是最简表单）
  /// [onDone] 新建完成后调用，传入新实体
  /// [onCancel] 取消新建
  final Widget Function({
    required ValueChanged<T> onDone,
    required VoidCallback onCancel,
  })? createFormBuilder;

  /// 是否允许新建（某些场景只允许选择）
  final bool allowCreate;

  /// 新建时预填的数据（如从公司侧新建联系人时预填 accountId）
  final Map<String, dynamic>? createDefaults;

  const EntityRelationField({
    super.key,
    required this.label,
    this.currentValue,
    required this.onSearch,
    required this.displayText,
    required this.entityId,
    required this.onSelect,
    this.onClear,
    this.createFormBuilder,
    this.allowCreate = true,
    this.createDefaults,
  });
}
```

### 4.3 组件内部状态机

```
┌─────────┐    点击/聚焦     ┌──────────┐    输入≥1字符    ┌──────────┐
│  IDLE   │──────────────▶│  SEARCH  │──────────────▶│ RESULTS  │
│(显示当前值│              │(显示搜索框) │              │(显示结果)  │
└─────────┘              └──────────┘              └────┬─────┘
     ▲                                                    │
     │         ┌──────────────────────────────────────────┤
     │         │                    │                     │
     │    选中已有实体         无匹配结果            点击"+ 新建"
     │         │                    │                     │
     │         ▼                    ▼                     ▼
     │    ┌─────────┐        ┌──────────┐         ┌──────────┐
     │    │ASSOCIATED│        │  EMPTY   │         │ CREATING │
     │    │(执行关联) │        │(提示新建) │         │(显示表单) │
     │    └────┬────┘        └──────────┘         └────┬─────┘
     │         │                                       │
     │         │ 关联完成                          创建完成
     │         │                                       │
     └─────────┴───────────────────────────────────────┘
```

### 4.4 完整实现代码

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EntityRelationField<T> extends ConsumerStatefulWidget {
  final String label;
  final T? currentValue;
  final Future<List<T>> Function(String query) onSearch;
  final String Function(T entity) displayText;
  final String Function(T entity) entityId;
  final ValueChanged<T> onSelect;
  final VoidCallback? onClear;
  final Widget Function({
    required ValueChanged<T> onDone,
    required VoidCallback onCancel,
  })? createFormBuilder;
  final bool allowCreate;

  const EntityRelationField({
    super.key,
    required this.label,
    this.currentValue,
    required this.onSearch,
    required this.displayText,
    required this.entityId,
    required this.onSelect,
    this.onClear,
    this.createFormBuilder,
    this.allowCreate = true,
  });

  @override
  ConsumerState<EntityRelationField<T>> createState() =>
      _EntityRelationFieldState<T>();
}

class _EntityRelationFieldState<T> extends ConsumerState<EntityRelationField<T>> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<T> _results = [];
  bool _isSearching = false;
  bool _isCreating = false;
  bool _showDropdown = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// 搜索（300ms 防抖）
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _showDropdown = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearching = true);
      final results = await widget.onSearch(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
          _showDropdown = true;
        });
      }
    });
  }

  /// 选中已有实体
  void _onSelectEntity(T entity) {
    widget.onSelect(entity);
    setState(() {
      _showDropdown = false;
      _controller.clear();
    });
    _focusNode.unfocus();
  }

  /// 开始新建
  void _startCreate() {
    setState(() {
      _isCreating = true;
      _showDropdown = false;
    });
  }

  /// 新建完成
  void _onCreated(T newEntity) {
    widget.onSelect(newEntity); // 新建后自动关联
    setState(() {
      _isCreating = false;
      _controller.clear();
    });
  }

  /// 取消新建
  void _cancelCreate() {
    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    // 新建模式：显示内联表单
    if (_isCreating && widget.createFormBuilder != null) {
      return widget.createFormBuilder!(
        onDone: _onCreated,
        onCancel: _cancelCreate,
      );
    }

    // 正常模式：显示字段 + 搜索下拉
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签 + 当前值
        _buildDisplayRow(),

        // 搜索输入框
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: '搜索${widget.label}...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: _onSearchChanged,
          onTap: () {
            if (_controller.text.isNotEmpty) {
              setState(() => _showDropdown = true);
            }
          },
        ),

        // 下拉结果
        if (_showDropdown) _buildDropdown(),
      ],
    );
  }

  /// 显示当前关联值
  Widget _buildDisplayRow() {
    if (widget.currentValue == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          widget.label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.displayText(widget.currentValue as T),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (widget.onClear != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: widget.onClear,
              tooltip: '清除关联',
            ),
        ],
      ),
    );
  }

  /// 下拉搜索结果
  Widget _buildDropdown() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 4),
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView(
          shrinkWrap: true,
          children: [
            // 搜索结果
            ..._results.map((entity) => ListTile(
              dense: true,
              title: Text(widget.displayText(entity)),
              onTap: () => _onSelectEntity(entity),
            )),

            // 无结果提示
            if (_results.isEmpty && _controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '未找到 "${_controller.text}"',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),

            // 新建选项
            if (widget.allowCreate && widget.createFormBuilder != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.add, size: 18),
                title: Text(
                  '新建${widget.label}${_controller.text.isNotEmpty ? ' "${_controller.text}"' : ''}',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
                onTap: _startCreate,
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## 五、四种场景的完整执行流程

### 场景 A：公司详情页 → 选择已有联系人

**触发位置**：`AccountDetailPage` → 联系人列表区域 → "+ 添加联系人"

**执行步骤**：

```
1. 用户点击"+ 添加联系人"
2. 页面内展开 EntityRelationField<ContactEntity>
3. 用户输入关键词（如"张"）
4. 300ms 后触发 DAO.search("张")
5. 下拉显示匹配结果（按 updatedAt DESC）
6. 用户点击"张三 - 13800138000"
7. 调用 DAO.updateContactAccount(contactId, accountId)
8. UI 刷新联系人列表，新联系人出现
9. EntityRelationField 收起
```

**DAO 调用**：

```dart
await contactDao.updateAccount(
  contactId: selectedContact.id,
  accountId: currentAccount.id,
);
```

### 场景 B：公司详情页 → 新建联系人

**触发位置**：同场景 A，但搜索无结果时

**执行步骤**：

```
1. 用户输入"王五"，无匹配结果
2. 下拉显示：未找到"王五" + [+ 新建联系人 "王五"]
3. 用户点击"+ 新建联系人"
4. 原地弹出 Modal（AlertDialog 或 BottomSheet）
5. Modal 内容：
   - 姓名（预填"王五"）← 来自搜索框输入
   - 手机号（空）
   - 职位（空，可选）
   - [创建] [取消]
6. 用户填写手机号，点击"创建"
7. 事务执行：
   INSERT INTO contacts (id, name, phone, account_id, created_at, updated_at)
   VALUES (:uuid, '王五', :phone, :currentAccountId, :now, :now)
8. Modal 关闭
9. EntityRelationField 自动显示"王五"为已选中
10. 联系人列表刷新，"王五"出现
```

**DAO 调用（事务）**：

```dart
await database.transaction(() async {
  final newContact = ContactEntity(
    id: const Uuid().v4(),
    name: name,           // "王五"
    phone: phone,
    accountId: currentAccount.id,  // ← 自动绑定当前公司
    createdAt: now,
    updatedAt: now,
  );
  await database.into(database.contacts).insert(newContact);
  return newContact;
});
```

### 场景 C：联系人详情页 → 选择已有公司

**触发位置**：`ContactDetailPage` → "所属公司"字段

**执行步骤**：

```
1. 用户点击"所属公司"字段
2. 展开 EntityRelationField<AccountEntity>
3. 用户输入关键词（如"科技"）
4. 下拉显示匹配的公司
5. 用户选择"星辰科技有限公司"
6. 调用 DAO.updateContactAccount(contactId, accountId: selectedAccountId)
7. UI 刷新，"所属公司"显示"星辰科技有限公司"
```

**DAO 调用**：

```dart
await contactDao.updateAccount(
  contactId: currentContact.id,
  accountId: selectedAccount.id,
);
```

### 场景 D：联系人详情页 → 新建公司

**触发位置**：同场景 C，但搜索无结果时

**执行步骤**：

```
1. 用户输入"新创达科技"，无匹配
2. 显示：未找到"新创达科技" + [+ 新建公司 "新创达科技"]
3. 用户点击"+ 新建公司"
4. 弹出 Modal：
   - 公司名称（预填"新创达科技"）
   - 公司类型（默认"企业"，可选：企业/个人/单位）
   - [创建] [取消]
5. 用户确认
6. 事务执行：
   a. INSERT INTO accounts (id, name, type, ...) VALUES (:uuid, '新创达科技', 'company', ...)
   b. UPDATE contacts SET account_id = :newAccountId WHERE id = :currentContactId
7. Modal 关闭
8. "所属公司"字段显示"新创达科技"
```

**DAO 调用（事务）**：

```dart
await database.transaction(() async {
  // Step 1: 创建公司
  final newAccount = AccountEntity(
    id: const Uuid().v4(),
    name: name,
    type: AccountType.company,
    createdAt: now,
    updatedAt: now,
  );
  await database.into(database.accounts).insert(newAccount);

  // Step 2: 更新联系人的 accountId
  await (database.update(database.contacts)
    ..where((c) => c.id.equals(currentContactId)))
    .write(ContactsCompanion(
      accountId: Value(newAccount.id),
      updatedAt: Value(now),
    ));

  return newAccount;
});
```

---

## 六、DAO 层完整实现

### 6.1 ContactDao

```dart
@UseDao(tables: [Contacts, Accounts])
class ContactDao extends DatabaseAccessor<AppDatabase> with _$ContactDaoMixin {
  ContactDao(AppDatabase db) : super(db);

  /// 模糊搜索联系人（姓名/手机/邮箱）
  /// 按 updatedAt 降序，最多返回 20 条
  Future<List<ContactEntity>> search(String query) {
    final q = '%${query.trim()}%';
    return (select(contacts)
      ..where((c) =>
          c.name.like(q) |
          c.phone.like(q) |
          c.email.like(q))
      ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])
      ..limit(20)
    ).get();
  }

  /// 获取某公司的所有联系人
  Stream<List<ContactEntity>> watchByAccount(String accountId) {
    return (select(contacts)
      ..where((c) => c.accountId.equals(accountId))
      ..orderBy([(c) => OrderingTerm.desc(c.isPrimary)])
    ).watch();
  }

  /// 快速创建联系人（最少字段）
  Future<ContactEntity> createQuick({
    required String name,
    String? phone,
    String? email,
    String? accountId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entity = ContactEntity(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      email: email,
      accountId: accountId,
      createdAt: now,
      updatedAt: now,
    );
    await into(contacts).insert(entity);
    return entity;
  }

  /// 更新联系人所属公司
  Future<void> updateAccount(String contactId, {required String? accountId}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (update(contacts)..where((c) => c.id.equals(contactId)))
        .write(ContactsCompanion(
      accountId: Value(accountId),
      updatedAt: Value(now),
    ));
  }

  /// 检查是否存在同名联系人（防重复）
  Future<ContactEntity?> findDuplicate(String name, {String? phone}) async {
    final query = select(contacts)
      ..where((c) => c.name.equals(name));
    if (phone != null && phone.isNotEmpty) {
      query.where((c) => c.phone.equals(phone));
    }
    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }
}
```

### 6.2 AccountDao

```dart
@UseDao(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(AppDatabase db) : super(db);

  /// 模糊搜索公司
  Future<List<AccountEntity>> search(String query) {
    final q = '%${query.trim()}%';
    return (select(accounts)
      ..where((a) => a.name.like(q))
      ..orderBy([(a) => OrderingTerm.desc(a.updatedAt)])
      ..limit(20)
    ).get();
  }

  /// 快速创建公司（最少字段）
  Future<AccountEntity> createQuick({
    required String name,
    AccountType type = AccountType.company,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entity = AccountEntity(
      id: const Uuid().v4(),
      name: name,
      type: type,
      createdAt: now,
      updatedAt: now,
    );
    await into(accounts).insert(entity);
    return entity;
  }

  /// 创建公司并绑定联系人（事务）
  Future<AccountEntity> createAndBindContact({
    required String accountName,
    AccountType type = AccountType.company,
    required String contactId,
  }) async {
    return transaction(() async {
      final newAccount = await createQuick(name: accountName, type: type);
      await contactDao.updateAccount(contactId, accountId: newAccount.id);
      return newAccount;
    });
  }
}
```

---

## 七、防重复检测逻辑

### 7.1 触发时机

在用户点击"创建"按钮时、实际执行 INSERT 之前。

### 7.2 检测规则

| 实体 | 检测条件 | 匹配逻辑 |
|:---|:---|:---|
| 联系人 | 姓名完全相同 | `name = :input` |
| 联系人 | 手机号完全相同 | `phone = :input` |
| 公司 | 名称完全相同 | `name = :input` |

### 7.3 UI 表现

```
检测到重复时：
  Modal 内容变为：
  ┌─────────────────────────────────┐
  │ ⚠️ 发现相似记录                   │
  │                                 │
  │ 已存在联系人"王五"(138****8000)   │
  │                                 │
  │ [使用已有记录]  [仍然新建]         │
  └─────────────────────────────────┘
```

### 7.4 代码实现

```dart
/// 在新建前检查重复
Future<ContactEntity?> _checkDuplicateBeforeCreate(
  String name,
  String? phone,
) async {
  final duplicate = await contactDao.findDuplicate(name, phone: phone);
  if (duplicate != null) {
    // 弹出确认对话框
    final useExisting = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现相似记录'),
        content: Text('已存在联系人"${duplicate.name}"(${duplicate.phone ?? "无手机号"})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('仍然新建'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('使用已有记录'),
          ),
        ],
      ),
    );
    if (useExisting == true) return duplicate;
  }
  return null; // 无重复，继续新建
}
```

---

## 八、Riverpod Provider 层

```dart
// providers/contact_providers.dart

/// 联系人搜索（用于 EntityRelationField.onSearch）
final contactSearchProvider = FutureProvider.autoDispose.family<List<ContactEntity>, String>(
  (ref, query) async {
    final dao = ref.watch(contactDaoProvider);
    return dao.search(query);
  },
);

/// 某公司的联系人列表（响应式）
final contactsByAccountProvider = StreamProvider.autoDispose.family<List<ContactEntity>, String>(
  (ref, accountId) {
    final dao = ref.watch(contactDaoProvider);
    return dao.watchByAccount(accountId);
  },
);

/// 联系人操作
final contactActionsProvider = Provider<ContactActions>((ref) {
  final dao = ref.watch(contactDaoProvider);
  return ContactActions(dao);
});

class ContactActions {
  final ContactDao _dao;
  ContactActions(this._dao);

  Future<ContactEntity> createAndBind({
    required String name,
    String? phone,
    required String accountId,
  }) async {
    // 1. 防重复检测
    final duplicate = await _dao.findDuplicate(name, phone: phone);
    if (duplicate != null) {
      throw DuplicateException(duplicate);
    }
    // 2. 创建并绑定
    return _dao.createQuick(
      name: name,
      phone: phone,
      accountId: accountId,
    );
  }

  Future<void> bindToAccount(String contactId, String accountId) {
    return _dao.updateAccount(contactId, accountId: accountId);
  }

  Future<void> unbind(String contactId) {
    return _dao.updateAccount(contactId, accountId: null);
  }
}
```

---

## 九、使用示例（完整页面集成）

### 9.1 公司详情页中嵌入联系人关联

```dart
class AccountDetailPage extends ConsumerWidget {
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsByAccountProvider(accountId));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ... 公司基本信息 ...

          const Divider(),
          const Text('联系人', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

          // 已有联系人列表
          contacts.when(
            data: (list) => Column(
              children: list.map((c) => _buildContactTile(context, ref, c)).toList(),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('加载失败: $e'),
          ),

          // 添加联系人（核心组件）
          const SizedBox(height: 12),
          EntityRelationField<ContactEntity>(
            label: '联系人',
            currentValue: null,
            onSearch: (query) => ref.read(contactDaoProvider).search(query),
            displayText: (c) => '${c.name}${c.phone != null ? ' · ${c.phone}' : ''}',
            entityId: (c) => c.id,
            onSelect: (contact) async {
              await ref.read(contactActionsProvider).bindToAccount(
                contact.id, accountId,
              );
            },
            createFormBuilder: ({required onDone, required onCancel}) {
              return _InlineContactCreateForm(
                accountId: accountId,
                onDone: onDone,
                onCancel: onCancel,
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### 9.2 联系人详情页中嵌入公司关联

```dart
class ContactDetailPage extends ConsumerWidget {
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(contactByIdProvider(contactId));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 所属公司字段（核心组件）
          EntityRelationField<AccountEntity>(
            label: '所属公司',
            currentValue: contact.value?.account,
            onSearch: (query) => ref.read(accountDaoProvider).search(query),
            displayText: (a) => a.name,
            entityId: (a) => a.id,
            onSelect: (account) async {
              await ref.read(contactActionsProvider).bindToAccount(
                contactId, account.id,
              );
            },
            onClear: () async {
              await ref.read(contactActionsProvider).unbind(contactId);
            },
            createFormBuilder: ({required onDone, required onCancel}) {
              return _InlineAccountCreateForm(
                contactId: contactId,
                onDone: onDone,
                onCancel: onCancel,
              );
            },
          ),

          // ... 联系人其他字段 ...
        ],
      ),
    );
  }
}
```

---

## 十、内联新建表单模板

### 10.1 联系人快速新建表单

```dart
class _InlineContactCreateForm extends ConsumerStatefulWidget {
  final String accountId;
  final ValueChanged<ContactEntity> onDone;
  final VoidCallback onCancel;

  const _InlineContactCreateForm({
    required this.accountId,
    required this.onDone,
    required this.onCancel,
  });

  @override
  ConsumerState<_InlineContactCreateForm> createState() => _InlineContactCreateFormState();
}

class _InlineContactCreateFormState extends ConsumerState<_InlineContactCreateForm> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);

    try {
      final actions = ref.read(contactActionsProvider);
      final newContact = await actions.createAndBind(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        accountId: widget.accountId,
      );
      widget.onDone(newContact);
    } on DuplicateException catch (e) {
      // 弹出重复提示
      final useExisting = await _showDuplicateDialog(e.existing);
      if (useExisting != null) {
        widget.onDone(useExisting);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快速新建联系人', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '姓名 *', isDense: true),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: '手机号', isDense: true),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '职位（选填）', isDense: true),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onCancel, child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### 10.2 公司快速新建表单

```dart
class _InlineAccountCreateForm extends ConsumerStatefulWidget {
  final String contactId;  // 新建后自动绑定到此联系人
  final ValueChanged<AccountEntity> onDone;
  final VoidCallback onCancel;

  const _InlineAccountCreateForm({
    required this.contactId,
    required this.onDone,
    required this.onCancel,
  });

  @override
  ConsumerState<_InlineAccountCreateForm> createState() => _InlineAccountCreateFormState();
}

class _InlineAccountCreateFormState extends ConsumerState<_InlineAccountCreateForm> {
  final _nameCtrl = TextEditingController();
  AccountType _type = AccountType.company;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);

    try {
      final accountDao = ref.read(accountDaoProvider);
      final newAccount = await accountDao.createAndBindContact(
        accountName: _nameCtrl.text.trim(),
        type: _type,
        contactId: widget.contactId,
      );
      widget.onDone(newAccount);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快速新建公司', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '公司名称 *', isDense: true),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AccountType>(
              value: _type,
              decoration: const InputDecoration(labelText: '类型', isDense: true),
              items: AccountType.values.map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.label),  // 企业/个人/单位
              )).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.onCancel, child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// AccountType 的中文标签扩展
extension AccountTypeLabel on AccountType {
  String get label => switch (this) {
    AccountType.company => '企业',
    AccountType.person => '个人',
    AccountType.org => '单位',
  };
}
```

---

## 十一、实施步骤（AI 执行清单）

### Phase 1：基础组件（优先级最高）

| 步骤 | 任务 | 产出文件 |
|:---|:---|:---|
| 1.1 | 创建 `EntityRelationField` 组件 | `lib/src/widgets/entity_relation_field.dart` |
| 1.2 | 实现 `ContactDao.search` + `createQuick` + `updateAccount` | `lib/src/db/dao/contact_dao.dart` |
| 1.3 | 实现 `AccountDao.search` + `createQuick` + `createAndBindContact` | `lib/src/db/dao/account_dao.dart` |
| 1.4 | 实现 `_InlineContactCreateForm` | `lib/src/widgets/inline_contact_form.dart` |
| 1.5 | 实现 `_InlineAccountCreateForm` | `lib/src/widgets/inline_account_form.dart` |
| 1.6 | 在 `AccountDetailPage` 集成联系人关联 | 修改 `account_detail_page.dart` |
| 1.7 | 在 `ContactDetailPage` 集成公司关联 | 修改 `contact_detail_page.dart` |

### Phase 2：体验优化

| 步骤 | 任务 | 说明 |
|:---|:---|:---|
| 2.1 | 添加防重复检测 | 新建前检查同名/同手机号 |
| 2.2 | 搜索结果排序优化 | 按 `updatedAt DESC`，最近使用的排前面 |
| 2.3 | 键盘导航支持 | ↑↓ 选择、Enter 确认、Esc 关闭 |
| 2.4 | 搜索框初始聚焦时显示最近 5 条 | 无需输入即可选择 |
| 2.5 | 加载骨架屏 | 搜索中显示 shimmer 效果 |

### Phase 3：扩展到其他实体

| 步骤 | 任务 | 说明 |
|:---|:---|:---|
| 3.1 | 商机页 → 关联客户 | 复用 `EntityRelationField<AccountEntity>` |
| 3.2 | 合同页 → 关联客户 | 同上 |
| 3.3 | 售后工单 → 关联合同 | 复用 `EntityRelationField<ContractEntity>` |
| 3.4 | 商机 `leadContactName` → 一键转正式联系人 | 特殊逻辑 |

---

## 十二、验收标准

| 编号 | 验收项 | 通过条件 |
|:---|:---|:---|
| AC-1 | 公司页添加已有联系人 | 搜索 → 选择 → 联系人出现在列表中，耗时 < 1秒 |
| AC-2 | 公司页新建联系人 | 搜索无结果 → 点新建 → 填姓名 → 创建 → 自动出现在列表，不离开页面 |
| AC-3 | 联系人页选择已有公司 | 搜索 → 选择 → 公司字段更新 |
| AC-4 | 联系人页新建公司 | 搜索无结果 → 点新建 → 填公司名 → 创建 → 自动关联 |
| AC-5 | 防重复 | 输入已存在的姓名 → 提示"发现相似记录" → 可选择使用已有 |
| AC-6 | 取消操作 | 点取消 → 无数据变更 → 回到搜索状态 |
| AC-7 | 清除关联 | 点 × → 联系人变为独立联系人（accountId = NULL） |
| AC-8 | 数据一致性 | 所有操作在事务内完成，中断不产生脏数据 |

---

## 十三、设计原则总结

| 原则 | 具体表现 |
|:---|:---|
| **不离开当前页** | 新建是 Modal/Inline，不是路由跳转 |
| **最少字段** | 新建只要求 1-2 个必填字段，其余后续补全 |
| **搜索即关联** | 选中即完成绑定，无需额外"保存关联"按钮 |
| **创建即关联** | 新建时自动注入外键，无需二次操作 |
| **预填上下文** | 从搜索框输入预填到新建表单的 name 字段 |
| **允许不完美** | accountId 可空、联系人可无公司，数据渐进补全 |
| **防重复但不阻断** | 提示重复但允许用户选择"仍然新建" |
| **事务原子性** | 创建+绑定在同一事务，要么全成功要么全回滚 |

---

> **文档版本**：v1.0 | **最后更新**：2026-08-24 | **状态**：待实施