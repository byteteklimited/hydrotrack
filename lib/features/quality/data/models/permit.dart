/// A licence or permit the factory must keep valid (NAFDAC, SON, water
/// board, fire…). The owner is reminded 60, 30 and 7 days before it
/// expires, and on the day.
class Permit {
  const Permit({
    required this.id,
    required this.name,
    required this.expiresOn,
    this.number,
    this.note,
  });

  /// Shown as "due soon" this many days before expiry.
  static const dueSoonDays = 30;

  final String id;
  final String name;
  final String? number;
  final DateTime expiresOn;
  final String? note;

  /// Days from [today] to expiry; negative once expired.
  int daysLeft(DateTime today) => DateTime(
    expiresOn.year,
    expiresOn.month,
    expiresOn.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;

  factory Permit.fromJson(Map<String, dynamic> json) => Permit(
    id: json['id'] as String,
    name: json['name'] as String,
    number: json['number'] as String?,
    expiresOn: DateTime.parse(json['expires_on'] as String),
    note: json['note'] as String?,
  );

  /// The columns the app writes (tenant_id is added by the repository).
  Map<String, dynamic> toWriteJson() => {
    'name': name,
    'number': number,
    'expires_on': expiresOn.toIso8601String().split('T').first,
    'note': note,
  };
}
