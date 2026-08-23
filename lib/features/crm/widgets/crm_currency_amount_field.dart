import 'package:flutter/material.dart';
import 'package:moodiary/features/crm/local/crm_field_defs.dart';

/// 货币复合输入：单个边框框内「币种下拉 | 金额输入」（Twenty 风格）。
class CrmCurrencyAmountField extends StatelessWidget {
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final TextEditingController amountController;
  final String label;
  final bool autoFocus;
  final ValueChanged<String>? onAmountSubmitted;

  const CrmCurrencyAmountField({
    super.key,
    required this.currency,
    required this.onCurrencyChanged,
    required this.amountController,
    required this.label,
    this.autoFocus = false,
    this.onAmountSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          DropdownButton<String>(
            value: kCurrencies.contains(currency) ? currency : kDefaultCurrency,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: [
              for (final c in kCurrencies)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) {
              if (v != null) onCurrencyChanged(v);
            },
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: amountController,
              autofocus: autoFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: onAmountSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
