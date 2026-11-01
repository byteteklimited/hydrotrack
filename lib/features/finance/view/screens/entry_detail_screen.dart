import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/cash_entry.dart';

/// Same reasoning as every other detail screen in the app: content
/// reads best at a bounded width, implemented as responsive padding so
/// `ListView` keeps its native scroll behavior.
const double _contentCap = 720;

/// Full record of one cash entry, including who recorded it.
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({super.key, required this.entry});

  final CashEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = entry.direction == CashDirection.moneyOut;

    return Scaffold(
      appBar: AppBar(title: Text(entry.note ?? entry.source.label)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.lg,
            ),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isOut ? '-' : '+'}${formatNaira(entry.amount)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: isOut ? AppColors.moneyOut : AppColors.moneyIn,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailRow(
                      label: 'Direction',
                      value: entry.direction.label,
                    ),
                    _DetailRow(label: 'Source', value: entry.source.label),
                    _DetailRow(label: 'Method', value: entry.method.label),
                    _DetailRow(
                      label: 'Date & time',
                      value: DateFormat.yMMMd().add_jm().format(entry.dateTime),
                    ),
                    if (entry.note != null)
                      _DetailRow(label: 'Note', value: entry.note!),
                    _DetailRow(label: 'Recorded by', value: entry.recordedBy),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
