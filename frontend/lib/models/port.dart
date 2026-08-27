/// Port model — represents a single connector port on a charger.
class Port {
  const Port({
    this.id,
    required this.name,
    required this.status,
  });

  final String? id;
  final String name;
  final String status;

  factory Port.fromJson(Map<String, dynamic> json) => Port(
        id: json['id'] as String?,
        name: (json['name'] ?? json['connector_type'] ?? '') as String,
        status: (json['status'] ?? 'offline') as String,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'status': status,
      };

  Port copyWith({String? id, String? name, String? status}) => Port(
        id: id ?? this.id,
        name: name ?? this.name,
        status: status ?? this.status,
      );
}
