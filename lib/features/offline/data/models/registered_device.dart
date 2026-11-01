/// A device set up for offline use, as an admin sees it in the list of
/// the organization's devices.
class RegisteredDevice {
  const RegisteredDevice({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastSeenAt,
    this.revokedAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? value) =>
        value == null ? null : DateTime.parse(value as String);
    return RegisteredDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSeenAt: parse(json['last_seen_at']),
      revokedAt: parse(json['revoked_at']),
    );
  }
}
