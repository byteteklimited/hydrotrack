import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../staff/data/models/staff_member.dart';
import '../../../staff/data/providers/staff_providers.dart';
import '../../data/models/location.dart';
import '../../data/providers/location_providers.dart';
import '../widgets/location_form_dialog.dart';

/// One location: edit or close it, and choose who works there. Owners and
/// admins work everywhere, so only other staff are listed.
class LocationDetailScreen extends ConsumerWidget {
  const LocationDetailScreen({super.key, required this.location});

  final Location location;

  static const _maxContentWidth = 720.0;

  Future<void> _setActive(BuildContext context, WidgetRef ref) async {
    final done = await ref
        .read(locationsActionControllerProvider.notifier)
        .saveLocation(
          name: location.name,
          kind: location.kind,
          id: location.id,
          isActive: !location.isActive,
        );
    if (!context.mounted) return;
    if (!done) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(locationsActionControllerProvider).error,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(location.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () =>
                showLocationFormDialog(context, location: location),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StaffCard(location: location),
                if (!location.isMain) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: location.isActive
                        ? 'Close this location'
                        : 'Open it again',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _setActive(context, ref),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends ConsumerStatefulWidget {
  const _StaffCard({required this.location});

  final Location location;

  @override
  ConsumerState<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends ConsumerState<_StaffCard> {
  Set<String>? _chosen;

  Future<void> _save() async {
    final done = await ref
        .read(locationsActionControllerProvider.notifier)
        .setAssignments(widget.location.id, _chosen!);
    if (!mounted) return;
    if (!done) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(locationsActionControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Staff saved')));
  }

  @override
  Widget build(BuildContext context) {
    final staff = [
      for (final member
          in ref.watch(staffProvider).valueOrNull ?? const <StaffMember>[])
        if (member.isActive && !member.role.isAdminLevel) member,
    ];
    final assignments = ref.watch(locationAssignmentsProvider).valueOrNull;
    if (assignments == null) return const AppCard(child: AppLoading());
    final chosen = _chosen ??= {
      for (final entry in assignments.entries)
        if (entry.value.contains(widget.location.id)) entry.key,
    };
    final busy = ref.watch(locationsActionControllerProvider).isLoading;
    return AppCard(
      title: 'Who works here',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (staff.isEmpty)
            const Text(
              'No staff yet. Owners and admins work at every location.',
            ),
          for (final member in staff)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: chosen.contains(member.id),
              title: Text(member.fullName),
              subtitle: Text(member.role.label),
              onChanged: (on) => setState(
                () => on! ? chosen.add(member.id) : chosen.remove(member.id),
              ),
            ),
          if (staff.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Save staff',
              isLoading: busy,
              onPressed: busy ? null : _save,
            ),
          ],
        ],
      ),
    );
  }
}
