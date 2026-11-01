import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_day_switcher.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/payroll_providers.dart';

/// The shared layout of the Workers & pay tabs; [withDay] adds the day
/// switcher the Attendance and Bags tabs share.
class PayTabList extends ConsumerWidget {
  const PayTabList({super.key, required this.children, this.withDay = false});

  final List<Widget> children;
  final bool withDay;

  static const _maxContentWidth = 720.0;

  /// How far back attendance and bags can be entered.
  static const _daysBack = 31;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ResponsiveCenter(
          maxWidth: _maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (withDay) ...[
                AppDaySwitcher(
                  day: ref.watch(payDayProvider),
                  earliestDaysBack: _daysBack,
                  onChanged: (day) =>
                      ref.read(payDayProvider.notifier).state = day,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              ...children,
            ],
          ),
        ),
      ],
    );
  }
}
