enum ConnectorType {
  ccs2('CCS2 (DC Fast)', 'DC'),
  type2('Type 2 (AC)', 'AC'),
  chademo('CHAdeMO (DC)', 'DC'),
  gbt('GB/T (DC)', 'DC');

  final String label;
  final String currentType;
  const ConnectorType(this.label, this.currentType);
}

class ChargerHardware {
  final String id;
  String name;
  String serialNumber;
  ConnectorType connectorType;
  int powerRatingKw;
  String status; // 'available', 'charging', 'offline', 'faulted'
  double totalDispensedKwh;

  ChargerHardware({
    required this.id,
    required this.name,
    required this.serialNumber,
    required this.connectorType,
    required this.powerRatingKw,
    this.status = 'available',
    this.totalDispensedKwh = 0.0,
  });

  ChargerHardware copyWith({
    String? name,
    String? serialNumber,
    ConnectorType? connectorType,
    int? powerRatingKw,
    String? status,
    double? totalDispensedKwh,
  }) {
    return ChargerHardware(
      id: id,
      name: name ?? this.name,
      serialNumber: serialNumber ?? this.serialNumber,
      connectorType: connectorType ?? this.connectorType,
      powerRatingKw: powerRatingKw ?? this.powerRatingKw,
      status: status ?? this.status,
      totalDispensedKwh: totalDispensedKwh ?? this.totalDispensedKwh,
    );
  }
}