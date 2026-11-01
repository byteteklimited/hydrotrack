import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/sanitation.dart';
import '../../data/providers/quality_providers.dart';
import 'checklist_item_dialog.dart';

/// The organization's own checklist: add, rename, stop or restart items.
/// Stopped items stay in past days' records.
class ChecklistItemsCard extends ConsumerWidget {
  const ChecklistItemsCard({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(QualityActionController controller) action,
  ) async {
    final done = await action(
      ref.read(qualityActionControllerProvider.notifier),
    );
    if (!done && context.mounted) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(qualityActionControllerProvider).error,
        ),
      );
    }
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<SanitationItem> items,
  ) async {
    final name = await showChecklistItemDialog(context);
    if (name == null || !context.mounted) return;
    final next = items.isEmpty ? 1 : items.last.position + 1;
    await _run(context, ref, (c) => c.addSanitationItem(name, next));
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SanitationItem item,
  ) async {
    final name = await showChecklistItemDialog(context, initial: item.name);
    if (name == null || !context.mounted) return;
    await _run(
      context,
      ref,
      (c) => c.updateSanitationItem(item.id, name: name),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(sanitationItemsProvider);
    final items = itemsAsync.valueOrNull;
    return AppCard(
      title: 'Sanitation checklist',
      child: items == null
          ? itemsAsync.hasError
                ? Text(
                    readableErrorMessage(itemsAsync.error) ??
                        "Couldn't load the checklist. Check your connection.",
                  )
                : const AppLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.name,
                      style: item.isActive
                          ? null
                          : const TextStyle(color: AppColors.textTertiary),
                    ),
                    subtitle: item.isActive ? null : const Text('Stopped'),
                    onTap: () => _rename(context, ref, item),
                    trailing: TextButton(
                      onPressed: () => _run(
                        context,
                        ref,
                        (c) => c.updateSanitationItem(
                          item.id,
                          isActive: !item.isActive,
                        ),
                      ),
                      child: Text(item.isActive ? 'Stop' : 'Restart'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Add item',
                  variant: AppButtonVariant.secondary,
                  leadingIcon: Icons.add,
                  onPressed: () => _add(context, ref, items),
                ),
              ],
            ),
    );
  }
}
