import 'package:flutter_test/flutter_test.dart';
import 'package:hydrotrack/features/organizations/data/models/bank_details.dart';
import 'package:hydrotrack/features/organizations/data/models/organization.dart';

void main() {
  const details = BankDetails(
    bankName: 'GTBank',
    accountNumber: '0123456789',
    accountName: 'Kano Pure Water Ltd',
  );

  test('Organization round-trips its bank details', () {
    const organization = Organization(
      id: 't1',
      name: 'Kano Pure Water',
      bankDetails: details,
    );
    final roundTripped = Organization.fromJson(organization.toJson());
    expect(roundTripped.bankDetails?.bankName, 'GTBank');
    expect(roundTripped.bankDetails?.accountNumber, '0123456789');
    expect(roundTripped.bankDetails?.accountName, 'Kano Pure Water Ltd');
  });

  test('no bank details when the columns are empty or missing', () {
    expect(
      Organization.fromJson({
        'id': 't1',
        'name': 'Kano Pure Water',
      }).bankDetails,
      isNull,
    );
    expect(
      BankDetails.fromTenantJson({
        'bank_name': 'GTBank',
        'bank_account_number': null,
        'bank_account_name': 'Kano Pure Water Ltd',
      }),
      isNull,
    );
  });

  test('clearing writes all three columns as null', () {
    expect(BankDetails.toTenantJson(null), {
      'bank_name': null,
      'bank_account_number': null,
      'bank_account_name': null,
    });
  });
}
