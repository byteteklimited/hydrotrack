import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_spacing.dart';

/// Lays a form's fields out responsively: one stacked column on phone,
/// a two-column grid pairing fields side by side from the medium
/// breakpoint up. A field left over at the end (odd count) gets a row to
/// itself rather than an awkward half-empty row — used by every "record
/// X" form so the same screen doesn't stay a single long column on
/// tablet/desktop just because nobody revisited it.
class AppFormGrid extends StatelessWidget {
  const AppFormGrid({super.key, required this.fields});

  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = AppBreakpoints.isMediumOrWider(constraints.maxWidth);

        if (!isWide) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i != fields.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < fields.length; i += 2) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields[i]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: i + 1 < fields.length
                        ? fields[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              if (i + 2 < fields.length) const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}
