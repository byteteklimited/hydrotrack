import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base for controllers that perform one write action and expose its
/// progress as `AsyncValue<void>` — "Record sale", "Add stock", and
/// every other single-action form in the app follow this shape.
///
/// [guard] wraps the action so a failure (most commonly no network
/// connection) surfaces as a normal [AsyncValue.error] the screen can
/// check and report, instead of an uncaught exception that leaves the
/// loading spinner stuck forever.
abstract class ActionController extends StateNotifier<AsyncValue<void>> {
  ActionController() : super(const AsyncValue.data(null));

  Future<T?> guard<T>(Future<T> Function() action) async {
    state = const AsyncValue.loading();
    try {
      final result = await action();
      state = const AsyncValue.data(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}
