import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/worker.dart';
import '../../data/providers/payroll_providers.dart';
import 'pay_tab_list.dart';

/// Each per-bag worker's bags on the chosen day, from the tally sheet.
class BagsTab extends ConsumerWidget {
  const BagsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = [
      for (final worker in ref.watch(activeWorkersProvider))
        if (worker.payType == PayType.perBag) worker,
    ];
    final countsAsync = ref.watch(bagCountsForDayProvider);
    final day = ref.watch(payDayProvider);
    final counts = countsAsync.valueOrNull;

    return PayTabList(
      withDay: true,
      children: [
        if (workers.isEmpty)
          const Text('No workers are paid per bag.')
        else if (counts == null)
          countsAsync.hasError
              ? Text(
                  readableErrorMessage(countsAsync.error) ??
                      "Couldn't load bag counts. Check your connection.",
                )
              : const AppLoading()
        else
          _BagsForm(
            key: ValueKey(day),
            day: day,
            workers: workers,
            counts: {for (final count in counts) count.workerId: count.bags},
          ),
      ],
    );
  }
}

class _BagsForm extends ConsumerStatefulWidget {
  const _BagsForm({
    super.key,
    required this.day,
    required this.workers,
    required this.counts,
  });

  final DateTime day;
  final List<Worker> workers;
  final Map<String, int> counts;

  @override
  ConsumerState<_BagsForm> createState() => _BagsFormState();
}

class _BagsFormState extends ConsumerState<_BagsForm> {
  late final Map<String, TextEditingController> _fields = {
    for (final worker in widget.workers)
      worker.id: TextEditingController(
        text: widget.counts[worker.id]?.toString(),
      ),
  };

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final bags = {
      for (final entry in _fields.entries)
        if (int.tryParse(entry.value.text) != null)
          entry.key: int.parse(entry.value.text),
    };
    if (bags.isEmpty) return;
    final saved = await ref
        .read(payrollActionControllerProvider.notifier)
        .recordBagCounts(widget.day, bags);
    if (!mounted) return;
    if (!saved) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(payrollActionControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bag counts saved')));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(payrollActionControllerProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final worker in widget.workers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppTextField.quantity(
              label: worker.name,
              controller: _fields[worker.id],
              unit: 'bags',
            ),
          ),
        AppButton(
          label: 'Save bag counts',
          isLoading: busy,
          onPressed: busy ? null : _save,
        ),
      ],
    );
  }
}
