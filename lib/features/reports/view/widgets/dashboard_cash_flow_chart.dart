import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/dashboard_snapshot.dart';

final _compactNaira = NumberFormat.compactCurrency(
  locale: 'en_NG',
  symbol: '₦',
);

/// Money in vs money out, one bar pair per day, for the last 7 days. Per
/// the brand guide's own chart rule, "In" is brand blue here (not the
/// green used for a money-in amount elsewhere in the app) and "Out" is
/// brand red — the guide explicitly calls out "the 'In' series in
/// charts" as blue, distinct from a plain money-in figure.
class DashboardCashFlowChart extends StatelessWidget {
  const DashboardCashFlowChart({super.key, required this.days});

  final List<CashFlowDay> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = days
        .expand((d) => [d.moneyIn, d.moneyOut])
        .fold<num>(0, (max, v) => v > max ? v : max);
    final hasData = maxValue > 0;
    // A flat zero chart still needs a visible axis to draw against.
    final chartMaxY = hasData ? (maxValue * 1.2) : 1000;

    return AppCard(
      title: 'Cash flow · last 7 days',
      trailing: const _CashFlowLegend(),
      child: Stack(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: chartMaxY.toDouble(),
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxY / 4,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: chartMaxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          _compactNaira.format(value),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            DateFormat.E().format(days[index].date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: hasData,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.neutralDark,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'In' : 'Out';
                      return BarTooltipItem(
                        '$label: ${formatNaira(rod.toY)}',
                        const TextStyle(color: AppColors.surfaceWhite),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: days[i].moneyIn.toDouble(),
                          color: AppColors.brandNavy,
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        BarChartRodData(
                          toY: days[i].moneyOut.toDouble(),
                          color: AppColors.dangerFg,
                          width: 8,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (!hasData)
            Positioned(
              left: 44,
              right: 0,
              top: 0,
              bottom: 28,
              child: Center(
                child: Text(
                  'No transactions in the last 7 days',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CashFlowLegend extends StatelessWidget {
  const _CashFlowLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: AppColors.brandNavy, label: 'In'),
        SizedBox(width: AppSpacing.md),
        _LegendDot(color: AppColors.dangerFg, label: 'Out'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
