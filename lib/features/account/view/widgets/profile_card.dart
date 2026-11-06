import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/data/models/staff_user.dart';
import '../../../auth/data/providers/auth_providers.dart';

/// The person's name (editable) and what they sign in with.
class ProfileCard extends ConsumerStatefulWidget {
  const ProfileCard({super.key, required this.user, required this.signInWith});

  final StaffUser user;

  /// The phone number or email they sign in with.
  final String signInWith;

  @override
  ConsumerState<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<ProfileCard> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await ref
        .read(accountControllerProvider.notifier)
        .saveName(_name.text.trim());
    if (!mounted) return;
    if (!saved) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(accountControllerProvider).error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Name saved')));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(accountControllerProvider).isLoading;
    final theme = Theme.of(context);
    return AppCard(
      title: 'Your profile',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              hint: 'e.g. Aisha Bello',
              label: 'Full name',
              controller: _name,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You sign in with ${widget.signInWith} · ${widget.user.role.label}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Save name',
              isLoading: busy,
              onPressed: busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
