import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../data/models/permit.dart';
import '../../data/providers/quality_providers.dart';
import '../screens/permit_form_screen.dart';
import 'permit_tile.dart';
import 'quality_tab_list.dart';

/// Licences and permits, soonest to expire first. Owners and admins add
/// and edit them; the owner is reminded before each expires.
class PermitsTab extends ConsumerWidget {
  const PermitsTab({super.key});

  void _openForm(BuildContext context, {Permit? permit}) => showAppModal<void>(
    context,
    builder: (_) => PermitFormScreen(permit: permit),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permitsAsync = ref.watch(permitsProvider);
    final canEdit = ref.watch(authStateProvider)?.role.isAdminLevel ?? false;

    return QualityTabList(
      onRefresh: () => ref.refresh(permitsProvider.future),
      children: [
        if (canEdit) ...[
          AppButton(
            label: 'Add permit',
            leadingIcon: Icons.add,
            onPressed: () => _openForm(context),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        permitsAsync.when(
          loading: () => const AppLoading(message: 'Loading permits…'),
          error: (error, stackTrace) => AppErrorState(
            message:
                readableErrorMessage(error) ??
                "Couldn't load permits. Check your connection and try again.",
            onRetry: () => ref.invalidate(permitsProvider),
          ),
          data: (permits) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (permits.isEmpty)
                Text(
                  canEdit
                      ? 'No permits yet. Add your NAFDAC licence and any others '
                            '(SON, water board, fire service) to be reminded 60, '
                            '30 and 7 days before each expires.'
                      : 'No permits recorded yet.',
                ),
              for (final permit in permits)
                PermitTile(
                  permit: permit,
                  onTap: canEdit
                      ? () => _openForm(context, permit: permit)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
