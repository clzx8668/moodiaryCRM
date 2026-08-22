import 'package:drift/drift.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';
import 'package:moodiary/persistence/app_database.dart';
import 'package:moodiary/persistence/isar.dart';
import 'package:uuid/uuid.dart';

/// 本地优先 CRM 仓储层（唯一读写入口）。
///
/// - 基础对象（公司/联系人/机会/合同）走强类型表，保证关联查询与性能；
/// - 自定义对象（回款/发票等）走「对象定义 + 通用记录 JSON 宽表」，
///   与 Twenty metadata 思路一致但无运行时建表成本；
/// - 实体 ↔ 日记/待办关联（跟进/认领/时间线）走 CrmEntityLinks。
class CrmLocalRepository {
  final AppDatabase db;

  CrmLocalRepository([AppDatabase? db]) : db = db ?? IsarUtil.database;

  static const List<String> baseObjectTypes = [
    'company',
    'person',
    'opportunity',
    'contract',
  ];

  // ==================== 公司 ====================

  Future<List<LocalCompany>> listCompanies({String? keyword}) async {
    final query = db.select(db.crmCompanies)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      query.where(
        (t) =>
            t.name.contains(keyword.trim()) |
            t.domainName.contains(keyword.trim()),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_companyFromRow).toList();
  }

  Future<LocalCompany?> getCompany(String id) async {
    final row = await (db.select(db.crmCompanies)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _companyFromRow(row);
  }

  Future<LocalCompany> createCompany(LocalCompany company) async {
    final now = DateTime.now();
    final entity = company..id = company.id.isEmpty ? const Uuid().v7() : company.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmCompanies).insert(_companyCompanion(entity));
    return entity;
  }

  Future<LocalCompany> updateCompany(LocalCompany company) async {
    company.updatedAt = DateTime.now();
    await (db.update(db.crmCompanies)..where((t) => t.id.equals(company.id)))
        .write(_companyCompanion(company));
    return company;
  }

