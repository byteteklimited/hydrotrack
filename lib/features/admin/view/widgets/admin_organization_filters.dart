import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../subscriptions/data/models/subscription.dart';
import '../../data/models/admin_organization.dart';

/// Search by name or owner contact, and a chip per subscription status
/// with how many organizations are in it.
class AdminOrganizationFilters extends StatelessWidget {
  const AdminOrganizationFilters({
    super.key,
    required this.organizations,
    required this.status,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final List<AdminOrganization> organizations;
  final SubscriptionStatus? status;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SubscriptionStatus?> onStatusChanged;

  int _count(SubscriptionStatus? status) => status == null
      ? organizations.length
      : organizations
            .where(
              (organization) => organization.subscription?.status == status,
            )
            .length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(onChanged: onQueryChanged),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in <SubscriptionStatus?>[
              null,
              ...SubscriptionStatus.values,
            ])
              ChoiceChip(
                label: Text('${option?.label ?? 'All'} (${_count(option)})'),
                selected: status == option,
                onSelected: (_) => onStatusChanged(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => widget.onChanged(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppTextField(
    label: 'Search by organization, owner, phone or email',
    controller: _controller,
    prefixIcon: const Icon(Icons.search),
  );
}
