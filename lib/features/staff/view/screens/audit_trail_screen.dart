import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/providers/staff_providers.dart';
import '../widgets/audit_trail_section.dart';

/// Same reasoning as every other list screen in the app: content reads
/// best at a bounded width, implemented as responsive padding so
/// `RefreshIndicator`/`ListView` keep their native scroll behavior.
const double _contentCap = 900;

/// "Who did what, and when" — every recorded action across the app,
/// most recent first.
class AuditTrailScreen extends ConsumerWidget {
  const AuditTrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditTrailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit trail')),
      body: auditAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const AppEmptyState(
              icon: Icons.history,
              title: 'Nothing recorded yet',
              message: 'Actions staff take across the app will show up here.',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > _contentCap
                  ? (constraints.maxWidth - _contentCap) / 2
                  : AppSpacing.lg;

              return RefreshIndicator(
                onRefresh: () => ref.refresh(auditTrailProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: AppSpacing.lg,
                  ),
                  children: [
                    AppCard(child: AuditTrailSection(entries: entries)),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const AppLoading(message: 'Loading audit trail…'),
        error: (error, stackTrace) => AppErrorState(
          message:
              "Couldn't load the audit trail. Check your connection and try again.",
          onRetry: () => ref.invalidate(auditTrailProvider),
        ),
      ),
    );
  }
}
