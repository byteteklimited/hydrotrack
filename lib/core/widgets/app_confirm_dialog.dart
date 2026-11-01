import 'package:flutter/material.dart';

import 'app_button.dart';

/// Asks for confirmation before an irreversible action. This is the one
/// place in the app a dialog is the right call — [AppInlineAlert] and
/// [showAppModal] exist precisely because dialogs are otherwise reserved
/// for a genuine decision, not a message. Returns `true` only if the
/// destructive action was confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
