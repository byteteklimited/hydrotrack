import 'package:flutter/material.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Asks for a checklist item's name; returns it, or null if cancelled.
Future<String?> showChecklistItemDialog(
  BuildContext context, {
  String? initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ChecklistItemDialog(initial: initial),
  );
}

class _ChecklistItemDialog extends StatefulWidget {
  const _ChecklistItemDialog({this.initial});

  final String? initial;

  @override
  State<_ChecklistItemDialog> createState() => _ChecklistItemDialogState();
}

class _ChecklistItemDialogState extends State<_ChecklistItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Add checklist item' : 'Rename item',
      ),
      content: Form(
        key: _formKey,
        child: AppTextField(
          label: 'What should be checked, e.g. "Bottles rinsed"',
          controller: _name,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter what to check' : null,
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(label: 'Save', onPressed: _done),
      ],
    );
  }
}
