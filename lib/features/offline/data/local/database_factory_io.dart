import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// Phones and desktops: a file in the app's private support folder.
Future<Database> openOfflineDatabase(String name) async {
  final directory = await getApplicationSupportDirectory();
  return databaseFactoryIo.openDatabase('${directory.path}/$name');
}
