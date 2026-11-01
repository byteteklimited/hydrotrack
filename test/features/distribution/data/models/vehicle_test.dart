import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/distribution/data/models/vehicle.dart';

void main() {
  test('Vehicle round-trips through fromJson(toJson(x))', () {
    const vehicle = Vehicle(id: 'v1', name: 'Blue Dyna — ABJ 342 XA');
    final roundTripped = Vehicle.fromJson(vehicle.toJson());
    expect(roundTripped.id, vehicle.id);
    expect(roundTripped.name, vehicle.name);
  });
}
