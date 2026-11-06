import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/bank_account.dart';

/// HydroTrack's bank account, with a copy button on the account number.
class BankAccountDetails extends StatelessWidget {
  const BankAccountDetails({super.key, required this.account});

  final BankAccount account;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: account.accountNumber));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account number copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(label: 'Bank', value: account.bankName),
        _Row(
          label: 'Account number',
          value: account.accountNumber,
          trailing: IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy account number',
            onPressed: () => _copy(context),
          ),
        ),
        _Row(label: 'Account name', value: account.accountName),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  static const _labelWidth = 130.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
