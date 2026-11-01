import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single pulsing placeholder block, for a loading state that already
/// knows roughly what shape its real content will be (a stat figure, a
/// table row) — reads as "this is about to be a number" rather than a
/// bare spinner that gives no sense of the page's shape.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.width, this.height = 14, this.radius = 4});

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.5, end: 1.0)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.hoverNeutral,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A loading placeholder for an [AppStatStrip]/[AppStat]-shaped figure —
/// a short label-width bar above a wider value-width bar.
class AppSkeletonStat extends StatelessWidget {
  const AppSkeletonStat({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSkeleton(width: 90, height: 12),
        SizedBox(height: AppSpacing.sm),
        AppSkeleton(width: 70, height: 22),
      ],
    );
  }
}

/// A loading placeholder for a row in a list/table — a few bars of
/// decreasing width standing in for a name, a detail, and an amount.
class AppSkeletonRow extends StatelessWidget {
  const AppSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(flex: 3, child: AppSkeleton()),
          SizedBox(width: AppSpacing.lg),
          Expanded(flex: 2, child: AppSkeleton()),
          SizedBox(width: AppSpacing.lg),
          Expanded(child: AppSkeleton()),
        ],
      ),
    );
  }
}
