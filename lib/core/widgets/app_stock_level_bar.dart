import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/brand_palette.dart';

/// A thin neutral track with a cyan fill showing quantity-on-hand
/// against some reference ceiling, plus a small tick marking the reorder
/// point. Deliberately never colored by stock status (out/low/healthy)
/// — that meaning belongs to a [AppStatusTag]/chip sitting next to it,
/// not the bar itself, so a zero-stock item doesn't double up on "red"
/// (a flat red stub at zero reads as a rendering error, not a real
/// level) while a healthy one doesn't double up on a redundant green.
///
/// Cyan is only safe as a fill at 6px or taller (the brand guide's own
/// condition for using it as a progress indicator, since it has nowhere
/// near the contrast needed to carry meaning on its own at a hairline
/// weight) — the default height here is exactly 6 for that reason, not
/// the thinner 4px an earlier version used.
class AppStockLevelBar extends StatelessWidget {
  const AppStockLevelBar({
    super.key,
    required this.fraction,
    this.reorderFraction,
    this.height = 6,
  });

  /// Current level as a fraction of the bar's ceiling, 0–1. A real
  /// non-zero stock level stays visibly non-zero even when tiny, so the
  /// bar never reads as "no data" — callers should clamp a very small
  /// positive value up to something visible (e.g. 0.04) before passing
  /// it in; an item genuinely at zero should pass exactly 0.
  final double fraction;

  /// Where the reorder point sits, as the same 0–1 fraction — draws a
  /// small tick there. Omitted when there's nothing meaningful to mark
  /// (e.g. no reorder level set).
  final double? reorderFraction;

  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height + 4,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(height / 2),
                child: SizedBox(
                  height: height,
                  width: width,
                  child: Stack(
                    children: [
                      Container(color: AppColors.hoverNeutral),
                      FractionallySizedBox(
                        widthFactor: fraction.clamp(0.0, 1.0),
                        child: Container(color: context.brand.accent),
                      ),
                    ],
                  ),
                ),
              ),
              if (reorderFraction != null)
                Positioned(
                  left: (width * reorderFraction!.clamp(0.0, 1.0) - 1).clamp(
                    0.0,
                    width - 2,
                  ),
                  child: Container(
                    width: 2,
                    height: height + 4,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
