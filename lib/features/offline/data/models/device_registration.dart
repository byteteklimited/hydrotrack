/// This device's set-up for offline use: which organization it holds and
/// the secret key it syncs with (from `register_device`, shown once).
class DeviceRegistration {
  const DeviceRegistration({
    required this.deviceId,
    required this.deviceKey,
    required this.tenantId,
    required this.deviceName,
    required this.setUpAt,
  });

  final String deviceId;
  final String deviceKey;
  final String tenantId;
  final String deviceName;
  final DateTime setUpAt;

  factory DeviceRegistration.fromJson(Map<String, dynamic> json) {
    return DeviceRegistration(
      deviceId: json['device_id'] as String,
      deviceKey: json['device_key'] as String,
      tenantId: json['tenant_id'] as String,
      deviceName: json['device_name'] as String,
      setUpAt: DateTime.parse(json['set_up_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'device_key': deviceKey,
    'tenant_id': tenantId,
    'device_name': deviceName,
    'set_up_at': setUpAt.toUtc().toIso8601String(),
  };
}
