import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Lays [AppStatTile]s out in as many equal columns as fit, each column
/// at most [maxTileWidth] wide. Tiles keep their natural height (no fixed
/// row height), so larger text or a fallback font can't make them
/// overflow.
class AppStatTileGrid extends StatelessWidget {
  const AppStatTileGrid({
    super.key,
    required this.tiles,
    required this.maxTileWidth,
  });

  final List<Widget> tiles;
  final double maxTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final columns = ((constraints.maxWidth + gap) / (maxTileWidth + gap))
            .ceil()
            .clamp(1, tiles.length);
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}
