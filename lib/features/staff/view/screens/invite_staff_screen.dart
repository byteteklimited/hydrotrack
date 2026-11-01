import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../../organizations/data/models/invitation.dart';
import '../../data/models/staff_member.dart';
import '../../data/providers/staff_providers.dart';

/// Invites someone to this organization: their name, the phone number
/// they'll sign in with, and their role. Issues a single-use code; they
/// join with it and choose their own PIN. Pops with the [Invitation] so
/// the roster can show the code to pass on.
class InviteStaffScreen extends ConsumerStatefulWidget {
  const InviteStaffScreen({super.key});

  /// Owners are made by promoting an existing member, never by invite.
  static final invitableRoles = StaffRole.values
      .where((role) => role != StaffRole.owner)
      .toList();

  @override
  ConsumerState<InviteStaffScreen> createState() => _InviteStaffScreenState();
}

class _InviteStaffScreenState extends ConsumerState<InviteStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  StaffRole _role = StaffRole.cashier;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final invitation = await ref
        .read(staffActionControllerProvider.notifier)
        .inviteStaff(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _role,
        );
    if (!mounted) return;

    if (invitation == null) {
      final error = ref.read(staffActionControllerProvider).error;
      showActionErrorSnackBar(context, message: readableErrorMessage(error));
      return;
    }
    Navigator.of(context).pop(invitation);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(staffActionControllerProvider).isLoading;

    final fields = [
      AppTextField(
        label: 'Full name',
        controller: _nameController,
        validator: (value) =>
            Validators.required(value, "Enter the staff member's name"),
      ),
      AppTextField(
        label: 'Phone number',
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        helperText: "They'll sign in with this number",
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(Validators.phoneLength),
        ],
        validator: Validators.phone,
      ),
      AppDropdownField<StaffRole>(
        label: 'Role',
        value: _role,
        items: InviteStaffScreen.invitableRoles,
        itemLabel: (role) => role.label,
        onChanged: (role) => setState(() => _role = role!),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Invite staff')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                ResponsiveCenter(
                  maxWidth: 680,
                  child: Column(
                    children: [
                      AppFormGrid(fields: fields),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Create invite code',
                        isLoading: isSaving,
                        expanded: true,
                        onPressed: isSaving ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
