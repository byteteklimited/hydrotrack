import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/models/sanitation.dart';
import '../../data/providers/quality_providers.dart';

/// Tick off today's checklist; items not done can carry a note. Opens
/// with whatever was already ticked today.
class TodayChecklistCard extends ConsumerStatefulWidget {
  const TodayChecklistCard({
    super.key,
    required this.items,
    required this.todaysChecks,
  });

  final List<SanitationItem> items;
  final List<SanitationCheck> todaysChecks;

  @override
  ConsumerState<TodayChecklistCard> createState() => _TodayChecklistCardState();
}

class _TodayChecklistCardState extends ConsumerState<TodayChecklistCard> {
  late final Map<String, bool> _done = {
    for (final item in widget.items)
      item.id: widget.todaysChecks
          .where((check) => check.itemId == item.id)
          .any((check) => check.done),
  };
  late final Map<String, TextEditingController> _notes = {
    for (final item in widget.items)
      item.id: TextEditingController(
        text: widget.todaysChecks
            .where((check) => check.itemId == item.id)
            .map((check) => check.note)
            .firstOrNull,
      ),
  };

  @override
  void dispose() {
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final ticks = [
      for (final item in widget.items)
        SanitationTick(
          itemId: item.id,
          done: _done[item.id] ?? false,
          note: _notes[item.id]!.text.trim().isEmpty
              ? null
              : _notes[item.id]!.text.trim(),
        ),
    ];
    final saved = await ref
        .read(qualityActionControllerProvider.notifier)
        .recordSanitationCheck(DateTime.now(), ticks);
    if (!mounted) return;
    if (!saved) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(qualityActionControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Today's checklist saved")));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const AppCard(
        title: "Today's checklist",
        child: Text(
          'The checklist is empty. An admin can add items under Quality → '
          'settings (top right).',
        ),
      );
    }
    final busy = ref.watch(qualityActionControllerProvider).isLoading;
    return AppCard(
      title: "Today's checklist",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in widget.items) ...[
            CheckboxListTile(
              value: _done[item.id],
              title: Text(item.name),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (done) => setState(() => _done[item.id] = done!),
            ),
            if (!(_done[item.id] ?? false))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TextField(
                  controller: _notes[item.id],
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Why not? (optional)',
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Save checklist',
            isLoading: busy,
            onPressed: busy ? null : _save,
          ),
        ],
      ),
    );
  }
}
