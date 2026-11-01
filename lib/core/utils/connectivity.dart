import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _hasConnection(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

/// True when the device reports some network connectivity. Doesn't
/// guarantee Supabase itself is reachable — just distinguishes
/// "definitely offline" (airplane mode, no wifi/data) from "might be
/// online," which is what the app-wide offline banner needs.
final isConnectedProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _hasConnection(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_hasConnection);
});
