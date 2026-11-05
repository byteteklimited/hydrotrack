import 'package:flutter/material.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Asks what to call this device (e.g. "Front desk phone"), so admins can
/// tell devices apart and switch off the right one if it's lost.
Future<String?> showDeviceNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _DeviceNameDialog(),
  );
}

class _DeviceNameDialog extends StatefulWidget {
  const _DeviceNameDialog();

  @override
  State<_DeviceNameDialog> createState() => _DeviceNameDialogState();
}

class _DeviceNameDialogState extends State<_DeviceNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set up this device'),
      content: Form(
        key: _formKey,
        child: AppTextField(
          hint: 'e.g. Front desk phone',
          label: 'Device name',
          controller: _name,
          helperText: 'e.g. Front desk phone, Depot tablet',
          validator: (value) =>
              Validators.required(value, 'Give this device a name'),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Set up and download', onPressed: _submit),
      ],
    );
  }
}
