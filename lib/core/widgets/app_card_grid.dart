import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_spacing.dart';

/// Lays a handful of cards/sections out responsively: one column on
/// phone, two from the medium breakpoint up, three from expanded — for
/// a screen with enough cards that a single stacked column wastes a
/// wide window's width (Reports is the first: six cards, previously one
/// long column regardless of how wide the window got). Cards keep their
/// own natural height — `CrossAxisAlignment.start`, no forced stretch —
/// so a short card and a long one can sit side by side without the row
/// growing to match the taller one.
class AppCardGrid extends StatelessWidget {
  const AppCardGrid({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppBreakpoints.isExpanded(constraints.maxWidth)
            ? 3
            : AppBreakpoints.isMediumOrWider(constraints.maxWidth)
            ? 2
            : 1;

        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i += columns) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = i; j < i + columns; j++) ...[
                    Expanded(
                      child: j < cards.length
                          ? cards[j]
                          : const SizedBox.shrink(),
                    ),
                    if (j != i + columns - 1)
                      const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
              if (i + columns < cards.length)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}
