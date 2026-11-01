import 'package:flutter/material.dart';

import 'app_empty_state.dart';
import 'app_nav_section.dart';

/// Placeholder for a section that hasn't been built yet. The navigation
/// shell falls back to this for every destination besides the ones it's
/// told about via `pageBuilder`.
class AppComingSoonPage extends StatelessWidget {
  const AppComingSoonPage({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(section.label)),
      body: AppEmptyState(
        icon: section.icon,
        title: section.label,
        message: '${section.label} comes in a later step.',
      ),
    );
  }
}
