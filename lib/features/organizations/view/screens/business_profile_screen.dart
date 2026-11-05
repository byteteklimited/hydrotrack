import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_inline_alert.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/business_profile.dart';
import '../../data/models/organization.dart';
import '../../data/providers/organization_providers.dart';

/// Edits the business name and profile (address, phone, email, CAC/RC and
/// NAFDAC numbers). Everything but the name is optional.
class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key, required this.organization});

  final Organization organization;

  @override
  ConsumerState<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final BusinessProfile _profile = widget.organization.profile;
  late final _name = TextEditingController(text: widget.organization.name);
  late final _address = TextEditingController(text: _profile.address);
  late final _phone = TextEditingController(text: _profile.phone);
  late final _email = TextEditingController(text: _profile.email);
  late final _rc = TextEditingController(text: _profile.rcNumber);
  late final _nafdac = TextEditingController(text: _profile.nafdacNumber);

  List<TextEditingController> get _controllers => [
    _name,
    _address,
    _phone,
    _email,
    _rc,
    _nafdac,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  static String? _optional(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await ref
        .read(organizationActionControllerProvider.notifier)
        .saveProfile(
          organizationId: widget.organization.id,
          name: _name.text.trim(),
          profile: BusinessProfile(
            address: _optional(_address),
            phone: _optional(_phone),
            email: _optional(_email)?.toLowerCase(),
            rcNumber: _optional(_rc),
            nafdacNumber: _optional(_nafdac),
          ),
        );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Business profile saved.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(organizationActionControllerProvider);
    final error = state.hasError
        ? readableErrorMessage(state.error) ??
              "Couldn't save. Check your connection and try again."
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Business profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ResponsiveCenter(
          maxWidth: 680,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFormGrid(
                  fields: [
                    AppTextField(
                      hint: 'e.g. Sunny Water',
                      label: 'Business name',
                      controller: _name,
                      validator: (v) =>
                          Validators.required(v, 'Enter your business name'),
                    ),
                    AppTextField(
                      hint: 'e.g. 08031234567',
                      label: 'Phone (optional)',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? null : Validators.phone(v),
                    ),
                    AppTextField(
                      hint: 'e.g. 12 Zoo Road, Kano',
                      label: 'Address (optional)',
                      controller: _address,
                    ),
                    AppTextField(
                      hint: 'e.g. hello@sunnywater.ng',
                      label: 'Email (optional)',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? null : Validators.email(v),
                    ),
                    AppTextField(
                      hint: 'e.g. RC 1234567',
                      label: 'CAC / RC number (optional)',
                      controller: _rc,
                    ),
                    AppTextField(
                      hint: 'e.g. A1-1234',
                      label: 'NAFDAC number (optional)',
                      controller: _nafdac,
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppInlineAlert(message: error),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save profile',
                  isLoading: state.isLoading,
                  expanded: true,
                  onPressed: state.isLoading ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
