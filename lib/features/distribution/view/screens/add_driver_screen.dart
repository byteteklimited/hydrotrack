import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/distribution_providers.dart';

/// Adds a new driver, so they can be picked when recording a load-out.
class AddDriverScreen extends ConsumerStatefulWidget {
  const AddDriverScreen({super.key});

  @override
  ConsumerState<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends ConsumerState<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(distributionActionControllerProvider.notifier)
        .createDriver(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
    if (!mounted) return;

    if (ref.read(distributionActionControllerProvider).hasError) {
      showActionErrorSnackBar(context);
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(distributionActionControllerProvider).isLoading;

    final fields = [
      AppTextField(
        hint: 'e.g. Sani Musa',
        label: 'Name',
        controller: _nameController,
        validator: (value) => (value == null || value.trim().isEmpty)
            ? "Enter the driver's name."
            : null,
      ),
      AppTextField(
        hint: 'e.g. 08031234567',
        label: 'Phone number',
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ],
        validator: (value) => (value == null || value.trim().length != 11)
            ? 'Enter a valid 11-digit phone number'
            : null,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Add driver')),
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
                        label: 'Add driver',
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
