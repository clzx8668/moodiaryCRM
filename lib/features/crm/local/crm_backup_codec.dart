import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:moodiary/features/crm/local/crm_models.dart';

/// 本地 CRM 全量导出/导入编解码（备份格式 `crm_local.json`，按 id 幂等合并）。
class CrmBackupCodec {
  static Future<Map<String, dynamic>> exportAll(
    CrmLocalRepository repo,
  ) async {
    String? date(DateTime? v) => v?.toIso8601String();
    return {
      'schema': 1,
      'accounts': [
        for (final a in await repo.listAccounts())
          {
            'id': a.id,
            'name': a.name,
            'type': a.type,
            'industry': a.industry,
            'level': a.level,
            'source': a.source,
            'phone': a.phone,
            'email': a.email,
            'address': a.address,
            'website': a.website,
            'creditCode': a.creditCode,
            'note': a.note,
            'status': a.status,
            'createdAt': date(a.createdAt),
            'updatedAt': date(a.updatedAt),
          },
      ],
      'contacts': [
        for (final c in await repo.listContacts())
          {
            'id': c.id,
            'accountId': c.accountId,
            'name': c.name,
            'title': c.title,
            'department': c.department,
            'phone': c.phone,
            'email': c.email,
            'wechat': c.wechat,
            'isPrimary': c.isPrimary,
            'isDecisionMaker': c.isDecisionMaker,
            'note': c.note,
            'createdAt': date(c.createdAt),
            'updatedAt': date(c.updatedAt),
          },
      ],
      'opportunities': [
        for (final o in await repo.listOpportunities())
          {
            'id': o.id,
            'accountId': o.accountId,
            'contactId': o.contactId,
            'name': o.name,
            'stage': o.stage,
            'probability': o.probability,
            'amount': o.amount,
            'currency': o.currency,
            'source': o.source,
            'leadContactName': o.leadContactName,
            'leadPhone': o.leadPhone,
            'leadEmail': o.leadEmail,
            'expectedCloseDate': date(o.expectedCloseDate),
            'actualCloseDate': date(o.actualCloseDate),
            'lossReason': o.lossReason,
            'note': o.note,
            'createdAt': date(o.createdAt),
            'updatedAt': date(o.updatedAt),
          },
      ],
      'contracts': [
        for (final c in await repo.listContracts())
          {
            'id': c.id,
            'contractNo': c.contractNo,
            'name': c.name,
            'accountId': c.accountId,
            'contactId': c.contactId,
            'opportunityId': c.opportunityId,
            'quoteId': c.quoteId,
            'status': c.status,
            'totalAmount': c.totalAmount,
            'paidAmount': c.paidAmount,
            'invoicedAmount': c.invoicedAmount,
            'signDate': date(c.signDate),
            'startDate': date(c.startDate),
            'endDate': date(c.endDate),
            'warrantyEndDate': date(c.warrantyEndDate),
            'note': c.note,
            'createdAt': date(c.createdAt),
            'updatedAt': date(c.updatedAt),
          },
      ],
      'products': [
        for (final p in await repo.listProducts())
          {
            'id': p.id,
            'categoryId': p.categoryId,
            'name': p.name,
            'sku': p.sku,
            'type': p.type,
            'unit': p.unit,
            'price': p.price,
            'cost': p.cost,
            'warrantyMonths': p.warrantyMonths,
            'isActive': p.isActive,
            'note': p.note,
            'createdAt': date(p.createdAt),
            'updatedAt': date(p.updatedAt),
          },
      ],
      'categories': [
        for (final c in await repo.listProductCategories())
          {'id': c.id, 'name': c.name, 'parentId': c.parentId},
      ],
      'quotes': [
        for (final q in await repo.listQuotes())
          {
            'id': q.id,
            'quoteNo': q.quoteNo,
            'opportunityId': q.opportunityId,
            'accountId': q.accountId,
            'contactId': q.contactId,
            'status': q.status,
            'totalAmount': q.totalAmount,
            'discountAmount': q.discountAmount,
            'validUntil': date(q.validUntil),
            'note': q.note,
            'createdAt': date(q.createdAt),
            'updatedAt': date(q.updatedAt),
          },
      ],
      'quoteItems': [
        for (final q in await repo.listQuotes())
          for (final i in await repo.quoteItems(q.id))
            {
              'id': i.id,
              'quoteId': i.quoteId,
              'productId': i.productId,
              'productName': i.productName,
              'quantity': i.quantity,
              'unitPrice': i.unitPrice,
              'discount': i.discount,
              'amount': i.amount,
              'sortOrder': i.sortOrder,
            },
      ],
      'contractItems': [
        for (final c in await repo.listContracts())
          for (final i in await repo.contractItems(c.id))
            {
              'id': i.id,
              'contractId': i.contractId,
              'productId': i.productId,
              'productName': i.productName,
              'quantity': i.quantity,
              'unitPrice': i.unitPrice,
              'amount': i.amount,
              'warrantyMonths': i.warrantyMonths,
              'sortOrder': i.sortOrder,
            },
      ],
      'paymentPlans': [
        for (final p in await repo.listPaymentPlans())
          {
            'id': p.id,
            'contractId': p.contractId,
            'planName': p.planName,
            'planAmount': p.planAmount,
            'paidAmount': p.paidAmount,
            'planDate': date(p.planDate),
            'status': p.status,
          },
      ],
      'payments': [
        for (final p in await repo.listPayments())
          {
            'id': p.id,
            'contractId': p.contractId,
            'planId': p.planId,
            'amount': p.amount,
            'paymentDate': date(p.paymentDate),
            'method': p.method,
            'invoiceId': p.invoiceId,
            'note': p.note,
            'createdAt': date(p.createdAt),
          },
      ],
      'invoices': [
        for (final i in await repo.listInvoices())
          {
            'id': i.id,
            'contractId': i.contractId,
            'invoiceNo': i.invoiceNo,
            'type': i.type,
            'amount': i.amount,
            'taxRate': i.taxRate,
            'issueDate': date(i.issueDate),
            'status': i.status,
            'receiverName': i.receiverName,
            'note': i.note,
            'createdAt': date(i.createdAt),
          },
      ],
      'warranties': [
        for (final w in await repo.listWarranties())
          {
            'id': w.id,
            'contractId': w.contractId,
            'contractItemId': w.contractItemId,
            'productId': w.productId,
            'serialNo': w.serialNo,
            'startDate': date(w.startDate),
            'endDate': date(w.endDate),
            'status': w.status,
            'note': w.note,
            'createdAt': date(w.createdAt),
          },
      ],
      'afterSales': [
        for (final t in await repo.listAfterSales())
          {
            'id': t.id,
            'ticketNo': t.ticketNo,
            'accountId': t.accountId,
            'contactId': t.contactId,
            'contractId': t.contractId,
            'warrantyId': t.warrantyId,
            'type': t.type,
            'priority': t.priority,
            'status': t.status,
            'subject': t.subject,
            'description': t.description,
            'resolution': t.resolution,
            'resolvedAt': date(t.resolvedAt),
            'closedAt': date(t.closedAt),
            'note': t.note,
            'createdAt': date(t.createdAt),
            'updatedAt': date(t.updatedAt),
          },
      ],
      'activities': [
        for (final a in await repo.listActivities())
          {
            'id': a.id,
            'type': a.type,
            'direction': a.direction,
            'relatedType': a.relatedType,
            'relatedId': a.relatedId,
            'subject': a.subject,
            'content': a.content,
            'status': a.status,
            'scheduledAt': date(a.scheduledAt),
            'completedAt': date(a.completedAt),
            'createdAt': date(a.createdAt),
          },
      ],
      'tags': [
        for (final t in await repo.listTags())
          {'id': t.id, 'name': t.name, 'color': t.color},
      ],
      'entityTags': [
        for (final entityType in [
          ...CrmLocalRepository.baseObjectTypes,
          ...(await repo.listCustomObjects()).map((o) => 'custom:${o.id}'),
        ])
          for (final tag in await _allTagsForType(repo, entityType))
            {'entityType': entityType, 'entityId': tag.$1, 'tagId': tag.$2},
      ],
      'attachments': [
        for (final a in await _allAttachments(repo))
          {
            'id': a.id,
            'relatedType': a.relatedType,
            'relatedId': a.relatedId,
            'fileName': a.fileName,
            'filePath': a.filePath,
            'mimeType': a.mimeType,
            'fileSize': a.fileSize,
            'createdAt': date(a.createdAt),
          },
      ],
      'reminders': [
        for (final r in await repo.listReminders(includeCompleted: true))
          {
            'id': r.id,
            'relatedType': r.relatedType,
            'relatedId': r.relatedId,
            'type': r.type,
            'title': r.title,
            'remindAt': date(r.remindAt),
            'isCompleted': r.isCompleted,
            'createdAt': date(r.createdAt),
          },
      ],
      'customObjects': [
        for (final o in await repo.listCustomObjects())
          {
            'id': o.id,
            'labelSingular': o.labelSingular,
            'labelPlural': o.labelPlural,
            'icon': o.icon,
            'fields': [for (final f in o.fields) f.toJson()],
            'builtin': o.builtin,
            'createdAt': date(o.createdAt),
            'updatedAt': date(o.updatedAt),
          },
      ],
      'customRecords': [
        for (final o in await repo.listCustomObjects())
          for (final r in await repo.listCustomRecords(o.id))
            {
              'id': r.id,
              'objectId': r.objectId,
              'label': r.label,
              'data': r.data,
              'createdAt': date(r.createdAt),
              'updatedAt': date(r.updatedAt),
            },
      ],
    };
  }

