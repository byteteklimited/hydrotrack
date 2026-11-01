import 'worker.dart';

/// A month's payroll (owners and admins only).
class Payroll {
  const Payroll({
    required this.id,
    required this.month,
    required this.isPaid,
    required this.workingDays,
    required this.lines,
    this.paidAt,
  });

  final String id;

  /// First day of the month.
  final DateTime month;
  final bool isPaid;

  /// Mondays to Saturdays in the month.
  final int workingDays;
  final DateTime? paidAt;
  final List<PayrollLine> lines;

  num get totalNet => lines.fold<num>(0, (sum, line) => sum + line.net);

  /// A line below zero (advances more than pay) blocks paying.
  bool get hasNegativeLine => lines.any((line) => line.net < 0);

  factory Payroll.fromJson(Map<String, dynamic> json) => Payroll(
    id: json['id'] as String,
    month: DateTime.parse(json['month'] as String),
    isPaid: json['status'] == 'paid',
    workingDays: json['working_days'] as int,
    paidAt: json['paid_at'] == null
        ? null
        : DateTime.parse(json['paid_at'] as String).toLocal(),
    lines: [
      for (final line in json['payroll_lines'] as List? ?? const [])
        PayrollLine.fromJson(line as Map<String, dynamic>),
    ]..sort((a, b) => a.workerName.compareTo(b.workerName)),
  );
}

/// One person's pay for the month, worked out by the server.
class PayrollLine {
  const PayrollLine({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.payType,
    required this.rate,
    required this.daysPresent,
    required this.daysAbsent,
    required this.bags,
    required this.gross,
    required this.absenceDeduction,
    required this.advances,
    required this.adjustment,
    required this.net,
    this.adjustmentNote,
  });

  final String id;
  final String workerId;
  final String workerName;
  final PayType payType;
  final num rate;
  final num daysPresent;
  final num daysAbsent;
  final int bags;
  final num gross;
  final num absenceDeduction;
  final num advances;
  final num adjustment;
  final String? adjustmentNote;
  final num net;

  factory PayrollLine.fromJson(Map<String, dynamic> json) => PayrollLine(
    id: json['id'] as String,
    workerId: json['worker_id'] as String,
    workerName:
        (json['workers'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    payType: PayType.fromDb(json['pay_type'] as String),
    rate: json['rate'] as num,
    daysPresent: json['days_present'] as num,
    daysAbsent: json['days_absent'] as num,
    bags: json['bags'] as int,
    gross: json['gross'] as num,
    absenceDeduction: json['absence_deduction'] as num,
    advances: json['advances'] as num,
    adjustment: json['adjustment'] as num,
    adjustmentNote: json['adjustment_note'] as String?,
    net: json['net'] as num,
  );
}

/// Money given to a worker before payday, taken off their next payroll.
class SalaryAdvance {
  const SalaryAdvance({
    required this.id,
    required this.workerId,
    required this.date,
    required this.amount,
    required this.deducted,
    this.note,
  });

  final String id;
  final String workerId;
  final DateTime date;
  final num amount;

  /// Taken off a paid payroll already.
  final bool deducted;
  final String? note;

  factory SalaryAdvance.fromJson(Map<String, dynamic> json) => SalaryAdvance(
    id: json['id'] as String,
    workerId: json['worker_id'] as String,
    date: DateTime.parse(json['date'] as String),
    amount: json['amount'] as num,
    deducted: json['payroll_id'] != null,
    note: json['note'] as String?,
  );
}
