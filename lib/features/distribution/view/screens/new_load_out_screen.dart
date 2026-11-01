import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/product_catalog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/action_error.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_form_grid.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_center.dart';
import '../../data/models/driver.dart';
import '../../data/models/load_out.dart';
import '../../data/models/vehicle.dart';
import '../../data/providers/distribution_providers.dart';
import 'add_driver_screen.dart';
import 'add_vehicle_screen.dart';

/// Records a new load-out: who's driving, in what, which product, and how
/// many bags — the matching finished-goods item is deducted automatically.
class NewLoadOutScreen extends ConsumerStatefulWidget {
  const NewLoadOutScreen({super.key});

  @override
  ConsumerState<NewLoadOutScreen> createState() => _NewLoadOutScreenState();
}

class _NewLoadOutScreenState extends ConsumerState<NewLoadOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bagsController = TextEditingController();
  final _noteController = TextEditingController();

  Driver? _driver;
  Vehicle? _vehicle;
  ProductType _product = ProductType.sachet50cl;

  @override
  void initState() {
    super.initState();
    _bagsController.addListener(_recompute);
  }

  @override
  void dispose() {
    _bagsController.removeListener(_recompute);
    _bagsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _recompute() => setState(() {});

  Future<void> _submit(Driver defaultDriver, Vehicle defaultVehicle) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final driver = _driver ?? defaultDriver;
    final vehicle = _vehicle ?? defaultVehicle;

    final loadOut = LoadOut(
      id: 'lo-${DateTime.now().microsecondsSinceEpoch}',
      dateTime: DateTime.now(),
      driverId: driver.id,
      vehicleId: vehicle.id,
      product: _product,
      bagsLoaded: int.parse(_bagsController.text),
      status: LoadOutStatus.onRoad,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    await ref
        .read(distributionActionControllerProvider.notifier)
        .recordLoadOut(loadOut);
    if (!mounted) return;

    if (ref.read(distributionActionControllerProvider).hasError) {
      showActionErrorSnackBar(context);
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final isSaving = ref.watch(distributionActionControllerProvider).isLoading;
    final bags = int.tryParse(_bagsController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('New load-out')),
      body: driversAsync.when(
        data: (drivers) {
          if (drivers.isEmpty) {
            return AppEmptyState(
              icon: Icons.person_add_outlined,
              title: 'No drivers yet',
              message: 'Add a driver before recording a load-out.',
              actionLabel: 'Add driver',
              onAction: () => showAppModal(
                context,
                builder: (_) => const AddDriverScreen(),
              ),
            );
          }
          return vehiclesAsync.when(
            data: (vehicles) {
              if (vehicles.isEmpty) {
                return AppEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No vehicles yet',
                  message: 'Add a vehicle before recording a load-out.',
                  actionLabel: 'Add vehicle',
                  onAction: () => showAppModal(
                    context,
                    builder: (_) => const AddVehicleScreen(),
                  ),
                );
              }
              final fields = [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppDropdownField<Driver>(
                      label: 'Driver',
                      value: _driver ?? drivers.first,
                      items: drivers,
                      itemLabel: (d) => d.name,
                      onChanged: (d) => setState(() => _driver = d),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton(
                        label: '+ Add new driver',
                        variant: AppButtonVariant.text,
                        onPressed: () => showAppModal(
                          context,
                          builder: (_) => const AddDriverScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppDropdownField<Vehicle>(
                      label: 'Vehicle',
                      value: _vehicle ?? vehicles.first,
                      items: vehicles,
                      itemLabel: (v) => v.name,
                      onChanged: (v) => setState(() => _vehicle = v),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AppButton(
                        label: '+ Add new vehicle',
                        variant: AppButtonVariant.text,
                        onPressed: () => showAppModal(
                          context,
                          builder: (_) => const AddVehicleScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                AppDropdownField<ProductType>(
                  label: 'Product',
                  value: _product,
                  items: ProductType.values,
                  itemLabel: (product) => product.label,
                  onChanged: (product) => setState(() => _product = product!),
                ),
                AppTextField.quantity(
                  label: 'Bags loaded',
                  controller: _bagsController,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter the number of bags loaded.'
                      : null,
                ),
                AppTextField(
                  label: 'Note (optional)',
                  controller: _noteController,
                ),
              ];

              return SafeArea(
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
                              if (bags != null && bags > 0) ...[
                                const SizedBox(height: AppSpacing.md),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'This will move $bags ${_product.label} bags out of finished goods.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              AppButton(
                                label: 'Confirm load-out',
                                isLoading: isSaving,
                                expanded: true,
                                onPressed: isSaving
                                    ? null
                                    : () => _submit(
                                        _driver ?? drivers.first,
                                        _vehicle ?? vehicles.first,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const AppLoading(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          );
        },
        loading: () => const AppLoading(),
        error: (error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
