import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_optional_date_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/permit.dart';
import '../../data/providers/quality_providers.dart';

/// Adds a permit, or edits / removes [permit].
class PermitFormScreen extends ConsumerStatefulWidget {
  const PermitFormScreen({super.key, this.permit});

  final Permit? permit;

  @override
  ConsumerState<PermitFormScreen> createState() => _PermitFormScreenState();
}

class _PermitFormScreenState extends ConsumerState<PermitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.permit?.name);
  late final _number = TextEditingController(text: widget.permit?.number);
  late final _note = TextEditingController(text: widget.permit?.note);
  late DateTime? _expiresOn = widget.permit?.expiresOn;
  bool _missingDate = false;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _note.dispose();
    super.dispose();
  }

  static String? _text(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  QualityActionController get _controller =>
      ref.read(qualityActionControllerProvider.notifier);

  Future<void> _finish(Future<bool> action) async {
    final done = await action;
    if (!mounted) return;
    if (!done) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(qualityActionControllerProvider).error,
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  void _save() {
    final valid = _formKey.currentState?.validate() ?? false;
    setState(() => _missingDate = _expiresOn == null);
    if (!valid || _expiresOn == null) return;
    _finish(
      _controller.savePermit(
        Permit(
          id: widget.permit?.id ?? '',
          name: _name.text.trim(),
          number: _text(_number),
          expiresOn: _expiresOn!,
          note: _text(_note),
        ),
        id: widget.permit?.id,
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${widget.permit!.name}?',
      message: 'Its reminders stop. This cannot be undone.',
      confirmLabel: 'Remove',
    );
    if (confirmed) _finish(_controller.deletePermit(widget.permit!.id));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(qualityActionControllerProvider).isLoading;
    final editing = widget.permit != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit permit' : 'Add permit'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove permit',
              onPressed: busy ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppTextField(
              label: 'Name, e.g. NAFDAC licence',
              controller: _name,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the permit name' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Number (optional)', controller: _number),
            const SizedBox(height: AppSpacing.md),
            AppOptionalDateField(
              label: 'Expires on',
              value: _expiresOn,
              lastDate: DateTime(DateTime.now().year + 10),
              onChanged: (date) => setState(() => _expiresOn = date),
            ),
            if (_missingDate && _expiresOn == null)
              Text(
                'Pick the expiry date',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.dangerFg),
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Note (optional)', controller: _note),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: editing ? 'Save permit' : 'Add permit',
              isLoading: busy,
              onPressed: busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
