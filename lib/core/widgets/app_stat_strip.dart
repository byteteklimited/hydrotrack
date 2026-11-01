import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';
import 'app_stat.dart';

/// One entry in an [AppStatStrip]. Pass [onTap] for the rare item that's
/// its own drill-down (e.g. "Money outside" opening Debts) — the rest of
/// the strip stays non-interactive, so only that one figure gets a tap
/// affordance rather than the whole panel appearing clickable.
class AppStatStripItem {
  const AppStatStripItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.qualifier,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? qualifier;
  final VoidCallback? onTap;
}

/// Several related figures inside ONE panel, separated by thin vertical
/// dividers, instead of a separate card per number — e.g. "Cash today /
/// Transfer today / Bags sold today" on one row. Wraps to a 2-column grid
/// once the strip is too narrow for every item to sit comfortably in a
/// single row.
class AppStatStrip extends StatelessWidget {
  const AppStatStrip({super.key, required this.items});

  final List<AppStatStripItem> items;

  static const double _minItemWidth = 140;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxPerRow = (constraints.maxWidth / _minItemWidth)
              .floor()
              .clamp(1, items.length);
          final wrap = maxPerRow < items.length;

          if (!wrap) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i != 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: VerticalDivider(
                          width: 1,
                          color: AppColors.border,
                        ),
                      ),
                    Expanded(child: _Item(items[i])),
                  ],
                ],
              ),
            );
          }

          // Narrower than every item fits on one row: a 2-column grid
          // instead, with a divider only between rows (a vertical one
          // between two differently-sized columns reads oddly).
          return Column(
            children: [
              for (var row = 0; row < items.length; row += 2) ...[
                if (row != 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Item(items[row])),
                    if (row + 1 < items.length) ...[
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: _Item(items[row + 1])),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.item);

  final AppStatStripItem item;

  @override
  Widget build(BuildContext context) {
    final stat = AppStat(
      label: item.label,
      value: item.value,
      valueColor: item.valueColor,
      qualifier: item.qualifier,
    );

    if (item.onTap == null) return stat;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.xs), child: stat),
    );
  }
}
