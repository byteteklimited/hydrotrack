import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Pick a color from [swatches] or type its hex code (#RRGGBB).
class BrandColorPicker extends StatefulWidget {
  const BrandColorPicker({
    super.key,
    required this.label,
    required this.value,
    required this.swatches,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final Color value;
  final List<Color> swatches;
  final ValueChanged<Color> onChanged;
  final String? helperText;

  @override
  State<BrandColorPicker> createState() => _BrandColorPickerState();
}

class _BrandColorPickerState extends State<BrandColorPicker> {
  late final _hex = TextEditingController(
    text: BrandPalette.toHex(widget.value),
  );

  static const _swatchSize = 36.0;

  @override
  void didUpdateWidget(BrandColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hex = BrandPalette.toHex(widget.value);
    if (BrandPalette.parseHex(_hex.text) != widget.value) _hex.text = hex;
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        if (widget.helperText != null)
          Text(
            widget.helperText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final color in widget.swatches)
              Tooltip(
                message: BrandPalette.toHex(color),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => widget.onChanged(color),
                  child: Container(
                    width: _swatchSize,
                    height: _swatchSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color == widget.value
                            ? AppColors.textPrimary
                            : AppColors.border,
                        width: color == widget.value ? 3 : 1,
                      ),
                    ),
                    child: color == widget.value
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: BrandPalette.textOn(color),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Or type a color code, e.g. #1D4ED8',
          controller: _hex,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: widget.value,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
          validator: (v) => BrandPalette.parseHex(v) == null
              ? 'Use 6 characters after #, e.g. #1D4ED8'
              : null,
          onChanged: (text) {
            final color = BrandPalette.parseHex(text);
            if (color != null) widget.onChanged(color);
          },
        ),
      ],
    );
  }
}
