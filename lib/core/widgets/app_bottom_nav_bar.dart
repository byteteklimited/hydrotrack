import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// One tab of [AppBottomNavBar].
class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The phone tab bar. Every tab gets the same width, and its label stays
/// on one line, shrinking only when the word is too long for the tab (e.g.
/// "Production" on a narrow phone or with large text), so icons and labels
/// always line up. Colors, height and the selected pill come from the
/// theme's `navigationBarTheme`.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = NavigationBarTheme.of(context);
    return Material(
      color: theme.backgroundColor,
      surfaceTintColor: theme.surfaceTintColor,
      elevation: theme.elevation ?? 0,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: theme.height,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _Tab(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  /// Material 3's selected pill behind the icon.
  static const _indicatorWidth = 56.0;
  static const _indicatorHeight = 32.0;

  /// Every label gets the same slot (a line of the label style), so a
  /// label that has to shrink never moves its icon.
  static const _labelHeight = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = NavigationBarTheme.of(context);
    final states = {if (selected) WidgetState.selected};
    final iconTheme = theme.iconTheme?.resolve(states);
    final labelStyle = theme.labelTextStyle?.resolve(states);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: _indicatorWidth,
                height: _indicatorHeight,
                decoration: ShapeDecoration(
                  color: selected ? theme.indicatorColor : null,
                  shape: theme.indicatorShape ?? const StadiumBorder(),
                ),
                child: Icon(
                  item.icon,
                  size: iconTheme?.size,
                  color: iconTheme?.color,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: _labelHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(item.label, maxLines: 1, style: labelStyle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
