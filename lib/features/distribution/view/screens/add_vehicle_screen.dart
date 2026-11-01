import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/providers/distribution_providers.dart';

/// Adds a new vehicle, so it can be picked when recording a load-out.
class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(distributionActionControllerProvider.notifier)
        .createVehicle(name: _nameController.text.trim());
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

    return Scaffold(
      appBar: AppBar(title: const Text('Add vehicle')),
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
                      AppTextField(
                        label: 'Name / plate number',
                        controller: _nameController,
                        helperText: 'e.g. "Blue Dyna — ABJ 342 XA"',
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Enter the vehicle name or plate number.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Add vehicle',
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
