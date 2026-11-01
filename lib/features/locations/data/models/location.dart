enum LocationKind {
  factory('Factory'),
  depot('Depot');

  const LocationKind(this.label);

  final String label;

  static LocationKind fromDb(String? value) =>
      value == 'depot' ? depot : factory;
}

/// A factory (produces and sells) or depot (holds and sells) of the
/// organization. Stock, sales, production, expenses, cash and customers
/// are kept per location.
class Location {
  const Location({
    required this.id,
    required this.name,
    required this.kind,
    this.isActive = true,
    this.isMain = false,
  });

  final String id;
  final String name;
  final LocationKind kind;
  final bool isActive;

  /// The first location; where records go when none is chosen.
  final bool isMain;

  @override
  bool operator ==(Object other) => other is Location && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: LocationKind.fromDb(json['kind'] as String?),
    isActive: json['is_active'] as bool? ?? true,
    isMain: json['is_main'] as bool? ?? false,
  );
}
