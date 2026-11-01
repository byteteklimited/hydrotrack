import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';

void main() {
  group('StaffUser JSON', () {
    test('fromJson maps snake_case role to the matching enum', () {
      final user = StaffUser.fromJson({
        'id': 'u1',
        'full_name': 'Musa Ibrahim',
        'role': 'store_keeper',
        'phone': '08031234567',
      });
      expect(user.role, StaffRole.storeKeeper);
    });

    test('toJson maps the enum back to its snake_case value', () {
      const user = StaffUser(
        id: 'u1',
        fullName: 'Musa Ibrahim',
        role: StaffRole.storeKeeper,
        phone: '08031234567',
      );
      expect(user.toJson()['role'], 'store_keeper');
    });

    test('round-trips through fromJson(toJson(x))', () {
      const user = StaffUser(
        id: 'u1',
        fullName: 'Musa Ibrahim',
        role: StaffRole.admin,
        phone: '08031234567',
      );
      final roundTripped = StaffUser.fromJson(user.toJson());
      expect(roundTripped.id, user.id);
      expect(roundTripped.fullName, user.fullName);
      expect(roundTripped.role, user.role);
      expect(roundTripped.phone, user.phone);
    });

    test('fromJson throws for an unrecognized role', () {
      expect(
        () => StaffUser.fromJson({
          'id': 'u1',
          'full_name': 'X',
          'role': 'supervisor',
          'phone': '0',
        }),
        throwsArgumentError,
      );
    });

    test('maps the owner role both ways', () {
      expect(staffRoleFromDb('owner'), StaffRole.owner);
      expect(staffRoleToDb(StaffRole.owner), 'owner');
    });
  });

  group('StaffRolePermissions', () {
    test('isAdminLevel is true only for owner and admin', () {
      expect(StaffRole.values.where((r) => r.isAdminLevel), [
        StaffRole.owner,
        StaffRole.admin,
      ]);
    });

    test('canManage adds manager to the admin-level roles', () {
      expect(StaffRole.values.where((r) => r.canManage), [
        StaffRole.owner,
        StaffRole.admin,
        StaffRole.manager,
      ]);
    });
  });

  group('StaffRoleLabel', () {
    test('every role has a human-readable label', () {
      for (final role in StaffRole.values) {
        expect(role.label, isNotEmpty);
      }
    });
  });
}
