import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_button.dart';

/// A date and time (e.g. when a machine stopped), picked with the date
/// then the time picker. Can't be later than now.
class AppDateTimeField extends StatelessWidget {
  const AppDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  /// How far back a date can be picked.
  static const _maxDaysBack = 90;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: now.subtract(const Duration(days: _maxDaysBack)),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    onChanged(picked.isAfter(now) ? now : picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        AppButton(
          label: DateFormat('EEE d MMM, h:mm a').format(value),
          leadingIcon: Icons.schedule,
          variant: AppButtonVariant.secondary,
          expanded: true,
          onPressed: () => _pick(context),
        ),
      ],
    );
  }
}
