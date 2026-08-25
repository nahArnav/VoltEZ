import 'package:dio/dio.dart';

/// VoltEZ API Service
/// Single Dio instance used by both Driver and Business sides.
///
/// Driver endpoints: /auth/*, /users/*, /chargers/*, /routes/*, /slots, /bookings, /payments, /sessions
/// Business endpoints: /business/*
class ApiService {
  ApiService({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? _defaultBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor(() => _token));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[API] $obj'),
    ));
  }

  // ─── Configure this for your backend ───
  static const String _defaultBaseUrl = 'http://localhost:3000/api';

  late final Dio _dio;

  Dio get dio => _dio;

  // ─── Token Management ───

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  // ─── Driver APIs ───

  // Auth
  Future<Response> login(String email, String password) =>
      _dio.post('/auth/login', data: {'email': email, 'password': password});

  Future<Response> signup(String name, String email, String password) =>
      _dio.post('/auth/signup', data: {
        'name': name,
        'email': email,
        'password': password,
      });

  // User
  Future<Response> getMe() => _dio.get('/users/me');

  // Chargers
  Future<Response> getNearbyChargers({
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) =>
      _dio.get('/chargers/nearby', queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radiusKm,
      });

  Future<Response> getChargerById(String id) =>
      _dio.get('/chargers/$id');

  // Recommendations (legacy — kept for backward compat)
  Future<Response> getRecommendations({
    required double lat,
    required double lng,
    double batteryPercent = 80,
    String preference = 'balanced',
  }) =>
      _dio.post('/routes/recommend', data: {
        'lat': lat,
        'lng': lng,
        'batteryPercent': batteryPercent,
        'preference': preference,
      });

  /// Full route-aware recommendation.
  ///
  /// POST /routes/recommendations
  /// Sends origin/destination coordinates, vehicle specs, current SOC,
  /// reserve SOC, and the driver's preference. Returns a list of
  /// recommended charging stops ranked by the backend AI.
  Future<Response> getRouteRecommendations({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String vehicleMake,
    required String vehicleModel,
    required double batteryCapacityKwh,
    required String connectorType,
    required double currentSOC,
    required double reserveSOC,
    required String preference,
    String? originName,
    String? destinationName,
  }) =>
      _dio.post('/routes/recommendations', data: {
        'origin': {
          'lat': originLat,
          'lng': originLng,
          if (originName != null) 'name': originName,
        },
        'destination': {
          'lat': destLat,
          'lng': destLng,
          if (destinationName != null) 'name': destinationName,
        },
        'vehicle': {
          'make': vehicleMake,
          'model': vehicleModel,
          'batteryCapacityKwh': batteryCapacityKwh,
          'connectorType': connectorType,
        },
        'currentSOC': currentSOC,
        'reserveSOC': reserveSOC,
        'preference': preference,
      });

  // Slots
  Future<Response> getSlots(String chargerId, DateTime date) =>
      _dio.get('/slots', queryParameters: {
        'chargerId': chargerId,
        'date': date.toIso8601String(),
      });

  // Bookings (Driver)
  Future<Response> createBooking(Map<String, dynamic> data) =>
      _dio.post('/bookings', data: data);

  Future<Response> getDriverBookings() => _dio.get('/bookings');

  Future<Response> cancelBooking(String id) =>
      _dio.delete('/bookings/$id');

  // Sessions
  Future<Response> checkIn(String bookingId) =>
      _dio.post('/sessions/check-in', data: {'bookingId': bookingId});

  Future<Response> getSessionStatus(String sessionId) =>
      _dio.get('/sessions/$sessionId');

  Future<Response> endSession(String sessionId) =>
      _dio.post('/sessions/$sessionId/end');

  // ─── Business APIs ───

  Future<Response> getBusinessProfile() => _dio.get('/business/profile');

  Future<Response> updateBusinessProfile(Map<String, dynamic> data) =>
      _dio.put('/business/profile', data: data);

  Future<Response> getBusinessChargers() => _dio.get('/business/chargers');

  Future<Response> createCharger(Map<String, dynamic> data) =>
      _dio.post('/business/chargers', data: data);

  Future<Response> updateCharger(String id, Map<String, dynamic> data) =>
      _dio.put('/business/chargers/$id', data: data);

  Future<Response> deleteCharger(String id) =>
      _dio.delete('/business/chargers/$id');

  Future<Response> getAvailability(String chargerId) =>
      _dio.get('/business/availability', queryParameters: {'chargerId': chargerId});

  Future<Response> updateAvailability(String chargerId, List<Map<String, dynamic>> slots) =>
      _dio.put('/business/availability', data: {
        'chargerId': chargerId,
        'slots': slots,
      });

  Future<Response> getBusinessBookings({String? status}) =>
      _dio.get('/business/bookings', queryParameters: {
        if (status != null) 'status': status,
      });

  Future<Response> getAnalytics({String period = 'daily'}) =>
      _dio.get('/business/analytics', queryParameters: {'period': period});
}

/// Adds Bearer token to every request.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenGetter);
  final String? Function() _tokenGetter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenGetter();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
