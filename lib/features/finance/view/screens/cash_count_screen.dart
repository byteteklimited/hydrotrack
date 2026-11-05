import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_stat.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/cash_count.dart';
import '../../data/providers/cash_count_providers.dart';

/// End of shift: what you should be holding, and what you counted.
class CashCountScreen extends ConsumerStatefulWidget {
  const CashCountScreen({super.key});

  @override
  ConsumerState<CashCountScreen> createState() => _CashCountScreenState();
}

class _CashCountScreenState extends ConsumerState<CashCountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _counted = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _counted.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(ExpectedCash expected) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final counted = parseNairaText(_counted.text);
    final saved = await ref
        .read(cashCountControllerProvider.notifier)
        .record(counted: counted, note: _note.text.trim());
    if (!saved || !mounted) return;
    final difference = counted - expected.expected;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          difference == 0
              ? 'Count saved: it matches.'
              : difference < 0
              ? 'Count saved: short by ${formatNaira(-difference)}. The owner '
                    'will see your note.'
              : 'Count saved: over by ${formatNaira(difference)}.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final expectedAsync = ref.watch(myExpectedCashProvider);
    final state = ref.watch(cashCountControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Count your cash')),
      body: expectedAsync.when(
        loading: () => const AppLoading(message: 'Working out your cash…'),
        error: (error, stackTrace) => AppErrorState(
          message:
              "Couldn't work out your cash. Check your connection and try again.",
          onRetry: () => ref.invalidate(myExpectedCashProvider),
        ),
        data: (expected) {
          final counted = parseNairaText(_counted.text);
          final mismatch =
              _counted.text.isNotEmpty && counted != expected.expected;
          final error = state.hasError
              ? readableErrorMessage(state.error)
              : null;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ResponsiveCenter(
              maxWidth: 560,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      title:
                          'Since ${DateFormat.jm().format(expected.since.toLocal())}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash you took in: ${formatNaira(expected.cashIn)}',
                          ),
                          Text(
                            'Cash you paid out: ${formatNaira(expected.cashOut)}',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppStat(
                            label: 'You should have',
                            value: formatNaira(expected.expected),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField.naira(
                      hint: 'e.g. 45,000',
                      label: 'Cash you counted',
                      controller: _counted,
                      validator: (v) =>
                          Validators.required(v, 'Enter the cash you counted'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      hint: 'e.g. Gave ₦2,000 change to a customer',
                      label: mismatch
                          ? 'What happened? (required)'
                          : 'Note (optional)',
                      controller: _note,
                      validator: (v) => mismatch
                          ? Validators.required(
                              v,
                              "Explain why it doesn't match",
                            )
                          : null,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppInlineAlert(message: error),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Save count',
                      isLoading: state.isLoading,
                      expanded: true,
                      onPressed: state.isLoading ? null : () => _save(expected),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
