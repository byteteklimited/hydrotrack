import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/organizations/data/models/business_profile.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';

void main() {
  test('header lines group contacts and registration numbers', () {
    const profile = BusinessProfile(
      address: '12 Zoo Road, Kano',
      phone: '08031234567',
      email: 'sales@sunny.ng',
      rcNumber: 'RC 123456',
      nafdacNumber: 'A1-2345',
    );
    expect(profile.headerLines, [
      '12 Zoo Road, Kano',
      'Tel: 08031234567 · sales@sunny.ng',
      'RC: RC 123456 · NAFDAC: A1-2345',
    ]);
  });

  test('only what was filled in is printed', () {
    expect(const BusinessProfile(email: 'a@b.ng').headerLines, ['a@b.ng']);
    expect(const BusinessProfile().headerLines, isEmpty);
  });

  test('the organization round-trips its profile', () {
    final organization = Organization.fromJson({
      'id': 't1',
      'name': 'Sunny Water',
      'address': 'Kano',
      'phone': '08031234567',
      'rc_number': 'RC 1',
    });
    final again = Organization.fromJson(organization.toJson());
    expect(again.profile.address, 'Kano');
    expect(again.profile.phone, '08031234567');
    expect(again.profile.rcNumber, 'RC 1');
    expect(again.profile.email, isNull);
  });
}
