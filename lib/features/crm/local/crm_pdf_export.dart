import 'dart:io';

import 'package:moodiary/features/crm/local/crm_local_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// 报价/合同/发票 PDF 导出（保存到应用文档目录 Exports/CRM/）。
class CrmPdfExport {
  static Future<String> exportQuote(
    CrmLocalRepository repo,
    String quoteId,
  ) async {
    final bytes = await quotePdfBytes(repo, quoteId);
    final quote = await repo.getQuote(quoteId);
    return _save('${quote!.quoteNo}.pdf', bytes);
  }

  /// 报价单 PDF 字节（纯函数，便于测试）。
  static Future<List<int>> quotePdfBytes(
    CrmLocalRepository repo,
    String quoteId,
  ) async {
    final quote = await repo.getQuote(quoteId);
    if (quote == null) throw StateError('报价单不存在');
    final items = await repo.quoteItems(quoteId);
    final account = await repo.getAccount(quote.accountId ?? '');

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _title('报价单 ${quote.quoteNo}'),
          _kv('状态', quote.status),
          _kv('客户', account?.name ?? '-'),
          _kv('有效期至', quote.validUntil?.toLocal().toString().substring(0, 10) ?? '-'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['产品', '数量', '单价', '折扣', '小计'],
            data: [
              for (final item in items)
                [
                  item.productName,
                  item.quantity.toString(),
                  item.unitPrice.toStringAsFixed(2),
                  '${(item.discount * 100).toStringAsFixed(0)}%',
                  item.amount.toStringAsFixed(2),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          _kv('合计', '¥ ${quote.totalAmount.toStringAsFixed(2)}'),
          _kv('备注', quote.note),
        ],
      ),
    );
    return doc.save();
  }

  static Future<String> exportContract(
    CrmLocalRepository repo,
    String contractId,
  ) async {
    final bytes = await contractPdfBytes(repo, contractId);
    final contract = await repo.getContract(contractId);
    return _save('${contract!.contractNo}.pdf', bytes);
  }

  static Future<List<int>> contractPdfBytes(
    CrmLocalRepository repo,
    String contractId,
  ) async {
    final contract = await repo.getContract(contractId);
    if (contract == null) throw StateError('合同不存在');
    final items = await repo.contractItems(contractId);
    final account = await repo.getAccount(contract.accountId ?? '');

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _title('合同 ${contract.contractNo}'),
          _kv('名称', contract.name),
          _kv('客户', account?.name ?? '-'),
          _kv('状态', contract.status),
          _kv('签约/开始/结束',
              '${_date(contract.signDate)} / ${_date(contract.startDate)} / ${_date(contract.endDate)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['产品', '数量', '单价', '小计', '质保(月)'],
            data: [
              for (final item in items)
                [
                  item.productName,
                  item.quantity.toString(),
                  item.unitPrice.toStringAsFixed(2),
                  item.amount.toStringAsFixed(2),
                  item.warrantyMonths.toString(),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          _kv('总金额', '¥ ${contract.totalAmount.toStringAsFixed(2)}'),
          _kv('已回款 / 已开票',
              '¥ ${contract.paidAmount.toStringAsFixed(2)} / ¥ ${contract.invoicedAmount.toStringAsFixed(2)}'),
          _kv('备注', contract.note),
        ],
      ),
    );
    return doc.save();
  }

  static Future<String> exportInvoice(
    CrmLocalRepository repo,
    String invoiceId,
  ) async {
    final bytes = await invoicePdfBytes(repo, invoiceId);
    final invoice = await repo.getInvoice(invoiceId);
    return _save(
      '${invoice!.invoiceNo.isEmpty ? '发票' : invoice.invoiceNo}.pdf',
      bytes,
    );
  }

  static Future<List<int>> invoicePdfBytes(
    CrmLocalRepository repo,
    String invoiceId,
  ) async {
    final invoice = await repo.getInvoice(invoiceId);
    if (invoice == null) throw StateError('发票不存在');
    final contract = await repo.getContract(invoice.contractId);
    final account = await repo.getAccount(contract?.accountId ?? '');

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _title('发票'),
          _kv('发票号', invoice.invoiceNo),
          _kv('客户', account?.name ?? '-'),
          _kv('合同', contract?.contractNo ?? '-'),
          _kv('类型', invoice.type),
          _kv('金额', '¥ ${invoice.amount.toStringAsFixed(2)}'),
          _kv('税率', '${(invoice.taxRate * 100).toStringAsFixed(0)}%'),
          _kv('开票日期', _date(invoice.issueDate)),
          _kv('状态', invoice.status),
          _kv('收票人', invoice.receiverName),
          _kv('备注', invoice.note),
        ],
      ),
    );
    return doc.save();
  }

  static Future<String> _save(String fileName, List<int> bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Exports', 'CRM'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static pw.Widget _title(String text) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _kv(String label, String value) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 90,
              child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
            ),
            pw.Expanded(child: pw.Text(value)),
          ],
        ),
      );

  static String _date(DateTime? date) =>
      date?.toLocal().toString().substring(0, 10) ?? '-';
}
