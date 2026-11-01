import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card_grid.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/report_period.dart';
import '../../data/models/report_summary.dart';
import '../../data/providers/reports_providers.dart';
import '../widgets/cash_report_card.dart';
import '../widgets/money_outside_report_card.dart';
import '../widgets/production_report_card.dart';
import '../widgets/profit_report_card.dart';
import '../widgets/report_export_row.dart';
import '../widgets/report_period_control.dart';
import '../widgets/sales_report_card.dart';
import '../widgets/stock_report_card.dart';

/// Wider than the usual 900 list cap — six cards in a grid need more
/// total width than a single column of rows before it's worth capping.
const double _contentCap = 1200;

/// Reports: pick a period, then read it top to bottom the way an owner
/// would — profit first, then what explains it.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > _contentCap
              ? (constraints.maxWidth - _contentCap) / 2
              : AppSpacing.lg;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(reportSummaryProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: AppSpacing.lg,
              ),
              children: [
                const ReportPeriodControl(),
                const SizedBox(height: AppSpacing.lg),
                switch (summaryAsync) {
                  AsyncData(:final value) => _ReportSections(summary: value),
                  AsyncError() => AppErrorState(
                    message:
                        "Couldn't load this report. Check your connection and try again.",
                    onRetry: () => ref.invalidate(reportSummaryProvider),
                  ),
                  _ => const AppLoading(message: 'Building report…'),
                },
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportSections extends StatelessWidget {
  const _ReportSections({required this.summary});

  final ReportSummary summary;

  bool get _isEmpty =>
      summary.production.bagsProduced == 0 &&
      summary.sales.bagsSold == 0 &&
      summary.cash.cashIn == 0 &&
      summary.cash.cashOut == 0;

  @override
  Widget build(BuildContext context) {
    if (summary.period.type == ReportPeriodType.custom && _isEmpty) {
      return const AppEmptyState(
        icon: Icons.insert_chart_outlined,
        title: 'Nothing here',
        message: 'Nothing recorded in this period.',
      );
    }

    final comparisonLabel = summary.period.comparisonLabel;

    return Column(
      children: [
        AppCardGrid(
          cards: [
            ProfitReportCard(
              profit: summary.profit,
              comparisonLabel: comparisonLabel,
            ),
            SalesReportCard(
              sales: summary.sales,
              comparisonLabel: comparisonLabel,
            ),
            ProductionReportCard(
              production: summary.production,
              comparisonLabel: comparisonLabel,
            ),
            CashReportCard(
              cash: summary.cash,
              comparisonLabel: comparisonLabel,
            ),
            MoneyOutsideReportCard(
              moneyOutside: summary.moneyOutside,
              comparisonLabel: comparisonLabel,
            ),
            StockReportCard(
              stock: summary.stock,
              comparisonLabel: comparisonLabel,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        ReportExportRow(summary: summary),
      ],
    );
  }
}
