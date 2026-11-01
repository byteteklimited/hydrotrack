import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../data/models/load_out.dart';
import '../../data/providers/distribution_providers.dart';
import '../widgets/on_road_load_out_card.dart';
import '../widgets/settled_day_section.dart';
import 'driver_returns_screen.dart';
import 'new_load_out_screen.dart';

/// Same reasoning as every other list screen in the app: content reads
/// best at a bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 900;

/// Distribution leads with what's on the road right now, then settled
/// trips grouped by day.
class DistributionScreen extends ConsumerWidget {
  const DistributionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadOutsAsync = ref.watch(loadOutsProvider);
    final driversAsync = ref.watch(driversProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Distribution')),
      floatingActionButton: AppButton(
        label: 'New load-out',
        leadingIcon: Icons.add,
        onPressed: () =>
            showAppModal(context, builder: (_) => const NewLoadOutScreen()),
      ),
      body: Builder(
        builder: (context) {
          if (loadOutsAsync.isLoading ||
              driversAsync.isLoading ||
              vehiclesAsync.isLoading) {
            return const AppLoading(message: 'Loading trips…');
          }
          if (loadOutsAsync.hasError ||
              driversAsync.hasError ||
              vehiclesAsync.hasError) {
            return AppErrorState(
              message:
                  "Couldn't load distribution trips. Check your connection and try again.",
              onRetry: () => ref.invalidate(loadOutsProvider),
            );
          }

          final loadOuts = loadOutsAsync.value!;
          final driversById = {for (final d in driversAsync.value!) d.id: d};
          final vehiclesById = {for (final v in vehiclesAsync.value!) v.id: v};
          final onRoad = loadOuts
              .where((l) => l.status == LoadOutStatus.onRoad)
              .toList();
          final settled = _groupSettledByDay(
            loadOuts.where((l) => l.status == LoadOutStatus.settled),
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > _contentCap
                  ? (constraints.maxWidth - _contentCap) / 2
                  : AppSpacing.lg;

              return RefreshIndicator(
                onRefresh: () => Future.wait([
                  ref.refresh(loadOutsProvider.future),
                  ref.refresh(driversProvider.future),
                  ref.refresh(vehiclesProvider.future),
                ]),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.lg,
                    horizontalPadding,
                    AppSpacing.xxl,
                  ),
                  children: [
                    if (onRoad.isEmpty)
                      const AppEmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'Nothing on the road',
                        message:
                            'No vehicles on the road. Tap + to record a load-out.',
                      )
                    else
                      for (final loadOut in onRoad) ...[
                        OnRoadLoadOutCard(
                          loadOut: loadOut,
                          driver: driversById[loadOut.driverId]!,
                          vehicle: vehiclesById[loadOut.vehicleId]!,
                          onTap: () => showAppModal(
                            context,
                            builder: (_) =>
                                DriverReturnsScreen(loadOut: loadOut),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    if (settled.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      for (final day in settled.keys) ...[
                        SettledDaySection(
                          date: day,
                          loadOuts: settled[day]!,
                          driversById: driversById,
                          vehiclesById: vehiclesById,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<DateTime, List<LoadOut>> _groupSettledByDay(Iterable<LoadOut> loadOuts) {
    final map = <DateTime, List<LoadOut>>{};
    for (final loadOut in loadOuts) {
      map.putIfAbsent(dateOnly(loadOut.dateTime), () => []).add(loadOut);
    }
    final sortedDays = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final day in sortedDays) day: map[day]!};
  }
}
