enum PayType {
  monthly('Monthly salary', 'a month'),
  daily('Daily wage', 'a day'),
  perBag('Per bag', 'a bag');

  const PayType(this.label, this.per);

  final String label;

  /// For "₦3,000 a day".
  final String per;

  String get dbValue => this == perBag ? 'per_bag' : name;

  static PayType fromDb(String value) =>
      values.firstWhere((type) => type.dbValue == value);
}

/// Someone on the payroll: a packer, loader or guard without the app, or
/// an app staff member ([userId]). Their rate is kept separately and only
/// owners and admins can see it.
class Worker {
  const Worker({
    required this.id,
    required this.name,
    required this.payType,
    required this.isActive,
    this.phone,
    this.jobTitle,
    this.userId,
  });

  final String id;
  final String name;
  final PayType payType;
  final bool isActive;
  final String? phone;
  final String? jobTitle;
  final String? userId;

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
    id: json['id'] as String,
    name: json['name'] as String,
    payType: PayType.fromDb(json['pay_type'] as String),
    isActive: json['is_active'] as bool? ?? true,
    phone: json['phone'] as String?,
    jobTitle: json['job_title'] as String?,
    userId: json['user_id'] as String?,
  );

  Map<String, dynamic> toWriteJson() => {
    'name': name,
    'pay_type': payType.dbValue,
    'is_active': isActive,
    'phone': phone,
    'job_title': jobTitle,
    'user_id': userId,
  };
}

enum AttendanceStatus {
  present('Present'),
  halfDay('Half day'),
  absent('Absent');

  const AttendanceStatus(this.label);

  final String label;

  String get dbValue => this == halfDay ? 'half_day' : name;

  static AttendanceStatus fromDb(String value) =>
      values.firstWhere((status) => status.dbValue == value);
}

/// One worker's attendance on one day.
class AttendanceMark {
  const AttendanceMark({
    required this.workerId,
    required this.date,
    required this.status,
  });

  final String workerId;
  final DateTime date;
  final AttendanceStatus status;

  factory AttendanceMark.fromJson(Map<String, dynamic> json) => AttendanceMark(
    workerId: json['worker_id'] as String,
    date: DateTime.parse(json['date'] as String),
    status: AttendanceStatus.fromDb(json['status'] as String),
  );
}

/// One per-bag worker's bags on one day.
class BagCount {
  const BagCount({
    required this.workerId,
    required this.date,
    required this.bags,
  });

  final String workerId;
  final DateTime date;
  final int bags;

  factory BagCount.fromJson(Map<String, dynamic> json) => BagCount(
    workerId: json['worker_id'] as String,
    date: DateTime.parse(json['date'] as String),
    bags: json['bags'] as int,
  );
}
