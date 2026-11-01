import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';
import '../../../organizations/data/models/business_header.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../data/models/sale.dart';
import '../../data/providers/sales_providers.dart';
import '../widgets/receipt_pdf.dart';
import '../widgets/sale_payment_status_color.dart';
import '../widgets/void_sale_dialog.dart';

/// A sale's receipt — shown right after recording it, or when tapping a
/// past sale from the list (as a modal). Looks itself up by [saleId]
/// from the live provider, rather than taking a [Sale] object directly,
/// so a void shows up immediately once its dialog closes instead of
/// leaving this screen stale — same pattern as the production run and
/// staff detail screens. "Print" opens the OS/browser print dialog,
/// which lists every printer the device already knows about — USB,
/// AirPrint, or a WiFi printer added at the OS level — rather than this
/// app needing to speak to one directly. "Share" hands the same PDF to
/// whatever's available (WhatsApp, email, Files).
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleProvider(saleId));

    return saleAsync.when(
      data: (sale) => _ReceiptBody(sale: sale),
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: AppErrorState(
          message:
              "Couldn't load this receipt. Check your connection and try again.",
          onRetry: () => ref.invalidate(saleProvider(saleId)),
        ),
      ),
    );
  }
}

class _ReceiptBody extends ConsumerStatefulWidget {
  const _ReceiptBody({required this.sale});

  final Sale sale;

  @override
  ConsumerState<_ReceiptBody> createState() => _ReceiptBodyState();
}

class _ReceiptBodyState extends ConsumerState<_ReceiptBody> {
  Sale get sale => widget.sale;

  /// Receipts carry the organization's own logo, name and profile.
  Future<BusinessHeader> get _header => ref.read(businessHeaderProvider.future);

  bool _isPrinting = false;
  bool _isSharing = false;

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      final doc = await buildReceiptPdf(sale, header: await _header);
      await Printing.layoutPdf(onLayout: (format) => doc.save());
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final doc = await buildReceiptPdf(sale, header: await _header);
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename:
            'hydrotrack-receipt-${sale.dateTime.toIso8601String().split('T').first}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = ref.watch(authStateProvider)?.role;
    final canVoid = (role?.isAdminLevel ?? false) && !sale.isVoided;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          if (canVoid)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Void sale',
              onPressed: () => showVoidSaleDialog(context, sale),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (sale.isVoided) ...[
            AppCard(
              accentColor: AppColors.moneyOut,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cancel_outlined, color: AppColors.moneyOut),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voided',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.moneyOut,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (sale.voidReason != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            sale.voidReason!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${sale.voidedBy ?? 'Unknown'} · '
                          '${DateFormat.yMMMd().add_jm().format(sale.voidedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.watch(currentOrganizationProvider)?.name ?? '',
                  style: theme.textTheme.titleLarge,
                ),
                for (final line
                    in ref
                            .watch(currentOrganizationProvider)
                            ?.profile
                            .headerLines ??
                        const <String>[])
                  Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DateFormat.yMMMd().add_jm().format(sale.dateTime),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  sale.customerName ?? 'Walk-in customer',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                for (final line in sale.lines) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${line.product.label} × ${line.quantity}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        formatNaira(line.lineTotal),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                _ReceiptRow(
                  label: 'Total',
                  value: formatNaira(sale.total),
                  emphasize: true,
                ),
                _ReceiptRow(label: 'Paid', value: formatNaira(sale.amountPaid)),
                _ReceiptRow(
                  label: 'Balance',
                  value: formatNaira(sale.balance),
                  // A zero balance (paid) stays neutral here — green is for
                  // amounts that actually came in, not an absence of one.
                  valueColor: sale.balance > 0
                      ? sale.paymentStatus.color
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Served by ${sale.recordedBy}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Print',
                  leadingIcon: Icons.print_outlined,
                  isLoading: _isPrinting,
                  onPressed: _isPrinting ? null : _print,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Share',
                  variant: AppButtonVariant.secondary,
                  leadingIcon: Icons.share_outlined,
                  isLoading: _isSharing,
                  onPressed: _isSharing ? null : _share,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleMedium?.copyWith(color: valueColor)
        : theme.textTheme.bodyMedium?.copyWith(color: valueColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: style?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
