/// Days since a customer's last payment before they're flagged overdue.
class DebtsThresholds {
  DebtsThresholds._();

  static const overdueDays = 14;

  /// SMS debt reminders: days between reminders and the most sent since a
  /// customer's last payment. Shown in settings; the schedule itself runs
  /// on the server (`claim_due_debt_reminders`, migration 0014), which
  /// must use the same numbers.
  static const reminderIntervalDays = 7;
  static const maxReminders = 4;
}
