import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../organizations/data/providers/organization_providers.dart';
import '../../data/models/payroll.dart';
import 'payroll_dialogs.dart';
import 'payslip_pdf.dart';

/// One person's pay: how it was worked out, and Adjust (draft) or
/// Payslip (paid).
class PayrollLineTile extends ConsumerWidget {
  const PayrollLineTile({super.key, required this.line, required this.payroll});

  final PayrollLine line;
  final Payroll payroll;

  Future<void> _sharePayslip(WidgetRef ref) async {
    final doc = await buildPayslipPdf(
      line,
      payroll,
      header: await ref.read(businessHeaderProvider.future),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'payslip-${line.workerName.replaceAll(' ', '-').toLowerCase()}-'
          '${payroll.month.toIso8601String().substring(0, 7)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        title: line.workerName,
        accentColor: line.net < 0 ? AppColors.dangerFg : null,
        trailing: Text(
          formatNaira(line.net),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in payslipRows(line))
              Text('${row.$1}: ${row.$2}', style: secondary),
            Align(
              alignment: Alignment.centerRight,
              child: payroll.isPaid
                  ? TextButton.icon(
                      onPressed: () => _sharePayslip(ref),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Payslip'),
                    )
                  : TextButton(
                      onPressed: () => showAdjustLineDialog(context, line),
                      child: const Text('Adjust'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
