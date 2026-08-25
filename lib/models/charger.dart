import 'port.dart';

/// Charger model — represents a single charging unit with its ports.
class Charger {
  const Charger({
    required this.id,
    required this.name,
    required this.power,
    required this.status,
    required this.reliability,
    required this.ports,
  });

  final String id;
  final String name;
  final int power;
  final String status;
  final double reliability;
  final List<Port> ports;

  factory Charger.fromJson(Map<String, dynamic> json) => Charger(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        power: (json['power'] as num?)?.toInt() ?? 0,
        status: (json['status'] ?? 'offline') as String,
        reliability: (json['reliability'] as num?)?.toDouble() ?? 0.0,
        ports: (json['ports'] as List<dynamic>?)
                ?.map((p) => Port.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'power': power,
        'status': status,
        'reliability': reliability,
        'ports': ports.map((p) => p.toJson()).toList(),
      };

  Charger copyWith({
    String? id,
    String? name,
    int? power,
    String? status,
    double? reliability,
    List<Port>? ports,
  }) =>
      Charger(
        id: id ?? this.id,
        name: name ?? this.name,
        power: power ?? this.power,
        status: status ?? this.status,
        reliability: reliability ?? this.reliability,
        ports: ports ?? this.ports,
      );
}
