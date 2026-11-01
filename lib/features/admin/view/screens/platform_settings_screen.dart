import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/platform_settings_form.dart';

/// The one HydroTrack plan: monthly price, trial and grace length, and how
/// owners pay.
class PlatformSettingsScreen extends ConsumerWidget {
  const PlatformSettingsScreen({super.key});

  static const _maxContentWidth = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(platformSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plan and price')),
      body: settingsAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => AppErrorState(
          message:
              readableErrorMessage(error) ??
              "Couldn't load the plan. Check your connection and try again.",
          onRetry: () => ref.invalidate(platformSettingsProvider),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ResponsiveCenter(
              maxWidth: _maxContentWidth,
              child: PlatformSettingsForm(settings: settings),
            ),
          ],
        ),
      ),
    );
  }
}
