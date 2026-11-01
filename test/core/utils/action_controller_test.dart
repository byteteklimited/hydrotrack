import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/core/utils/action_controller.dart';

class _TestController extends ActionController {}

void main() {
  group('ActionController.guard', () {
    test('starts at data(null)', () {
      final controller = _TestController();
      expect(controller.state, const AsyncValue<void>.data(null));
    });

    test(
      'returns the action result and ends at data(null) on success',
      () async {
        final controller = _TestController();
        final result = await controller.guard(() async => 42);
        expect(result, 42);
        expect(controller.state, const AsyncValue<void>.data(null));
      },
    );

    test(
      'returns null and surfaces the error when the action throws',
      () async {
        final controller = _TestController();
        final result = await controller.guard<int>(
          () async => throw Exception('no connection'),
        );
        expect(result, isNull);
        expect(controller.state.hasError, isTrue);
      },
    );

    test('is loading while the action is in flight', () async {
      final controller = _TestController();
      final future = controller.guard(() async {
        expect(controller.state.isLoading, isTrue);
        return 1;
      });
      await future;
    });
  });
}
