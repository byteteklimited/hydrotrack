import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/staff/data/models/staff_member.dart';

StaffMember _buildMember({
  bool isActive = true,
  StaffRole role = StaffRole.cashier,
}) {
  return StaffMember(
    id: 's1',
    fullName: 'Ngozi Okafor',
    role: role,
    phone: '08056781234',
    isActive: isActive,
    joinedOn: DateTime(2026, 2, 3),
  );
}

void main() {
  group('StaffMember JSON', () {
    test('fromJson reads a tenant_members row with its embedded profile', () {
      final member = StaffMember.fromJson({
        'user_id': 's1',
        'role': 'cashier',
        'is_active': false,
        'joined_at': '2026-02-03T00:00:00.000Z',
        'profiles': {
          'full_name': 'Ngozi Okafor',
          'phone': '08056781234',
          'email': null,
        },
      });
      expect(member.id, 's1');
      expect(member.fullName, 'Ngozi Okafor');
      expect(member.role, StaffRole.cashier);
      expect(member.phone, '08056781234');
      expect(member.isActive, isFalse);
      expect(member.joinedOn, DateTime.parse('2026-02-03T00:00:00.000Z'));
    });

    test('falls back to the email when the member has no phone', () {
      final member = StaffMember.fromJson({
        'user_id': 'o1',
        'role': 'owner',
        'is_active': true,
        'joined_at': '2026-02-03T00:00:00.000Z',
        'profiles': {
          'full_name': 'Hauwa Bello',
          'phone': null,
          'email': 'hauwa@example.com',
        },
      });
      expect(member.role, StaffRole.owner);
      expect(member.phone, 'hauwa@example.com');
    });

    test('round-trips through fromJson(toJson(x))', () {
      final member = _buildMember();
      final roundTripped = StaffMember.fromJson(member.toJson());
      expect(roundTripped.id, member.id);
      expect(roundTripped.fullName, member.fullName);
      expect(roundTripped.role, member.role);
      expect(roundTripped.phone, member.phone);
      expect(roundTripped.isActive, member.isActive);
      expect(roundTripped.joinedOn, member.joinedOn);
    });
  });

  group('copyWith', () {
    test('changes only the given fields', () {
      final member = _buildMember();
      final deactivated = member.copyWith(isActive: false);
      expect(deactivated.isActive, isFalse);
      expect(deactivated.role, member.role);
      expect(deactivated.fullName, member.fullName);
    });

    test('changes role independently of active status', () {
      final member = _buildMember();
      final promoted = member.copyWith(role: StaffRole.manager);
      expect(promoted.role, StaffRole.manager);
      expect(promoted.isActive, member.isActive);
    });
  });
}
