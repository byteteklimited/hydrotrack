import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/quality_providers.dart';
import '../widgets/batch_trace_view.dart';

/// Type the batch number from a bag or receipt to see every customer and
/// trip that got bags from it (Owner, Admin, Manager).
class TraceBatchScreen extends ConsumerStatefulWidget {
  const TraceBatchScreen({super.key});

  @override
  ConsumerState<TraceBatchScreen> createState() => _TraceBatchScreenState();
}

class _TraceBatchScreenState extends ConsumerState<TraceBatchScreen> {
  static const _maxContentWidth = 720.0;

  final _number = TextEditingController();
  String? _searched;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _trace() {
    final number = _number.text.trim();
    if (number.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searched = number);
  }

  @override
  Widget build(BuildContext context) {
    final searched = _searched;
    return Scaffold(
      appBar: AppBar(title: const Text('Trace a batch')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ResponsiveCenter(
            maxWidth: _maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  hint: 'e.g. 261101-M-1',
                  label: 'Batch number',
                  controller: _number,
                  helperText:
                      'Printed on receipts and shown on each '
                      'production run',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Trace batch',
                  leadingIcon: Icons.manage_search,
                  onPressed: _trace,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (searched != null)
                  ref
                      .watch(batchTraceProvider(searched))
                      .when(
                        loading: () =>
                            const AppLoading(message: 'Tracing the batch…'),
                        error: (error, stackTrace) => AppErrorState(
                          message:
                              readableErrorMessage(error) ??
                              "Couldn't trace the batch. Check your "
                                  'connection and try again.',
                          onRetry: () =>
                              ref.invalidate(batchTraceProvider(searched)),
                        ),
                        data: (trace) => BatchTraceView(trace: trace),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