  static Future<List<(String, String)>> _allTagsForType(
    CrmLocalRepository repo,
    String entityType,
  ) async {
    final result = <(String, String)>[];
    final ids = <String>[];
    switch (entityType) {
      case 'account':
        ids.addAll((await repo.listAccounts()).map((a) => a.id));
      case 'contact':
        ids.addAll((await repo.listContacts()).map((c) => c.id));
      case 'opportunity':
        ids.addAll((await repo.listOpportunities()).map((o) => o.id));
      case 'contract':
        ids.addAll((await repo.listContracts()).map((c) => c.id));
      default:
        if (entityType.startsWith('custom:')) {
          ids.addAll(
            (await repo.listCustomRecords(entityType.substring(7)))
                .map((r) => r.id),
          );
        }
    }
    for (final id in ids) {
      for (final tag in await repo.tagsForEntity(entityType, id)) {
        result.add((id, tag.id));
      }
    }
    return result;
  }

  static Future<List<LocalAttachment>> _allAttachments(
    CrmLocalRepository repo,
  ) async {
    final result = <LocalAttachment>[];
    for (final entityType in [
      ...CrmLocalRepository.baseObjectTypes,
      ...(await repo.listCustomObjects()).map((o) => 'custom:${o.id}'),
    ]) {
      final ids = <String>[];
      switch (entityType) {
        case 'account':
          ids.addAll((await repo.listAccounts()).map((a) => a.id));
        case 'contact':
          ids.addAll((await repo.listContacts()).map((c) => c.id));
        case 'opportunity':
          ids.addAll((await repo.listOpportunities()).map((o) => o.id));
        case 'contract':
          ids.addAll((await repo.listContracts()).map((c) => c.id));
        default:
          if (entityType.startsWith('custom:')) {
            ids.addAll(
              (await repo.listCustomRecords(entityType.substring(7)))
                  .map((r) => r.id),
            );
          }
      }
      for (final id in ids) {
        result.addAll(await repo.listAttachments(entityType, id));
      }
    }
    return result;
  }

