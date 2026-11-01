/// A delivery driver who takes stock out on load-outs.
class Driver {
  const Driver({required this.id, required this.name, required this.phone});

  final String id;
  final String name;
  final String phone;

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone};
}
