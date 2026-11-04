import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/location.dart';
import '../../data/providers/location_providers.dart';
import '../../../../core/theme/brand_palette.dart';

/// Which location the app is working in, and a menu to switch when the
/// person may work at more than one. Hidden otherwise.
class LocationSwitcher extends ConsumerWidget {
  const LocationSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(locationOptionsProvider).valueOrNull;
    final current = ref.watch(currentLocationProvider);
    if (options == null || current == null || options.allowed.length < 2) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<Location>(
        tooltip: 'Switch location',
        onSelected: (location) => chooseLocation(ref, location),
        itemBuilder: (_) => [
          for (final location in options.allowed)
            CheckedPopupMenuItem(
              value: location,
              checked: location == current,
              child: Text('${location.name} · ${location.kind.label}'),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.place_outlined,
              size: 18,
              color: context.brand.primaryText,
            ),
            const SizedBox(width: 4),
            Text(current.name, style: theme.textTheme.titleSmall),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
