/// Material's three standard width classes. Used everywhere a screen needs
/// to switch from a single stretched column (phone) to a width-constrained
/// or multi-column layout (tablet, desktop) — the nav shell already uses
/// its own threshold for the same reason.
class AppBreakpoints {
  AppBreakpoints._();

  static const double medium = 600;
  static const double expanded = 840;

  static bool isCompact(double width) => width < medium;
  static bool isMediumOrWider(double width) => width >= medium;
  static bool isExpanded(double width) => width >= expanded;
}
