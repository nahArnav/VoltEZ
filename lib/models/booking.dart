/// Booking model — represents a single charging session booking.
class Booking {
  const Booking({
    required this.id,
    required this.vehicle,
    required this.slot,
    required this.status,
    required this.amount,
    this.customerName,
    this.chargerName,
    this.energy,
    this.date,
  });

  final String id;
  final String vehicle;
  final String slot;
  final String status;
  final double amount;
  final String? customerName;
  final String? chargerName;
  final double? energy;
  final String? date;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: (json['id'] ?? '') as String,
        vehicle: (json['vehicle'] ?? '') as String,
        slot: (json['slot'] ?? json['time'] ?? '') as String,
        status: (json['status'] ?? 'PENDING') as String,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        customerName: json['customer_name'] as String?,
        chargerName: json['charger_name'] as String?,
        energy: (json['energy'] as num?)?.toDouble(),
        date: json['date'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicle': vehicle,
        'slot': slot,
        'status': status,
        'amount': amount,
        if (customerName != null) 'customer_name': customerName,
        if (chargerName != null) 'charger_name': chargerName,
        if (energy != null) 'energy': energy,
        if (date != null) 'date': date,
      };
}
