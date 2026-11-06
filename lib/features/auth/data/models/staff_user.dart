/// A staff member's role in the current organization, controlling what
/// they can see and do. Roles are per organization: the same person can
/// be an Owner in one and a Cashier in another.
enum StaffRole { owner, admin, manager, cashier, storeKeeper }

extension StaffRoleLabel on StaffRole {
  /// Human-readable label shown in the UI.
  String get label => switch (this) {
    StaffRole.owner => 'Owner',
    StaffRole.admin => 'Admin',
    StaffRole.manager => 'Manager',
    StaffRole.cashier => 'Cashier',
    StaffRole.storeKeeper => 'Store Keeper',
  };
}

/// Permission groupings shared by every screen, mirroring the server-side
/// role checks (an Owner passes every Admin check).
extension StaffRolePermissions on StaffRole {
  /// Owner or Admin: staff management, voids, opening balances, write-offs.
  bool get isAdminLevel => this == StaffRole.owner || this == StaffRole.admin;

  /// Owner, Admin or Manager: catalog, recipes, editing past records.
  bool get canManage => isAdminLevel || this == StaffRole.manager;
}

/// The signed-in person, as a member of the current organization.
class StaffUser {
  const StaffUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.phone,
  });

  final String id;
  final String fullName;
  final StaffRole role;
  final String phone;

  /// Up to two initials for the sidebar avatar, e.g. "Musa Ibrahim" → "MI".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  StaffUser copyWith({String? fullName}) => StaffUser(
    id: id,
    fullName: fullName ?? this.fullName,
    role: role,
    phone: phone,
  );

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: staffRoleFromDb(json['role'] as String),
      phone: json['phone'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': staffRoleToDb(role),
      'phone': phone,
    };
  }
}

/// `tenant_members.role` is a Postgres enum with snake_case values — this maps
/// to/from Dart's camelCase [StaffRole] names.
StaffRole staffRoleFromDb(String value) => switch (value) {
  'owner' => StaffRole.owner,
  'admin' => StaffRole.admin,
  'manager' => StaffRole.manager,
  'cashier' => StaffRole.cashier,
  'store_keeper' => StaffRole.storeKeeper,
  _ => throw ArgumentError('Unknown staff role: $value'),
};

String staffRoleToDb(StaffRole role) => switch (role) {
  StaffRole.owner => 'owner',
  StaffRole.admin => 'admin',
  StaffRole.manager => 'manager',
  StaffRole.cashier => 'cashier',
  StaffRole.storeKeeper => 'store_keeper',
};
