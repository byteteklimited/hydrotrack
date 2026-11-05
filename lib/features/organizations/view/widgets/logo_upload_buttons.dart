import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/utils/image_picker.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/models/organization.dart';
import '../../data/providers/organization_providers.dart';

/// "Upload logo" / "Change logo" and "Remove logo" for [organization] —
/// used in Branding and the business profile.
class LogoUploadButtons extends ConsumerWidget {
  const LogoUploadButtons({super.key, required this.organization});

  final Organization organization;

  /// Storage accepts these, up to 5 MB.
  static const _logoExtensions = {'png', 'jpg', 'jpeg', 'webp'};
  static const _maxLogoBytes = 5 * 1024 * 1024;

  Future<void> _pickLogo(BuildContext context, WidgetRef ref) async {
    final PickedImage? image;
    try {
      image = await pickImage();
    } catch (_) {
      if (context.mounted) {
        showActionErrorSnackBar(
          context,
          message:
              'Could not open your photos. Allow this site to access files '
              'in your browser settings, then try again.',
        );
      }
      return;
    }
    if (image == null || !context.mounted) return;
    if (!_logoExtensions.contains(image.extension)) {
      showActionErrorSnackBar(
        context,
        message: 'Choose a PNG, JPG or WebP image.',
      );
      return;
    }
    if (image.bytes.length > _maxLogoBytes) {
      showActionErrorSnackBar(
        context,
        message: 'That image is over 5 MB. Choose a smaller one.',
      );
      return;
    }
    final updated = await ref
        .read(organizationActionControllerProvider.notifier)
        .uploadLogo(
          organizationId: organization.id,
          bytes: image.bytes,
          extension: image.extension,
        );
    if (!context.mounted) return;
    _report(context, ref, updated != null ? 'Logo updated.' : null);
  }

  Future<void> _removeLogo(BuildContext context, WidgetRef ref) async {
    final updated = await ref
        .read(organizationActionControllerProvider.notifier)
        .removeLogo(organization.id);
    if (context.mounted) {
      _report(context, ref, updated != null ? 'Logo removed.' : null);
    }
  }

  void _report(BuildContext context, WidgetRef ref, String? success) {
    if (success != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      return;
    }
    showActionErrorSnackBar(
      context,
      message: readableErrorMessage(
        ref.read(organizationActionControllerProvider).error,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(organizationActionControllerProvider).isLoading;
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        AppButton(
          label: organization.logoPath == null ? 'Upload logo' : 'Change logo',
          leadingIcon: Icons.image_outlined,
          variant: AppButtonVariant.secondary,
          isLoading: busy,
          onPressed: () => _pickLogo(context, ref),
        ),
        if (organization.logoPath != null)
          AppButton(
            label: 'Remove logo',
            variant: AppButtonVariant.text,
            onPressed: busy ? null : () => _removeLogo(context, ref),
          ),
      ],
    );
  }
}
