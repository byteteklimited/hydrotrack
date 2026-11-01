import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

/// Plain-text form of a comparison line ("₦84,000 more than last week",
/// "Same as yesterday") plus whether that change is good news, so the
/// PDF/CSV exporters can reuse the exact wording [ReportComparisonLine]
/// shows on screen instead of recomputing it separately.
class ReportComparisonText {
  const ReportComparisonText({required this.text, required this.isGood});

  final String text;

  /// Null when there's no change to judge (`Same as ...`).
  final bool? isGood;
}

ReportComparisonText formatReportComparison({
  required num current,
  required num previous,
  required String comparisonLabel,
  bool higherIsBetter = true,
  String Function(num value)? formatValue,
}) {
  final diff = current - previous;
  final format = formatValue ?? formatNaira;

  if (diff == 0) {
    return ReportComparisonText(text: 'Same as $comparisonLabel', isGood: null);
  }

  final isIncrease = diff > 0;
  final isGood = higherIsBetter ? isIncrease : !isIncrease;
  final direction = isIncrease ? 'more' : 'less';

  return ReportComparisonText(
    text: '${format(diff.abs())} $direction than $comparisonLabel',
    isGood: isGood,
  );
}

/// "₦84,000 more than last week" — green when the change is good news,
/// red when it isn't. [higherIsBetter] decides which direction is good
/// for this particular figure (more profit is good; more money outside
/// isn't).
class ReportComparisonLine extends StatelessWidget {
  const ReportComparisonLine({
    super.key,
    required this.current,
    required this.previous,
    required this.comparisonLabel,
    this.higherIsBetter = true,
    this.formatValue,
  });

  final num current;
  final num previous;
  final String comparisonLabel;
  final bool higherIsBetter;

  /// Formats the absolute difference, unit included (e.g. "3 bags",
  /// "2 items"). Defaults to naira.
  final String Function(num value)? formatValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comparison = formatReportComparison(
      current: current,
      previous: previous,
      comparisonLabel: comparisonLabel,
      higherIsBetter: higherIsBetter,
      formatValue: formatValue,
    );

    if (comparison.isGood == null) {
      return Text(
        comparison.text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final color = comparison.isGood! ? AppColors.moneyIn : AppColors.moneyOut;

    return Text(
      comparison.text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
