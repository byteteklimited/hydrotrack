import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/organizations/data/models/membership.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';

Map<String, dynamic> _row({
  String role = 'manager',
  bool isActive = true,
  String? phone = '08031234567',
  String? email,
}) {
  return {
    'role': role,
    'is_active': isActive,
    'user_id': 'u1',
    'tenants': {'id': 't1', 'name': 'Kano Pure Water', 'logo_path': null},
    'profiles': {'full_name': 'Aisha Lawal', 'phone': phone, 'email': email},
  };
}

void main() {
  group('Organization JSON', () {
    test('round-trips through fromJson(toJson(x))', () {
      const organization = Organization(
        id: 't1',
        name: 'Kano Pure Water',
        logoPath: 't1/logo.png',
      );
      final roundTripped = Organization.fromJson(organization.toJson());
      expect(roundTripped.id, 't1');
      expect(roundTripped.name, 'Kano Pure Water');
      expect(roundTripped.logoPath, 't1/logo.png');
    });
  });

  group('Membership', () {
    test('fromJson reads the tenant, role and embedded profile', () {
      final membership = Membership.fromJson(_row());
      expect(membership.organization.id, 't1');
      expect(membership.organization.name, 'Kano Pure Water');
      expect(membership.role, StaffRole.manager);
      expect(membership.isActive, isTrue);
      expect(membership.fullName, 'Aisha Lawal');
      expect(membership.contact, '08031234567');
    });

    test('contact falls back to the email for email-only owners', () {
      final membership = Membership.fromJson(
        _row(role: 'owner', phone: null, email: 'aisha@example.com'),
      );
      expect(membership.role, StaffRole.owner);
      expect(membership.contact, 'aisha@example.com');
    });

    test('toStaffUser carries this organization\'s role', () {
      final user = Membership.fromJson(_row(role: 'cashier')).toStaffUser();
      expect(user.id, 'u1');
      expect(user.fullName, 'Aisha Lawal');
      expect(user.role, StaffRole.cashier);
    });

    test('reads a deactivated membership', () {
      expect(Membership.fromJson(_row(isActive: false)).isActive, isFalse);
    });
  });
}
