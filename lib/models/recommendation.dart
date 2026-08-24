/// Recommendation model — AI-generated off-peak pricing / availability recommendation.
class Recommendation {
  const Recommendation({
    required this.id,
    required this.type,
    required this.title,
    required this.recommendedStartAt,
    required this.recommendedEndAt,
    required this.suggestedPrice,
    required this.forecastDemand,
    required this.nearbySupply,
    required this.predictedUtilization,
    required this.confidence,
    required this.reason,
    required this.status,
  });

  final String id;
  final String type;
  final String title;
  final String recommendedStartAt;
  final String recommendedEndAt;
  final double suggestedPrice;
  final int forecastDemand;
  final int nearbySupply;
  final double predictedUtilization;
  final double confidence;
  final String reason;
  final String status;

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
        id: (json['id'] ?? '') as String,
        type: (json['type'] ?? '') as String,
        title: (json['title'] ?? '') as String,
        recommendedStartAt: (json['recommended_start_at'] ?? json['recommendedStartAt'] ?? '') as String,
        recommendedEndAt: (json['recommended_end_at'] ?? json['recommendedEndAt'] ?? '') as String,
        suggestedPrice: (json['suggested_price'] ?? json['suggestedPrice'] ?? 0) as double,
        forecastDemand: (json['forecast_demand'] ?? json['forecastDemand'] ?? 0) as int,
        nearbySupply: (json['nearby_supply'] ?? json['nearbySupply'] ?? 0) as int,
        predictedUtilization: (json['predicted_utilization'] ?? json['predictedUtilization'] ?? 0.0) as double,
        confidence: (json['confidence'] ?? 0.0) as double,
        reason: (json['reason'] ?? '') as String,
        status: (json['status'] ?? 'pending') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'recommended_start_at': recommendedStartAt,
        'recommended_end_at': recommendedEndAt,
        'suggested_price': suggestedPrice,
        'forecast_demand': forecastDemand,
        'nearby_supply': nearbySupply,
        'predicted_utilization': predictedUtilization,
        'confidence': confidence,
        'reason': reason,
        'status': status,
      };

  Recommendation copyWith({String? status}) => Recommendation(
        id: id,
        type: type,
        title: title,
        recommendedStartAt: recommendedStartAt,
        recommendedEndAt: recommendedEndAt,
        suggestedPrice: suggestedPrice,
        forecastDemand: forecastDemand,
        nearbySupply: nearbySupply,
        predictedUtilization: predictedUtilization,
        confidence: confidence,
        reason: reason,
        status: status ?? this.status,
      );
}
