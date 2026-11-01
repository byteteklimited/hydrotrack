/// A delivery vehicle, identified by its display name (which may already
/// include the plate number, e.g. "Blue Dyna — ABJ 342 XA").
class Vehicle {
  const Vehicle({required this.id, required this.name});

  final String id;
  final String name;

  factory Vehicle.fromJson(Map<String, dynamic> json) =>
      Vehicle(id: json['id'] as String, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
