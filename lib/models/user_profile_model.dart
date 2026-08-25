class StationSpecs {
  final String location;
  final int activeChargers;
  final int totalPowerKw;

  StationSpecs({
    required this.location,
    required this.activeChargers,
    required this.totalPowerKw,
  });

  factory StationSpecs.fromJson(Map<String, dynamic> json) {
    return StationSpecs(
      location: json['location'] as String? ?? 'Shivajinagar, Pune',
      activeChargers: (json['activeChargers'] as num?)?.toInt() ?? 0,
      totalPowerKw: (json['totalPowerKw'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'location': location,
    'activeChargers': activeChargers,
    'totalPowerKw': totalPowerKw,
  };
}

class StationStats {
  final double totalRevenue;
  final double kwhDispensed;
  final int reliabilityPercent;

  StationStats({
    required this.totalRevenue,
    required this.kwhDispensed,
    required this.reliabilityPercent,
  });

  factory StationStats.fromJson(Map<String, dynamic> json) {
    return StationStats(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      kwhDispensed: (json['kwhDispensed'] as num?)?.toDouble() ?? 0.0,
      reliabilityPercent: (json['reliabilityPercent'] as num?)?.toInt() ?? 98,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalRevenue': totalRevenue,
    'kwhDispensed': kwhDispensed,
    'reliabilityPercent': reliabilityPercent,
  };
}

class UserPreferences {
  bool notifications;
  bool location;
  bool darkMode;

  UserPreferences({
    required this.notifications,
    required this.location,
    required this.darkMode,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      notifications: json['notifications'] as bool? ?? true,
      location: json['location'] as bool? ?? true,
      darkMode: json['darkMode'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'notifications': notifications,
    'location': location,
    'darkMode': darkMode,
  };
}

class UserProfile {
  final String id;
  String name;
  String email;
  String phone;
  String businessName;
  final bool isVerifiedHost;
  StationSpecs stationSpecs;
  StationStats stats;
  UserPreferences preferences;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.businessName,
    required this.isVerifiedHost,
    required this.stationSpecs,
    required this.stats,
    required this.preferences,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      isVerifiedHost: json['isVerifiedHost'] as bool? ?? true,
      stationSpecs: StationSpecs.fromJson(
        json['stationSpecs'] as Map<String, dynamic>? ?? {},
      ),
      stats: StationStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? {},
      ),
      preferences: UserPreferences.fromJson(
        json['preferences'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'businessName': businessName,
    'isVerifiedHost': isVerifiedHost,
    'stationSpecs': stationSpecs.toJson(),
    'stats': stats.toJson(),
    'preferences': preferences.toJson(),
  };
}