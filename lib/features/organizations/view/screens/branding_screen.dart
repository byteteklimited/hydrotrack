import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/theme/brand_swatches.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/organization.dart';
import '../../data/providers/organization_providers.dart';
import '../widgets/brand_color_picker.dart';
import '../widgets/brand_preview.dart';
import '../widgets/logo_upload_buttons.dart';
import '../widgets/organization_logo.dart';
import 'business_profile_screen.dart';

/// The organization's own brand — name, logo, main and accent colors —
/// which the whole app wears inside it (and receipts and reports carry).
/// With [setup], the first step after creating an organization: "Save
/// and continue" goes on to the business details, "Skip for now" to Home.
class BrandingScreen extends ConsumerStatefulWidget {
  const BrandingScreen({super.key, this.setup = false});

  final bool setup;

  @override
  ConsumerState<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends ConsumerState<BrandingScreen> {
  static const _maxContentWidth = 720.0;

  final _formKey = GlobalKey<FormState>();
  late final Organization _start = ref.read(currentOrganizationProvider)!;
  late final _name = TextEditingController(text: _start.name);
  late Color _primary = _start.palette.primary;
  late Color _accent = _start.palette.accent;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isHydroTrack =>
      _primary == BrandPalette.hydrotrack.primary &&
      _accent == BrandPalette.hydrotrack.accent;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await ref
        .read(organizationActionControllerProvider.notifier)
        .saveBranding(
          organizationId: _start.id,
          name: _name.text.trim(),
          // HydroTrack's own colors are stored as "none", so they follow
          // any change to the defaults.
          primaryHex: _isHydroTrack ? null : BrandPalette.toHex(_primary),
          accentHex: _isHydroTrack ? null : BrandPalette.toHex(_accent),
        );
    if (!mounted) return;
    if (saved == null) {
      showActionErrorSnackBar(
        context,
        message: readableErrorMessage(
          ref.read(organizationActionControllerProvider).error,
        ),
      );
      return;
    }
    if (widget.setup) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BusinessProfileScreen(organization: saved),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Branding saved')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(organizationActionControllerProvider).isLoading;
    final organization = ref.watch(currentOrganizationProvider) ?? _start;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setup ? 'Make it yours' : 'Branding'),
        automaticallyImplyLeading: !widget.setup,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ResponsiveCenter(
              maxWidth: _maxContentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.setup) ...[
                    const Text(
                      'Add your logo and colors: your staff see your brand '
                      'everywhere in the app, and on receipts and reports. '
                      'You can change this any time under Organization → '
                      'Branding.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppCard(
                    title: 'Name and logo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const OrganizationLogo(size: 72),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: LogoUploadButtons(
                                organization: organization,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'Business name',
                          controller: _name,
                          onChanged: (_) => setState(() {}),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter your business name'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    title: 'Colors',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BrandColorPicker(
                          label: 'Main color',
                          helperText: 'Buttons, menus and headings',
                          value: _primary,
                          swatches: BrandSwatches.main,
                          onChanged: (c) => setState(() => _primary = c),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        BrandColorPicker(
                          label: 'Accent color',
                          helperText: 'Highlights behind selected items',
                          value: _accent,
                          swatches: BrandSwatches.accent,
                          onChanged: (c) => setState(() => _accent = c),
                        ),
                        if (!_isHydroTrack)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AppButton(
                              label: 'Use the standard colors',
                              variant: AppButtonVariant.text,
                              onPressed: () => setState(() {
                                _primary = BrandPalette.hydrotrack.primary;
                                _accent = BrandPalette.hydrotrack.accent;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BrandPreview(
                    palette: BrandPalette(primary: _primary, accent: _accent),
                    name: _name.text.trim(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: widget.setup ? 'Save and continue' : 'Save branding',
                    isLoading: busy,
                    onPressed: busy ? null : _save,
                  ),
                  if (widget.setup)
                    AppButton(
                      label: 'Skip for now',
                      variant: AppButtonVariant.text,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
