import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/responsive_center.dart';

/// The shared layout of the Quality tabs: pull to refresh, centered,
/// comfortable reading width.
class QualityTabList extends StatelessWidget {
  const QualityTabList({
    super.key,
    required this.onRefresh,
    required this.children,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  static const _maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
