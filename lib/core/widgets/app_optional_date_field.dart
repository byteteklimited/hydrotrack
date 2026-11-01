import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_button.dart';

/// A nullable date picker — "expiry date", "best before" — anywhere a
/// date genuinely might not apply (not every item or batch expires).
/// Shows [label] as a prompt until a date is picked, then the formatted
/// date with a clear action to go back to null.
class AppOptionalDateField extends StatelessWidget {
  const AppOptionalDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: selected == null
                ? label
                : DateFormat.yMMMd().format(selected),
            leadingIcon: Icons.calendar_today_outlined,
            variant: AppButtonVariant.secondary,
            expanded: true,
            onPressed: () => _pick(context),
          ),
        ),
        if (selected != null)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Remove date',
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}
