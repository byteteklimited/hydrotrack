import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/data/providers/admin_providers.dart';
import '../../features/auth/data/models/staff_user.dart';
import '../../features/auth/data/providers/auth_providers.dart';
import '../../features/organizations/data/providers/organization_providers.dart';
import '../../features/organizations/view/widgets/organization_logo.dart';
import '../constants/app_routes.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';
import 'app_coming_soon_page.dart';
import 'app_nav_section.dart';
import '../theme/brand_palette.dart';

/// Below this width: NavigationBar at the bottom. At or above: a sidebar
/// down the side, matching Material's medium/expanded breakpoint. Public
/// so screens know when the sidebar (and its account footer) isn't there.
const double wideNavBreakpoint = 700;

const double _sidebarWidth = 232;
const double _sidebarCollapsedWidth = 72;
const double _sidebarHeaderHeight = 64;

/// Adaptive shell used for every screen after sign-in. Destinations are
/// filtered by the signed-in user's role; [pageBuilder] supplies the screen
/// for a built section and falls back to [AppComingSoonPage] otherwise.
class AppNavigationShell extends ConsumerStatefulWidget {
  const AppNavigationShell({super.key, required this.pageBuilder});

  final Widget? Function(AppSection section) pageBuilder;

  @override
  ConsumerState<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends ConsumerState<AppNavigationShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    if (user == null) return const SizedBox.shrink();

    final config = RoleNavConfig.forRole(user.role);
    final destinations = [
      for (final section in config.primary)
        NavigationDestination(icon: Icon(section.icon), label: section.label),
      if (config.overflow.isNotEmpty)
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
    ];
    final pages = [
      for (final section in config.primary)
        widget.pageBuilder(section) ?? AppComingSoonPage(section: section),
    ];

    void onSelect(int index) {
      if (index == config.primary.length) {
        _showMoreSheet(context, config.overflow);
        return;
      }
      setState(() => _selectedIndex = index);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final body = IndexedStack(index: _selectedIndex, children: pages);
        final isWide = constraints.maxWidth >= wideNavBreakpoint;

        if (!isWide) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: onSelect,
              destinations: destinations,
            ),
          );
        }

        // Full labels need real room to avoid wrapping — at tablet widths
        // (just past the bottom-bar cutoff, short of desktop) the sidebar
        // collapses to icon-only with tooltips until there's enough width
        // to spare for all of them. Same cutoff the rail used before this
        // restyle, just applied to a hand-built sidebar instead of
        // `NavigationRail`.
        final showLabels = AppBreakpoints.isExpanded(constraints.maxWidth);

        return Scaffold(
          body: Row(
            children: [
              _Sidebar(
                user: user,
                config: config,
                selectedIndex: _selectedIndex,
                showLabels: showLabels,
                onSelect: onSelect,
              ),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }

  void _showMoreSheet(BuildContext context, List<AppSection> overflow) {
    // Grows to fit every row (Flutter's default caps a sheet at ~56% of
    // the window) and scrolls when the window is too short for them all.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < overflow.length; i++) ...[
                  _MoreSheetRow(
                    section: overflow[i],
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              widget.pageBuilder(overflow[i]) ??
                              AppComingSoonPage(section: overflow[i]),
                        ),
                      );
                    },
                  ),
                  if (i != overflow.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The restyled left sidebar: brand header, destination list (same
/// selection state/callback as the bottom nav bar uses), and a footer
/// identifying who's signed in with a sign-out control — calling the
/// exact same [signOutAndReturnToLogin] function every other sign-out
/// control in the app calls.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.user,
    required this.config,
    required this.selectedIndex,
    required this.showLabels,
    required this.onSelect,
  });

  final StaffUser user;
  final RoleNavConfig config;
  final int selectedIndex;
  final bool showLabels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinationCount =
        config.primary.length + (config.overflow.isNotEmpty ? 1 : 0);

    return Container(
      width: showLabels ? _sidebarWidth : _sidebarCollapsedWidth,
      color: AppColors.surfaceWhite,
      child: Column(
        children: [
          SizedBox(
            height: _sidebarHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Align(
                alignment: showLabels ? Alignment.centerLeft : Alignment.center,
                child: _OrganizationHeader(showName: showLabels),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                for (var i = 0; i < destinationCount; i++)
                  _SidebarItem(
                    icon: i < config.primary.length
                        ? config.primary[i].icon
                        : Icons.more_horiz,
                    label: i < config.primary.length
                        ? config.primary[i].label
                        : 'More',
                    selected: i == selectedIndex && i < config.primary.length,
                    showLabel: showLabels,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _SidebarFooter(user: user, showLabels: showLabels),
        ],
      ),
    );
  }
}

/// One destination row — icon + label on wide sidebars, icon-only with a
/// tooltip once the sidebar collapses at tablet widths.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.brand.primaryText
        : AppColors.textSecondary;

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Material(
          color: selected ? context.brand.accentTint : Colors.transparent,
          child: Stack(
            children: [
              InkWell(
                hoverColor: selected
                    ? context.brand.accentTint
                    : AppColors.hoverNeutral,
                onTap: onTap,
                child: Container(
                  height: 40,
                  padding: EdgeInsets.symmetric(
                    horizontal: showLabel ? AppSpacing.md : 0,
                  ),
                  alignment: showLabel
                      ? Alignment.centerLeft
                      : Alignment.center,
                  child: showLabel
                      ? Row(
                          children: [
                            Icon(icon, size: 20, color: color),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                label,
                                style: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(color: color),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Icon(icon, size: 20, color: color),
                ),
              ),
              // The active item's cyan indicator — cyan never carries text
              // or an icon on its own (it's ~2.2:1 against white, well
              // under what's readable), so it only ever appears as this
              // accent bar; the actual meaning (which item is active)
              // reads through the navy icon/label above, not the bar.
              if (selected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: context.brand.accent),
                ),
            ],
          ),
        ),
      ),
    );

    return showLabel ? row : Tooltip(message: label, child: row);
  }
}

