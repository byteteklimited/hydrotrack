import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/auth/data/models/staff_user.dart';
import 'package:hydrotrack/features/organizations/data/models/invitation.dart';

Invitation _invitation({DateTime? acceptedAt, DateTime? revokedAt}) {
  return Invitation(
    id: 'i1',
    code: 'K7QX2MPR9T',
    fullName: 'Emeka Obi',
    role: StaffRole.storeKeeper,
    phone: '08051234567',
    createdAt: DateTime(2026, 10, 1),
    expiresAt: DateTime(2026, 10, 8),
    acceptedAt: acceptedAt,
    revokedAt: revokedAt,
  );
}

void main() {
  final beforeExpiry = DateTime(2026, 10, 5);
  final afterExpiry = DateTime(2026, 10, 9);

  group('Invitation.statusAt', () {
    test('is pending before expiry when unused', () {
      expect(_invitation().statusAt(beforeExpiry), InvitationStatus.pending);
    });

    test('is expired after expiry when unused', () {
      expect(_invitation().statusAt(afterExpiry), InvitationStatus.expired);
    });

    test('accepted wins over expiry', () {
      final accepted = _invitation(acceptedAt: DateTime(2026, 10, 2));
      expect(accepted.statusAt(afterExpiry), InvitationStatus.accepted);
    });

    test('revoked wins over expiry', () {
      final revoked = _invitation(revokedAt: DateTime(2026, 10, 2));
      expect(revoked.statusAt(beforeExpiry), InvitationStatus.revoked);
    });
  });

  group('Invitation JSON', () {
    test('round-trips through fromJson(toJson(x))', () {
      final invitation = _invitation(acceptedAt: DateTime(2026, 10, 2));
      final roundTripped = Invitation.fromJson(invitation.toJson());
      expect(roundTripped.code, 'K7QX2MPR9T');
      expect(roundTripped.role, StaffRole.storeKeeper);
      expect(roundTripped.sentTo, '08051234567');
      expect(roundTripped.expiresAt, invitation.expiresAt);
      expect(roundTripped.acceptedAt, invitation.acceptedAt);
      expect(roundTripped.revokedAt, isNull);
    });

    test('sentTo falls back to the email', () {
      final invitation = Invitation.fromJson({
        'id': 'i2',
        'code': 'ABCDEFGHJK',
        'full_name': 'Tunde Bakare',
        'role': 'admin',
        'phone': null,
        'email': 'tunde@example.com',
        'created_at': '2026-10-01T00:00:00Z',
        'expires_at': '2026-10-08T00:00:00Z',
        'accepted_at': null,
        'revoked_at': null,
      });
      expect(invitation.sentTo, 'tunde@example.com');
    });
  });
}
