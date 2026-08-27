/// Revenue analytics data returned by `GET /businesses/me/analytics/revenue`.
class RevenueAnalytics {
  const RevenueAnalytics({
    required this.totalRevenue,
    required this.totalSessions,
    required this.totalEnergy,
    required this.avgSessionDuration,
    required this.peakHour,
    required this.dailyBreakdown,
  });

  final double totalRevenue;
  final int totalSessions;
  final double totalEnergy;
  final double avgSessionDuration;
  final String peakHour;
  final List<DailyRevenue> dailyBreakdown;

  factory RevenueAnalytics.fromJson(Map<String, dynamic> json) =>
      RevenueAnalytics(
        totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
        totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
        totalEnergy: (json['total_energy'] as num?)?.toDouble() ?? 0.0,
        avgSessionDuration: (json['avg_session_duration'] as num?)?.toDouble() ?? 0.0,
        peakHour: (json['peak_hour'] ?? '') as String,
        dailyBreakdown: (json['daily_breakdown'] as List<dynamic>?)
                ?.map((d) => DailyRevenue.fromJson(d as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Single day revenue entry.
class DailyRevenue {
  const DailyRevenue({
    required this.date,
    required this.revenue,
    required this.sessions,
  });

  final String date;
  final double revenue;
  final int sessions;

  factory DailyRevenue.fromJson(Map<String, dynamic> json) => DailyRevenue(
        date: (json['date'] ?? '') as String,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      );
}

/// Autonomous AI insight from the Lyzr agent.
class AiInsight {
  const AiInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.severity,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String type; // 'weekly_digest', 'anomaly', 'milestone'
  final String title;
  final String summary;
  final String severity; // 'info', 'warning', 'critical'
  final String createdAt;
  final bool isRead;

  factory AiInsight.fromJson(Map<String, dynamic> json) => AiInsight(
        id: (json['id'] ?? '') as String,
        type: (json['type'] ?? 'info') as String,
        title: (json['title'] ?? '') as String,
        summary: (json['summary'] ?? '') as String,
        severity: (json['severity'] ?? 'info') as String,
        createdAt: (json['created_at'] ?? '') as String,
        isRead: (json['is_read'] as bool?) ?? false,
      );
}
