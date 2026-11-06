import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/admin_plans_card.dart';
import '../widgets/platform_settings_form.dart';

/// HydroTrack's plans (prices and limits), trial and grace length, and
/// the bank account owners pay into.
class PlatformSettingsScreen extends ConsumerWidget {
  const PlatformSettingsScreen({super.key});

  static const _maxContentWidth = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(platformSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Plans and payment')),
      body: settingsAsync.when(
        loading: () => const AppLoading(),
        error: (error, stackTrace) => AppErrorState(
          message:
              readableErrorMessage(error) ??
              "Couldn't load the settings. Check your connection and try "
                  'again.',
          onRetry: () => ref.invalidate(platformSettingsProvider),
        ),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ResponsiveCenter(
              maxWidth: _maxContentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AdminPlansCard(),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    title: 'Trial, grace and payment',
                    child: PlatformSettingsForm(settings: settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
