import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/location_providers.dart';
import '../widgets/location_form_dialog.dart';
import 'location_detail_screen.dart';

/// Owners/admins: the organization's factories and depots.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  static const _maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(allLocationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Locations')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: 'Add location',
                  leadingIcon: Icons.add_location_alt_outlined,
                  onPressed: () => showLocationFormDialog(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                locationsAsync.when(
                  loading: () => const AppLoading(),
                  error: (error, stackTrace) => AppErrorState(
                    message:
                        readableErrorMessage(error) ??
                        "Couldn't load locations. Check your connection.",
                    onRetry: () => ref.invalidate(allLocationsProvider),
                  ),
                  data: (locations) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final location in locations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            title: location.name,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    LocationDetailScreen(location: location),
                              ),
                            ),
                            child: Text(
                              [
                                location.kind.label,
                                if (location.isMain) 'Main',
                                if (!location.isActive) 'Closed',
                              ].join(' · '),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
