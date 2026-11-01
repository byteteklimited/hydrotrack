import 'package:flutter/material.dart';

/// Keeps content from stretching edge-to-edge on tablet/desktop by capping
/// its width and centering it horizontally. Used on every form-first
/// screen (auth, add/record forms) so they read as a deliberate column
/// instead of a full-bleed sheet of fields once the window is wide.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 480});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
