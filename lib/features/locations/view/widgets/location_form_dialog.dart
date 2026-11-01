import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/location.dart';
import '../../data/providers/location_providers.dart';

/// Adds a location, or renames / changes the kind of [location].
Future<void> showLocationFormDialog(
  BuildContext context, {
  Location? location,
}) => showDialog<void>(
  context: context,
  builder: (_) => _LocationFormDialog(location: location),
);

class _LocationFormDialog extends ConsumerStatefulWidget {
  const _LocationFormDialog({this.location});

  final Location? location;

  @override
  ConsumerState<_LocationFormDialog> createState() =>
      _LocationFormDialogState();
}

class _LocationFormDialogState extends ConsumerState<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.location?.name);
  late LocationKind _kind = widget.location?.kind ?? LocationKind.depot;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFormDialog(
    formKey: _formKey,
    busy: ref.watch(locationsActionControllerProvider).isLoading,
    error: () => ref.read(locationsActionControllerProvider).error,
    title: widget.location == null ? 'Add location' : 'Edit location',
    intro: widget.location == null
        ? 'A factory makes and sells; a depot holds and sells stock sent '
              'to it. Its stock, sales, cash and customers are kept apart.'
        : null,
    submitLabel: 'Save location',
    onSubmit: () => ref
        .read(locationsActionControllerProvider.notifier)
        .saveLocation(
          name: _name.text.trim(),
          kind: _kind,
          id: widget.location?.id,
        ),
    fields: [
      AppTextField(
        label: 'Name, e.g. "Kano depot"',
        controller: _name,
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
      ),
      AppDropdownField<LocationKind>(
        label: 'Kind',
        value: _kind,
        items: LocationKind.values,
        itemLabel: (kind) => kind.label,
        onChanged: (kind) => setState(() => _kind = kind!),
      ),
    ],
  );
}
