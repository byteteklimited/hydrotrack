/// Named routes for top-level navigation (splash → login → organization →
/// home). Keeping these as strings, not screen imports, is what lets auth,
/// organization and reports screens navigate between each other without
/// depending on one another.
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const joinWithInvite = '/join';
  static const organizations = '/organizations';
  static const home = '/home';
}
