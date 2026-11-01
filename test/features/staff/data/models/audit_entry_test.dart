import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/staff/data/models/audit_entry.dart';

void main() {
  group('AuditEntry JSON', () {
    test('fromJson reads the audit_trail view shape, including "at"', () {
      final entry = AuditEntry.fromJson({
        'id': 'a1',
        'staff_name': 'Ngozi Okafor',
        'role': 'cashier',
        'category': 'sales',
        'description': 'Recorded sale of 40 bags to Blessing Stores',
        'at': '2026-03-05T09:14:00.000Z',
      });
      expect(entry.staffName, 'Ngozi Okafor');
      expect(entry.role, StaffRole.cashier);
      expect(entry.category, AuditCategory.sales);
      expect(entry.timestamp, DateTime.parse('2026-03-05T09:14:00.000Z'));
    });

    test('toJson writes the timestamp back under "at"', () {
      final entry = AuditEntry(
        id: 'a1',
        staffName: 'Ngozi Okafor',
        role: StaffRole.cashier,
        category: AuditCategory.sales,
        description: 'Recorded a sale',
        timestamp: DateTime(2026, 3, 5, 9, 14),
      );
      final json = entry.toJson();
      expect(json['at'], entry.timestamp.toIso8601String());
      expect(json.containsKey('timestamp'), isFalse);
    });

    test('round-trips through fromJson(toJson(x))', () {
      final entry = AuditEntry(
        id: 'a1',
        staffName: 'Musa Ibrahim',
        role: StaffRole.admin,
        category: AuditCategory.staff,
        description: 'Deactivated staff account — Chidi Eze',
        timestamp: DateTime(2026, 3, 5, 9, 14),
      );
      final roundTripped = AuditEntry.fromJson(entry.toJson());
      expect(roundTripped.staffName, entry.staffName);
      expect(roundTripped.role, entry.role);
      expect(roundTripped.category, entry.category);
      expect(roundTripped.description, entry.description);
      expect(roundTripped.timestamp, entry.timestamp);
    });
  });
}
