import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/location_providers.dart';
import '../../data/providers/transfer_providers.dart';
import '../widgets/transfer_tile.dart';
import 'send_transfer_screen.dart';

/// Stock moving in and out of the current location: send to another
/// location, receive what's on its way here.
class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  static const _maxContentWidth = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfersAsync = ref.watch(transfersProvider);
    final here = ref.watch(currentLocationProvider)?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('Transfers · $here')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(transfersProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ResponsiveCenter(
              maxWidth: _maxContentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'Send stock',
                    leadingIcon: Icons.north_east,
                    onPressed: () => showAppModal<void>(
                      context,
                      builder: (_) => const SendTransferScreen(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  transfersAsync.when(
                    loading: () => const AppLoading(),
                    error: (error, stackTrace) => AppErrorState(
                      message:
                          readableErrorMessage(error) ??
                          "Couldn't load transfers. Check your connection and "
                              'try again.',
                      onRetry: () => ref.invalidate(transfersProvider),
                    ),
                    data: (transfers) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (transfers.isEmpty)
                          const Text(
                            'No transfers yet. Send stock to another factory '
                            'or depot; it arrives when they receive it.',
                          ),
                        for (final transfer in transfers)
                          TransferTile(transfer: transfer),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
