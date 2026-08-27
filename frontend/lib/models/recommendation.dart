class Recommendation {
  final String id;
  final String type;
  final String date;
  final String start;
  final String end;
  double price;
  final int forecast;
  final int nearby;
  final double utilization;
  final double confidence;
  final String reason;
  String status;

  Recommendation({
    required this.id,
    required this.type,
    required this.date,
    required this.start,
    required this.end,
    required this.price,
    required this.forecast,
    required this.nearby,
    required this.utilization,
    required this.confidence,
    required this.reason,
    required this.status,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      date: json['date'] as String? ?? '',
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      forecast: (json['forecast'] as num?)?.toInt() ?? 0,
      nearby: (json['nearby'] as num?)?.toInt() ?? 0,
      utilization: (json['utilization'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'date': date,
    'start': start,
    'end': end,
    'price': price,
    'forecast': forecast,
    'nearby': nearby,
    'utilization': utilization,
    'confidence': confidence,
    'reason': reason,
    'status': status,
  };
}