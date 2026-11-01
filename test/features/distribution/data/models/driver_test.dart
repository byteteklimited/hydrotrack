import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/distribution/data/models/driver.dart';

void main() {
  test('Driver round-trips through fromJson(toJson(x))', () {
    const driver = Driver(
      id: 'd1',
      name: 'Suleiman Bello',
      phone: '08099998888',
    );
    final roundTripped = Driver.fromJson(driver.toJson());
    expect(roundTripped.id, driver.id);
    expect(roundTripped.name, driver.name);
    expect(roundTripped.phone, driver.phone);
  });
}