  static Future<void> importAll(
    CrmLocalRepository repo,
    Map<String, dynamic> data,
  ) async {
    DateTime? dt(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    String s(Object? v) => v?.toString() ?? '';

    for (final a in (data['accounts'] as List? ?? []).cast<Map>()) {
      await repo.createAccount(
        LocalAccount(
          id: s(a['id']),
          name: s(a['name']),
          type: s(a['type']),
          industry: s(a['industry']),
          level: s(a['level']),
          source: s(a['source']),
          phone: s(a['phone']),
          email: s(a['email']),
          address: s(a['address']),
          website: s(a['website']),
          creditCode: s(a['creditCode']),
          note: s(a['note']),
          status: s(a['status']),
        ),
      );
    }
    for (final c in (data['contacts'] as List? ?? []).cast<Map>()) {
      await repo.createContact(
        LocalContact(
          id: s(c['id']),
          accountId: s(c['accountId']),
          name: s(c['name']),
          title: s(c['title']),
          department: s(c['department']),
          phone: s(c['phone']),
          email: s(c['email']),
          wechat: s(c['wechat']),
          isPrimary: c['isPrimary'] == true,
          isDecisionMaker: c['isDecisionMaker'] == true,
          note: s(c['note']),
        ),
      );
    }
    for (final o in (data['opportunities'] as List? ?? []).cast<Map>()) {
      await repo.createOpportunity(
        LocalOpportunity(
          id: s(o['id']),
          accountId: s(o['accountId']),
          contactId: s(o['contactId']),
          name: s(o['name']),
          stage: s(o['stage']),
          probability: i(o['probability']),
          amount: d(o['amount']),
          currency: s(o['currency']),
          source: s(o['source']),
          leadContactName: s(o['leadContactName']),
          leadPhone: s(o['leadPhone']),
          leadEmail: s(o['leadEmail']),
          expectedCloseDate: dt(o['expectedCloseDate']),
          actualCloseDate: dt(o['actualCloseDate']),
          lossReason: s(o['lossReason']),
          note: s(o['note']),
        ),
      );
    }
    for (final c in (data['contracts'] as List? ?? []).cast<Map>()) {
      await repo.createContract(
        LocalContract(
          id: s(c['id']),
          contractNo: s(c['contractNo']),
          name: s(c['name']),
          accountId: s(c['accountId']),
          contactId: s(c['contactId']),
          opportunityId: s(c['opportunityId']),
          quoteId: s(c['quoteId']),
          status: s(c['status']),
          totalAmount: d(c['totalAmount']),
          paidAmount: d(c['paidAmount']),
          invoicedAmount: d(c['invoicedAmount']),
          signDate: dt(c['signDate']),
          startDate: dt(c['startDate']),
          endDate: dt(c['endDate']),
          warrantyEndDate: dt(c['warrantyEndDate']),
          note: s(c['note']),
        ),
      );
    }
    for (final p in (data['products'] as List? ?? []).cast<Map>()) {
      await repo.createProduct(
        LocalProduct(
          id: s(p['id']),
          categoryId: s(p['categoryId']),
          name: s(p['name']),
          sku: s(p['sku']),
          type: s(p['type']),
          unit: s(p['unit']),
          price: d(p['price']),
          cost: d(p['cost']),
          warrantyMonths: i(p['warrantyMonths']),
          isActive: p['isActive'] != false,
          note: s(p['note']),
        ),
      );
    }
    for (final c in (data['categories'] as List? ?? []).cast<Map>()) {
      await repo.createProductCategory(
        LocalProductCategory(
          id: s(c['id']),
          name: s(c['name']),
          parentId: s(c['parentId']),
        ),
      );
    }
    for (final q in (data['quotes'] as List? ?? []).cast<Map>()) {
      await repo.createQuote(
        LocalQuote(
          id: s(q['id']),
          quoteNo: s(q['quoteNo']),
          opportunityId: s(q['opportunityId']),
          accountId: s(q['accountId']),
          contactId: s(q['contactId']),
          status: s(q['status']),
          totalAmount: d(q['totalAmount']),
          discountAmount: d(q['discountAmount']),
          validUntil: dt(q['validUntil']),
          note: s(q['note']),
        ),
      );
    }
    for (final item in (data['quoteItems'] as List? ?? []).cast<Map>()) {
      await repo.addQuoteItem(
        LocalQuoteItem(
          id: s(item['id']),
          quoteId: s(item['quoteId']),
          productId: s(item['productId']),
          productName: s(item['productName']),
          quantity: d(item['quantity']),
          unitPrice: d(item['unitPrice']),
          discount: d(item['discount']),
          amount: d(item['amount']),
          sortOrder: i(item['sortOrder']),
        ),
      );
    }
    for (final item in (data['contractItems'] as List? ?? []).cast<Map>()) {
      await repo.addContractItem(
        LocalContractItem(
          id: s(item['id']),
          contractId: s(item['contractId']),
          productId: s(item['productId']),
          productName: s(item['productName']),
          quantity: d(item['quantity']),
          unitPrice: d(item['unitPrice']),
          amount: d(item['amount']),
          warrantyMonths: i(item['warrantyMonths']),
          sortOrder: i(item['sortOrder']),
        ),
      );
    }
    for (final p in (data['paymentPlans'] as List? ?? []).cast<Map>()) {
      await repo.createPaymentPlan(
        LocalPaymentPlan(
          id: s(p['id']),
          contractId: s(p['contractId']),
          planName: s(p['planName']),
          planAmount: d(p['planAmount']),
          paidAmount: d(p['paidAmount']),
          planDate: dt(p['planDate']) ?? DateTime.now(),
          status: s(p['status']),
        ),
      );
    }
    for (final p in (data['payments'] as List? ?? []).cast<Map>()) {
      await repo.createPayment(
        LocalPayment(
          id: s(p['id']),
          contractId: s(p['contractId']),
          planId: s(p['planId']),
          amount: d(p['amount']),
          paymentDate: dt(p['paymentDate']) ?? DateTime.now(),
          method: s(p['method']),
          invoiceId: s(p['invoiceId']),
          note: s(p['note']),
        ),
      );
    }
    for (final inv in (data['invoices'] as List? ?? []).cast<Map>()) {
      await repo.createInvoice(
        LocalInvoice(
          id: s(inv['id']),
          contractId: s(inv['contractId']),
          invoiceNo: s(inv['invoiceNo']),
          type: s(inv['type']),
          amount: d(inv['amount']),
          taxRate: d(inv['taxRate']),
          issueDate: dt(inv['issueDate']),
          status: s(inv['status']),
          receiverName: s(inv['receiverName']),
          note: s(inv['note']),
        ),
      );
    }
    for (final w in (data['warranties'] as List? ?? []).cast<Map>()) {
      await repo.createWarranty(
        LocalWarranty(
          id: s(w['id']),
          contractId: s(w['contractId']),
          contractItemId: s(w['contractItemId']),
          productId: s(w['productId']),
          serialNo: s(w['serialNo']),
          startDate: dt(w['startDate']) ?? DateTime.now(),
          endDate: dt(w['endDate']) ?? DateTime.now(),
          status: s(w['status']),
          note: s(w['note']),
        ),
      );
    }
    for (final t in (data['afterSales'] as List? ?? []).cast<Map>()) {
      await repo.createAfterSales(
        LocalAfterSales(
          id: s(t['id']),
          ticketNo: s(t['ticketNo']),
          accountId: s(t['accountId']),
          contactId: s(t['contactId']),
          contractId: s(t['contractId']),
          warrantyId: s(t['warrantyId']),
          type: s(t['type']),
          priority: s(t['priority']),
          status: s(t['status']),
          subject: s(t['subject']),
          description: s(t['description']),
          resolution: s(t['resolution']),
          resolvedAt: dt(t['resolvedAt']),
          closedAt: dt(t['closedAt']),
          note: s(t['note']),
        ),
      );
    }
    for (final a in (data['activities'] as List? ?? []).cast<Map>()) {
      await repo.createActivity(
        LocalActivity(
          id: s(a['id']),
          type: s(a['type']),
          direction: s(a['direction']),
          relatedType: s(a['relatedType']),
          relatedId: s(a['relatedId']),
          subject: s(a['subject']),
          content: s(a['content']),
          status: s(a['status']),
          scheduledAt: dt(a['scheduledAt']),
          completedAt: dt(a['completedAt']),
        ),
      );
    }
    for (final t in (data['tags'] as List? ?? []).cast<Map>()) {
      await repo.createTag(s(t['name']));
    }
    for (final et in (data['entityTags'] as List? ?? []).cast<Map>()) {
      final entityType = s(et['entityType']);
      final entityId = s(et['entityId']);
      final tagId = s(et['tagId']);
      final tags = await repo.tagsForEntity(entityType, entityId);
      final tag = tags.where((t) => t.id == tagId).toList();
      if (tag.isNotEmpty) {
        await repo.setEntityTags(
          entityType,
          entityId,
          [...tags.map((t) => t.name)],
        );
      }
    }
    for (final a in (data['attachments'] as List? ?? []).cast<Map>()) {
      await repo.addAttachment(
        LocalAttachment(
          id: s(a['id']),
          relatedType: s(a['relatedType']),
          relatedId: s(a['relatedId']),
          fileName: s(a['fileName']),
          filePath: s(a['filePath']),
          mimeType: s(a['mimeType']),
          fileSize: a['fileSize'] == null ? null : i(a['fileSize']),
        ),
      );
    }
    for (final r in (data['reminders'] as List? ?? []).cast<Map>()) {
      await repo.createReminder(
        LocalReminder(
          id: s(r['id']),
          relatedType: s(r['relatedType']),
          relatedId: s(r['relatedId']),
          type: s(r['type']),
          title: s(r['title']),
          remindAt: dt(r['remindAt']) ?? DateTime.now(),
          isCompleted: r['isCompleted'] == true,
        ),
      );
    }
    for (final o in (data['customObjects'] as List? ?? []).cast<Map>()) {
      await repo.createCustomObject(
        LocalCustomObject(
          id: s(o['id']),
          labelSingular: s(o['labelSingular']),
          labelPlural: s(o['labelPlural']),
          icon: s(o['icon']),
          fields: [
            for (final f in (o['fields'] as List? ?? []).cast<Map>())
              CrmFieldDef.fromJson(f.cast<String, dynamic>()),
          ],
          builtin: o['builtin'] == true,
        ),
      );
    }
    for (final r in (data['customRecords'] as List? ?? []).cast<Map>()) {
      await repo.createCustomRecord(
        LocalCustomRecord(
          id: s(r['id']),
          objectId: s(r['objectId']),
          label: s(r['label']),
          data: (r['data'] as Map? ?? {}).cast<String, dynamic>(),
        ),
      );
    }
  }
}