  Future<void> deleteCompany(String id) async {
    await (db.update(db.crmCompanies)..where((t) => t.id.equals(id))).write(
      CrmCompaniesCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countCompanies() async =>
      (await listCompanies()).length;

  // ==================== 联系人 ====================

  Future<List<LocalPerson>> listPeople({String? keyword}) async {
    final query = db.select(db.crmPeople)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      final k = keyword.trim();
      query.where(
        (t) =>
            t.firstName.contains(k) |
            t.lastName.contains(k) |
            t.jobTitle.contains(k) |
            t.city.contains(k),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_personFromRow).toList();
  }

  Future<List<LocalPerson>> peopleOfCompany(String companyId) async {
    final rows = await (db.select(db.crmPeople)
          ..where(
            (t) => t.companyId.equals(companyId) & t.deleted.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_personFromRow).toList();
  }

  Future<LocalPerson?> getPerson(String id) async {
    final row = await (db.select(db.crmPeople)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _personFromRow(row);
  }

  Future<LocalPerson> createPerson(LocalPerson person) async {
    final now = DateTime.now();
    final entity = person..id = person.id.isEmpty ? const Uuid().v7() : person.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmPeople).insert(_personCompanion(entity));
    return entity;
  }

  Future<LocalPerson> updatePerson(LocalPerson person) async {
    person.updatedAt = DateTime.now();
    await (db.update(db.crmPeople)..where((t) => t.id.equals(person.id)))
        .write(_personCompanion(person));
    return person;
  }

  Future<void> deletePerson(String id) async {
    await (db.update(db.crmPeople)..where((t) => t.id.equals(id))).write(
      CrmPeopleCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countPeople() async => (await listPeople()).length;

  // ==================== 机会/线索 ====================

  Future<List<LocalOpportunity>> listOpportunities({String? keyword}) async {
    final query = db.select(db.crmOpportunities)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      query.where(
        (t) =>
            t.name.contains(keyword.trim()) |
            t.stage.contains(keyword.trim()),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_opportunityFromRow).toList();
  }

  Future<LocalOpportunity?> getOpportunity(String id) async {
    final row = await (db.select(db.crmOpportunities)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _opportunityFromRow(row);
  }

  Future<LocalOpportunity> createOpportunity(LocalOpportunity opp) async {
    final now = DateTime.now();
    final entity = opp..id = opp.id.isEmpty ? const Uuid().v7() : opp.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmOpportunities).insert(_opportunityCompanion(entity));
    return entity;
  }

  Future<LocalOpportunity> updateOpportunity(LocalOpportunity opp) async {
    opp.updatedAt = DateTime.now();
    await (db.update(db.crmOpportunities)
          ..where((t) => t.id.equals(opp.id)))
        .write(_opportunityCompanion(opp));
    return opp;
  }

  Future<void> deleteOpportunity(String id) async {
    await (db.update(db.crmOpportunities)..where((t) => t.id.equals(id))).write(
      CrmOpportunitiesCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countOpportunities() async =>
      (await listOpportunities()).length;

  // ==================== 合同 ====================

  Future<List<LocalContract>> listContracts({String? keyword}) async {
    final query = db.select(db.crmContracts)
      ..where((t) => t.deleted.equals(false));
    if (keyword != null && keyword.trim().isNotEmpty) {
      query.where(
        (t) =>
            t.name.contains(keyword.trim()) |
            t.status.contains(keyword.trim()),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_contractFromRow).toList();
  }

  Future<LocalContract?> getContract(String id) async {
    final row = await (db.select(db.crmContracts)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _contractFromRow(row);
  }

  Future<LocalContract> createContract(LocalContract contract) async {
    final now = DateTime.now();
    final entity = contract
      ..id = contract.id.isEmpty ? const Uuid().v7() : contract.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmContracts).insert(_contractCompanion(entity));
    return entity;
  }

  Future<LocalContract> updateContract(LocalContract contract) async {
    contract.updatedAt = DateTime.now();
    await (db.update(db.crmContracts)
          ..where((t) => t.id.equals(contract.id)))
        .write(_contractCompanion(contract));
    return contract;
  }

  Future<void> deleteContract(String id) async {
    await (db.update(db.crmContracts)..where((t) => t.id.equals(id))).write(
      CrmContractsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countContracts() async => (await listContracts()).length;

  // ==================== 自定义对象 ====================

  Future<List<LocalCustomObject>> listCustomObjects() async {
    final rows = await db.select(db.crmObjectDefs).get();
    return rows.map(_objectDefFromRow).toList();
  }

  Future<LocalCustomObject?> getCustomObject(String id) async {
    final row = await (db.select(db.crmObjectDefs)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _objectDefFromRow(row);
  }

  Future<LocalCustomObject> createCustomObject(LocalCustomObject def) async {
    final now = DateTime.now();
    final entity = def..id = def.id.isEmpty ? const Uuid().v7() : def.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmObjectDefs).insert(_objectDefCompanion(entity));
    return entity;
  }

  Future<LocalCustomObject> updateCustomObject(LocalCustomObject def) async {
    def.updatedAt = DateTime.now();
    await (db.update(db.crmObjectDefs)..where((t) => t.id.equals(def.id)))
        .write(_objectDefCompanion(def));
    return def;
  }

  Future<void> deleteCustomObject(String id) async {
    await db.transaction(() async {
      await (db.delete(db.crmCustomRecords)
            ..where((t) => t.objectId.equals(id)))
          .go();
      await (db.delete(db.crmObjectDefs)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<List<LocalCustomRecord>> listCustomRecords(
    String objectId, {
    String? keyword,
  }) async {
    final query = db.select(db.crmCustomRecords)
      ..where(
        (t) => t.objectId.equals(objectId) & t.deleted.equals(false),
      );
    if (keyword != null && keyword.trim().isNotEmpty) {
      query.where((t) => t.label.contains(keyword.trim()));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_customRecordFromRow).toList();
  }

  Future<LocalCustomRecord?> getCustomRecord(String id) async {
    final row = await (db.select(db.crmCustomRecords)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _customRecordFromRow(row);
  }

  Future<LocalCustomRecord> createCustomRecord(LocalCustomRecord record) async {
    final now = DateTime.now();
    final entity = record
      ..id = record.id.isEmpty ? const Uuid().v7() : record.id;
    entity.createdAt = now;
    entity.updatedAt = now;
    await db.into(db.crmCustomRecords).insert(_customRecordCompanion(entity));
    return entity;
  }

  Future<LocalCustomRecord> updateCustomRecord(LocalCustomRecord record) async {
    record.updatedAt = DateTime.now();
    await (db.update(db.crmCustomRecords)
          ..where((t) => t.id.equals(record.id)))
        .write(_customRecordCompanion(record));
    return record;
  }

  Future<void> deleteCustomRecord(String id) async {
    await (db.update(db.crmCustomRecords)..where((t) => t.id.equals(id))).write(
      CrmCustomRecordsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countCustomRecords(String objectId) async =>
      (await listCustomRecords(objectId)).length;

  // ==================== 实体 ↔ 内容关联 ====================

  Future<LocalEntityLink> linkEntity({
    required String entityType,
    required String entityId,
    required String localType,
    required String localId,
    String relation = 'followup',
  }) async {
    final link = LocalEntityLink(
      id: const Uuid().v7(),
      entityType: entityType,
      entityId: entityId,
      localType: localType,
      localId: localId,
      relation: relation,
    );
    await db.into(db.crmEntityLinks).insert(
      CrmEntityLinksCompanion.insert(
        id: link.id,
        entityType: link.entityType,
        entityId: link.entityId,
        localType: link.localType,
        localId: link.localId,
        relation: Value(link.relation),
        createdAt: link.createdAt,
      ),
    );
    return link;
  }

  Future<void> unlinkEntity({
    required String entityType,
    required String entityId,
    required String localType,
    required String localId,
    String? relation,
  }) async {
    final query = db.delete(db.crmEntityLinks)
      ..where(
        (t) =>
            t.entityType.equals(entityType) &
            t.entityId.equals(entityId) &
            t.localType.equals(localType) &
            t.localId.equals(localId),
      );
    if (relation != null) {
      query.where((t) => t.relation.equals(relation));
    }
    await query.go();
  }

  Future<List<LocalEntityLink>> linksForEntity(
    String entityType,
    String entityId,
  ) async {
    final rows = await (db.select(db.crmEntityLinks)
          ..where(
            (t) => t.entityType.equals(entityType) & t.entityId.equals(entityId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_linkFromRow).toList();
  }

  // ==================== 统计 ====================

  Future<Map<String, int>> stats() async {
    final result = <String, int>{};
    result['company'] = await countCompanies();
    result['person'] = await countPeople();
    result['opportunity'] = await countOpportunities();
    result['contract'] = await countContracts();
    for (final def in await listCustomObjects()) {
      result['custom:${def.id}'] = await countCustomRecords(def.id);
    }
    return result;
  }

  // ==================== 行 ↔ 模型 ====================

  CrmCompaniesCompanion _companyCompanion(LocalCompany c) {
    return CrmCompaniesCompanion(
      id: Value(c.id),
      name: Value(c.name),
      domainName: Value(c.domainName),
      addressJson: Value(c.address),
      employees: Value(c.employees),
      linkedinLink: Value(c.linkedinLink),
      xLink: Value(c.xLink),
      arrMicros: Value(c.arrMicros),
      icp: Value(c.icp),
      customerStatus: Value(c.customerStatus),
      createdAt: Value(c.createdAt),
      updatedAt: Value(c.updatedAt),
      deleted: Value(c.deleted),
    );
  }

  LocalCompany _companyFromRow(CrmCompanyRow row) => LocalCompany(
    id: row.id,
    name: row.name,
    domainName: row.domainName,
    address: row.addressJson,
    employees: row.employees,
    linkedinLink: row.linkedinLink,
    xLink: row.xLink,
    arrMicros: row.arrMicros,
    icp: row.icp,
    customerStatus: row.customerStatus,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmPeopleCompanion _personCompanion(LocalPerson p) {
    return CrmPeopleCompanion(
      id: Value(p.id),
      companyId: Value(p.companyId),
      firstName: Value(p.firstName),
      lastName: Value(p.lastName),
      jobTitle: Value(p.jobTitle),
      emailsJson: Value(p.emails),
      phonesJson: Value(p.phones),
      city: Value(p.city),
      wechat: Value(p.wechat),
      avatarUrl: Value(p.avatarUrl),
      linkedinLink: Value(p.linkedinLink),
      xLink: Value(p.xLink),
      createdAt: Value(p.createdAt),
      updatedAt: Value(p.updatedAt),
      deleted: Value(p.deleted),
    );
  }

  LocalPerson _personFromRow(CrmPersonRow row) => LocalPerson(
    id: row.id,
    companyId: row.companyId,
    firstName: row.firstName,
    lastName: row.lastName,
    jobTitle: row.jobTitle,
    emails: row.emailsJson,
    phones: row.phonesJson,
    city: row.city,
    wechat: row.wechat,
    avatarUrl: row.avatarUrl,
    linkedinLink: row.linkedinLink,
    xLink: row.xLink,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmOpportunitiesCompanion _opportunityCompanion(LocalOpportunity o) {
    return CrmOpportunitiesCompanion(
      id: Value(o.id),
      companyId: Value(o.companyId),
      pointOfContactId: Value(o.pointOfContactId),
      name: Value(o.name),
      amountMicros: Value(o.amountMicros),
      closeDate: Value(o.closeDate),
      stage: Value(o.stage),
      customStatus: Value(o.customStatus),
      createdAt: Value(o.createdAt),
      updatedAt: Value(o.updatedAt),
      deleted: Value(o.deleted),
    );
  }

  LocalOpportunity _opportunityFromRow(CrmOpportunityRow row) =>
      LocalOpportunity(
        id: row.id,
        companyId: row.companyId,
        pointOfContactId: row.pointOfContactId,
        name: row.name,
        amountMicros: row.amountMicros,
        closeDate: row.closeDate,
        stage: row.stage,
        customStatus: row.customStatus,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
      );

  CrmContractsCompanion _contractCompanion(LocalContract c) {
    return CrmContractsCompanion(
      id: Value(c.id),
      companyId: Value(c.companyId),
      name: Value(c.name),
      amountMicros: Value(c.amountMicros),
      currency: Value(c.currency),
      status: Value(c.status),
      dueDate: Value(c.dueDate),
      terms: Value(c.terms),
      createdAt: Value(c.createdAt),
      updatedAt: Value(c.updatedAt),
      deleted: Value(c.deleted),
    );
  }

  LocalContract _contractFromRow(CrmContractRow row) => LocalContract(
    id: row.id,
    companyId: row.companyId,
    name: row.name,
    amountMicros: row.amountMicros,
    currency: row.currency,
    status: row.status,
    dueDate: row.dueDate,
    terms: row.terms,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
  );

  CrmObjectDefsCompanion _objectDefCompanion(LocalCustomObject def) {
    return CrmObjectDefsCompanion(
      id: Value(def.id),
      labelSingular: Value(def.labelSingular),
      labelPlural: Value(def.labelPlural),
      icon: Value(def.icon),
      fieldsJson: Value(def.fields.map((f) => f.toJson()).toList()),
      builtin: Value(def.builtin),
      createdAt: Value(def.createdAt),
      updatedAt: Value(def.updatedAt),
    );
  }

  LocalCustomObject _objectDefFromRow(CrmObjectDefRow row) => LocalCustomObject(
    id: row.id,
    labelSingular: row.labelSingular,
    labelPlural: row.labelPlural,
    icon: row.icon,
    fields: row.fieldsJson
        .map((e) => CrmFieldDef.fromJson(e as Map<String, dynamic>))
        .toList(),
    builtin: row.builtin,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  CrmCustomRecordsCompanion _customRecordCompanion(LocalCustomRecord r) {
    return CrmCustomRecordsCompanion(
      id: Value(r.id),
      objectId: Value(r.objectId),
      label: Value(r.label),
      dataJson: Value(r.data),
      createdAt: Value(r.createdAt),
      updatedAt: Value(r.updatedAt),
      deleted: Value(r.deleted),
    );
  }

  LocalCustomRecord _customRecordFromRow(CrmCustomRecordRow row) =>
      LocalCustomRecord(
        id: row.id,
        objectId: row.objectId,
        label: row.label,
        data: row.dataJson,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
      );

  LocalEntityLink _linkFromRow(CrmEntityLinkRow row) => LocalEntityLink(
    id: row.id,
    entityType: row.entityType,
    entityId: row.entityId,
    localType: row.localType,
    localId: row.localId,
    relation: row.relation,
    createdAt: row.createdAt,
  );
}
