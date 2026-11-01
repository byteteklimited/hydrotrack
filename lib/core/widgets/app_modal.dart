import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Presents [builder]'s content as a modal sheet instead of pushing a new
/// route — for drilling into detail from a dashboard card without losing
/// the screen behind it. Full width on phone; centered and capped at a
/// comfortable reading width on tablet/desktop, where a full-bleed sheet
/// would otherwise stretch edge to edge.
///
/// The content can be a full `Scaffold` (its own `AppBar` back button
/// closes the sheet automatically, same as it would pop a pushed route)
/// — nothing needs to change about a screen to show it this way.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxWidth: 720,
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: builder,
  );
}
