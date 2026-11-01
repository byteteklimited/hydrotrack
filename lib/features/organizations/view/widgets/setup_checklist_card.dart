import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/setup_checklist.dart';
import '../../data/providers/organization_providers.dart';
import '../screens/organization_settings_screen.dart';

/// Home, for the owner: what's left to set up, until it's all done or
/// dismissed.
class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    final dismissed = ref.watch(setupChecklistDismissedProvider);
    if (organization == null || dismissed) return const SizedBox.shrink();
    final checklist = SetupChecklist.forOrganization(organization);
    if (checklist.isComplete) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        title:
            'Finish setting up · ${checklist.doneCount} of '
            '${checklist.steps.length} done',
        trailing: AppButton(
          label: 'Dismiss',
          variant: AppButtonVariant.text,
          onPressed: () => dismissSetupChecklist(ref),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final step in checklist.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      step.isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: step.isDone
                          ? AppColors.moneyIn
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title, style: theme.textTheme.titleSmall),
                          if (!step.isDone)
                            Text(
                              'Still to add: ${step.missing.join(', ')}. '
                              'It prints on receipts, reports and reminders.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Open business profile',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OrganizationSettingsScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
