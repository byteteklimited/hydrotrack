import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_status_tag.dart';
import '../../data/providers/offline_providers.dart';

/// "Needs checking" next to a sale or production run that synced from
/// offline with a problem. Nothing otherwise.
class NeedsCheckingTag extends ConsumerWidget {
  const NeedsCheckingTag({super.key, this.saleId, this.productionRunId});

  final String? saleId;
  final String? productionRunId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(openSyncFlagsProvider).valueOrNull ?? const [];
    final flagged = flags.any(
      (flag) =>
          (saleId != null && flag.saleId == saleId) ||
          (productionRunId != null && flag.productionRunId == productionRunId),
    );
    if (!flagged) return const SizedBox.shrink();
    return const AppStatusTag(
      label: 'Needs checking',
      color: AppColors.lowStockWarning,
    );
  }
}