class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter({required this.user, required this.showLabels});

  final StaffUser user;
  final bool showLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final organizationName = ref.watch(currentOrganizationProvider)?.name ?? '';
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: context.brand.accentTint,
      child: Text(
        user.initials,
        style: textTheme.labelMedium?.copyWith(
          color: context.brand.primaryText,
        ),
      ),
    );
    final isPlatformAdmin =
        ref.watch(isPlatformAdminProvider).valueOrNull ?? false;
    final actions = [
      if (isPlatformAdmin)
        _FooterAction(
          tooltip: 'HydroTrack admin',
          icon: Icons.admin_panel_settings_outlined,
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.admin),
        ),
      _FooterAction(
        tooltip: 'Switch organization',
        icon: Icons.swap_horiz,
        onPressed: () => switchOrganization(context, ref),
      ),
      _FooterAction(
        tooltip: 'Sign out',
        icon: Icons.logout,
        onPressed: () => signOutAndReturnToLogin(context, ref),
      ),
    ];

    if (!showLabels) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Tooltip(message: organizationName, child: avatar),
            const SizedBox(height: AppSpacing.xs),
            ...actions,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.fullName.split(' ').first} · ${user.role.label}',
                  style: textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  organizationName,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A small icon button in the sidebar footer.
class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: AppColors.textSecondary,
        onPressed: onPressed,
      ),
    );
  }
}

/// One row in the "More" sheet's grouped list — icon, label, chevron,
/// 48px tall.
class _MoreSheetRow extends StatelessWidget {
  const _MoreSheetRow({required this.section, required this.onTap});

  final AppSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Icon(section.icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                section.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The sidebar's header: the organization's logo (or initials badge) and
/// name — its brand, not HydroTrack's.
class _OrganizationHeader extends ConsumerWidget {
  const _OrganizationHeader({required this.showName});

  final bool showName;

  static const _logoSize = 32.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentOrganizationProvider)?.name ?? '';
    if (!showName) return const OrganizationLogo(size: _logoSize);
    return Row(
      children: [
        const OrganizationLogo(size: _logoSize),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
