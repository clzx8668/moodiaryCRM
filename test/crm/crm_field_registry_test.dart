import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/features/crm/crm_field_registry.dart';

void main() {
  group('CrmFieldRegistry.defaultDisplayFields', () {
    test('标签字段置顶 + 可展示标量按 metadata 顺序', () {
      const meta = CrmObjectMeta(
        nameSingular: 'company',
        namePlural: 'companies',
        labelSingular: 'Company',
        labelField: 'name',
        fields: [
          CrmFieldMeta(name: 'id', label: 'Id', type: 'UUID', isSystem: true),
          CrmFieldMeta(name: 'name', label: 'Name', type: 'TEXT'),
          CrmFieldMeta(
            name: 'people',
            label: 'People',
            type: 'RELATION',
          ),
          CrmFieldMeta(
            name: 'createdAt',
            label: 'Creation date',
            type: 'DATE_TIME',
            isSystem: true,
          ),
          CrmFieldMeta(name: 'address', label: 'Address', type: 'ADDRESS'),
          CrmFieldMeta(name: 'employees', label: 'Employees', type: 'NUMBER'),
        ],
      );

      final display = CrmFieldRegistry.defaultDisplayFields(meta);

      expect(display.map((f) => f.name), ['name', 'address', 'employees']);
    });

    test('无 name/title 时退化为第一个可展示字段', () {
      const meta = CrmObjectMeta(
        nameSingular: 'commission',
        namePlural: 'commissions',
        labelSingular: 'Commission',
        labelField: 'name',
        fields: [
          CrmFieldMeta(
            name: 'noteTargets',
            label: 'Notes',
            type: 'RELATION',
          ),
        ],
      );

      final display = CrmFieldRegistry.defaultDisplayFields(meta);

      expect(display, isEmpty);
    });

    test('isDisplayableField 排除系统/审计/关系字段', () {
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(name: 'name', label: 'Name', type: 'TEXT'),
        ),
        isTrue,
      );
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(
            name: 'createdAt',
            label: 'Date',
            type: 'DATE_TIME',
            isSystem: true,
          ),
        ),
        isFalse,
      );
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(
            name: 'people',
            label: 'People',
            type: 'RELATION',
          ),
        ),
        isFalse,
      );
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(name: 'companyId', label: 'Company', type: 'UUID'),
        ),
        isFalse,
      );
    });

    test('schema 风格：复合标量可展示，关系对象排除', () {
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(name: 'domainName', label: 'Domain', type: 'Links'),
        ),
        isTrue,
      );
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(
            name: 'annualRecurringRevenue',
            label: 'ARR',
            type: 'Currency',
          ),
        ),
        isTrue,
      );
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(
            name: 'people',
            label: 'People',
            type: 'PersonConnection',
          ),
        ),
        isFalse,
      );
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(
            name: 'accountOwner',
            label: 'Owner',
            type: 'WorkspaceMember',
          ),
        ),
        isFalse,
      );
      // 枚举（schema ENUM → SELECT）
      expect(
        CrmFieldRegistry.isDisplayableField(
          const CrmFieldMeta(
            name: 'customerstatus',
            label: 'Customer Status',
            type: 'SELECT',
          ),
        ),
        isTrue,
      );
    });

    test('mergeCustomizedWithDefaults 追加新增默认字段且保留自定义顺序', () {
      const meta = CrmObjectMeta(
        nameSingular: 'company',
        namePlural: 'companies',
        labelSingular: 'Company',
        labelField: 'name',
        fields: [
          CrmFieldMeta(name: 'name', label: 'Name', type: 'TEXT'),
          CrmFieldMeta(name: 'address', label: 'Address', type: 'ADDRESS'),
          CrmFieldMeta(name: 'xLink', label: 'X', type: 'Links'),
          CrmFieldMeta(name: 'linkedinLink', label: 'Linkedin', type: 'Links'),
          CrmFieldMeta(name: 'domainName', label: 'Domain Name', type: 'Links'),
          CrmFieldMeta(name: 'employees', label: 'Employees', type: 'Float'),
          CrmFieldMeta(
            name: 'annualRecurringRevenue',
            label: 'ARR',
            type: 'Currency',
          ),
          CrmFieldMeta(
            name: 'customerstatus',
            label: 'CustomerStatus',
            type: 'SELECT',
          ),
          CrmFieldMeta(name: 'people', label: 'People', type: 'RELATION'),
        ],
      );
      // 旧自定义只保留了 3 个字段（历史列设置保存的）
      const customized = ['name', 'address', 'xLink', 'linkedinLink'];
      final available = {
        'name',
        'address',
        'xLink',
        'linkedinLink',
        'domainName',
        'employees',
        'annualRecurringRevenue',
        'customerstatus',
        'people',
      };

      final merged = CrmFieldRegistry.mergeCustomizedWithDefaults(
        customized,
        meta,
        available,
      );

      expect(merged, [
        'name',
        'address',
        'xLink',
        'linkedinLink',
        'domainName',
        'employees',
        'annualRecurringRevenue',
        'customerstatus',
      ]);
      expect(merged, isNot(contains('people')));
    });
  });

  group('CrmFieldRegistry.objectMetaName', () {
    test('覆盖全部 CRM Tab 对象', () {
      expect(
        CrmFieldRegistry.objectMetaName,
        containsPair('company', 'company'),
      );
      expect(CrmFieldRegistry.objectMetaName['contractsHeTongGuanLi'], 'contract');
      expect(CrmFieldRegistry.objectMetaName['paymentsHuiKuanJiLu'], 'payment');
      expect(CrmFieldRegistry.objectMetaName['invoiceFaPiao'], 'invoice');
      expect(
        CrmFieldRegistry.objectMetaName['commissionsTiChengJieSuan'],
        'commission',
      );
      expect(CrmFieldRegistry.objectMetaName['moodiaryGeneric'], 'moodiaryGeneric');
    });
  });
}
