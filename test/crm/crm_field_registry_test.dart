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
