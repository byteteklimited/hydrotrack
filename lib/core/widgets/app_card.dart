import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The app's one signature surface: a flat card (styled by `CardTheme` in
/// Step 2) with an optional thin left accent bar whose color carries
/// meaning — blue for info, green for money in, red for overdue/out, amber
/// for low stock. This exact treatment is reused on every screen.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.accentColor,
    this.onTap,
    this.title,
    this.trailing,
  });

  final Widget child;
  final Color? accentColor;
  final VoidCallback? onTap;
  final String? title;

  /// An optional control in the header row, next to [title] — e.g. a
  /// chart's legend, or a "See all" link. Ignored if [title] is null.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final body = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title!, style: theme.textTheme.titleSmall),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );

    // A Stack overlay, not a Row + IntrinsicHeight: IntrinsicHeight needs
    // to probe the content's intrinsic height, which throws if that
    // content contains a LayoutBuilder anywhere in its subtree (several
    // feature screens nest a responsive LayoutBuilder-based section
    // directly inside an AppCard). Positioned stretches to the Stack's
    // resolved height without ever querying the body for one.
    final content = accentColor == null
        ? body
        : Stack(
            children: [
              body,
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(color: accentColor),
              ),
            ],
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
