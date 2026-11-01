import 'package:sembast_web/sembast_web.dart';

/// Browsers: IndexedDB. It survives reloads and restarts, but is lost if
/// someone clears the browser's site data.
Future<Database> openOfflineDatabase(String name) {
  return databaseFactoryWeb.openDatabase(name);
}
