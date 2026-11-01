/// One thing on the organization's daily sanitation checklist.
class SanitationItem {
  const SanitationItem({
    required this.id,
    required this.name,
    required this.position,
    required this.isActive,
  });

  final String id;
  final String name;
  final int position;

  /// Stopped items stay in past days' records but aren't asked any more.
  final bool isActive;

  factory SanitationItem.fromJson(Map<String, dynamic> json) => SanitationItem(
    id: json['id'] as String,
    name: json['name'] as String,
    position: json['position'] as int? ?? 0,
    isActive: json['is_active'] as bool? ?? true,
  );
}

/// One item ticked (or not) on one day.
class SanitationCheck {
  const SanitationCheck({
    required this.date,
    required this.itemId,
    required this.done,
    required this.checkedBy,
    this.note,
  });

  final DateTime date;
  final String itemId;
  final bool done;
  final String? note;
  final String checkedBy;

  factory SanitationCheck.fromJson(Map<String, dynamic> json) =>
      SanitationCheck(
        date: DateTime.parse(json['date'] as String),
        itemId: json['item_id'] as String,
        done: json['done'] as bool,
        note: json['note'] as String?,
        checkedBy:
            (json['profiles'] as Map<String, dynamic>?)?['full_name']
                as String? ??
            'Unknown',
      );
}

/// What someone ticks for one item when filling in the checklist.
class SanitationTick {
  const SanitationTick({required this.itemId, required this.done, this.note});

  final String itemId;
  final bool done;
  final String? note;

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'done': done,
    'note': note,
  };
}

/// How a day's checklist went.
enum SanitationDayStatus { complete, issues, notDone }

/// [checks] for one day against the active [items].
SanitationDayStatus sanitationDayStatus(
  List<SanitationItem> items,
  List<SanitationCheck> checks,
) {
  if (checks.isEmpty) return SanitationDayStatus.notDone;
  final active = items.where((item) => item.isActive).map((item) => item.id);
  final done = {
    for (final check in checks)
      if (check.done) check.itemId,
  };
  return active.every(done.contains)
      ? SanitationDayStatus.complete
      : SanitationDayStatus.issues;
}
