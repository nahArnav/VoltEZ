// ignore_for_file: use_null_aware_elements, unintended_html_in_doc_comment
import 'package:dio/dio.dart';

/// VoltEZ API Service
/// Single Dio instance used by both Driver and Business sides.
///
/// Backend API prefix: /api/v1
/// All endpoints match the actual FastAPI backend contracts.
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
    _dio.interceptors.add(_ErrorInterceptor());
  }

  // ─── Backend base URL ───
  // Backend serves under /api/v1
  static const String _defaultBaseUrl = 'http://localhost:3000/api/v1';

  late final Dio _dio;

  Dio get dio => _dio;

  // ─── Token Management ───

  String? _token;
  String? _refreshToken;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  void setRefreshToken(String? refreshToken) {
    _refreshToken = refreshToken;
  }

  String? get refreshToken => _refreshToken;

  // ═══════════════════════════════════════════════════════════════════════════
  // Auth — POST /auth/register, /auth/login, /auth/refresh, /auth/logout
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /auth/register
  /// Body: { name, email, password, role: "DRIVER"|"OWNER", phone? }
  Future<Response> register({
    required String name,
    required String email,
    required String password,
    String role = 'DRIVER',
    String? phone,
  }) =>
      _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (phone != null) 'phone': phone,
      });

  /// POST /auth/login
  /// Body: { email, password }
  /// Returns: { access_token, refresh_token, token_type: "bearer" }
  Future<Response> login(String email, String password) =>
      _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

  /// POST /auth/refresh
  /// Body: { refresh_token }
  /// Returns: { access_token, refresh_token, token_type: "bearer" }
  Future<Response> refreshTokens(String refreshToken) =>
      _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

  /// POST /auth/logout
  Future<Response> logout() => _dio.post('/auth/logout');

  // ═══════════════════════════════════════════════════════════════════════════
  // Users — GET /users/me, PATCH /users/me
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /users/me
  /// Returns: { id: int, name, email, phone?, role, verification_status, created_at }
  Future<Response> getMe() => _dio.get('/users/me');

  /// PATCH /users/me
  /// Body: { name?, phone? }
  Future<Response> updateMe(Map<String, dynamic> data) =>
      _dio.patch('/users/me', data: data);

  // ═══════════════════════════════════════════════════════════════════════════
  // Vehicles — CRUD under /vehicles
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /vehicles
  /// Body: { make, model, battery_kwh, connector_types: ["CCS2"], max_ac_kw?, max_dc_kw?, estimated_range_km? }
  Future<Response> createVehicle(Map<String, dynamic> data) =>
      _dio.post('/vehicles', data: data);

  /// GET /vehicles
  Future<Response> getVehicles() => _dio.get('/vehicles');

  /// GET /vehicles/{id}
  Future<Response> getVehicle(int id) => _dio.get('/vehicles/$id');

  /// PATCH /vehicles/{id}
  Future<Response> updateVehicle(int id, Map<String, dynamic> data) =>
      _dio.patch('/vehicles/$id', data: data);

  /// DELETE /vehicles/{id}
  Future<Response> deleteVehicle(int id) => _dio.delete('/vehicles/$id');

  // ═══════════════════════════════════════════════════════════════════════════
  // Chargers — GET /chargers/nearby, GET /chargers/{id}
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /chargers/nearby?latitude=...&longitude=...&radius_meters=5000
  /// Returns: List<ChargerResponse> with nested ports
  Future<Response> getNearbyChargers({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) =>
      _dio.get('/chargers/nearby', queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
      });

  /// GET /chargers/{id}
  /// Returns: ChargerResponse with nested ports
  Future<Response> getChargerById(int id) => _dio.get('/chargers/$id');

  // ═══════════════════════════════════════════════════════════════════════════
  // Routes & Recommendations — POST /routes/recommendations
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /routes/recommendations
  /// Full route-aware recommendation request.
  /// NOTE: Backend endpoint is in the API contract but may not be implemented yet.
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
          'battery_kwh': batteryCapacityKwh,
          'connector_types': [connectorType],
        },
        'current_soc': currentSOC,
        'reserve_soc': reserveSOC,
        'preference': preference,
      });

  // ═══════════════════════════════════════════════════════════════════════════
  // Bookings — POST /bookings/, POST /bookings/{id}/cancel, GET /bookings
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /bookings/
  /// Body: { port_id: int, start_at: datetime, end_at: datetime, vehicle_id?: int, idempotency_key?: str }
  /// Returns: BookingResponse
  Future<Response> createBooking(Map<String, dynamic> data) =>
      _dio.post('/bookings', data: data);

  /// POST /bookings/{id}/confirm
  /// Confirm a booking after payment verification.
  Future<Response> confirmBooking(int bookingId) =>
      _dio.post('/bookings/$bookingId/confirm');

  /// POST /bookings/{id}/cancel
  /// Returns: BookingResponse
  Future<Response> cancelBooking(int bookingId) =>
      _dio.post('/bookings/$bookingId/cancel');

  /// GET /bookings
  /// Returns: List<BookingResponse>
  Future<Response> getDriverBookings() => _dio.get('/bookings');

  /// GET /bookings/{id}
  Future<Response> getBooking(int bookingId) => _dio.get('/bookings/$bookingId');

  // ═══════════════════════════════════════════════════════════════════════════
  // Payments — POST /payments/create-order, POST /payments/verify
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /payments/create-order
  Future<Response> createPaymentOrder(Map<String, dynamic> data) =>
      _dio.post('/payments/create-order', data: data);

  /// POST /payments/verify
  Future<Response> verifyPayment(Map<String, dynamic> data) =>
      _dio.post('/payments/verify', data: data);

  // ═══════════════════════════════════════════════════════════════════════════
  // Sessions — POST /sessions/check-in, POST /sessions/{id}/start,
  //           POST /sessions/{id}/complete, POST /sessions/{id}/report-issue
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /sessions/check-in
  /// Body: { booking_id: int }
  /// Returns: ChargingSessionResponse
  Future<Response> checkIn(int bookingId) =>
      _dio.post('/sessions/check-in', data: {'booking_id': bookingId});

  /// POST /sessions/{id}/start
  /// Mark charging has begun (plug connected, power flowing).
  /// Returns: ChargingSessionResponse
  Future<Response> startCharging(int sessionId) =>
      _dio.post('/sessions/$sessionId/start');

  /// POST /sessions/{id}/complete
  /// Body: { energy_kwh: float }
  /// Returns: ChargingSessionResponse
  Future<Response> completeSession(int sessionId, double energyKwh) =>
      _dio.post('/sessions/$sessionId/complete', data: {
        'energy_kwh': energyKwh,
      });

  /// POST /sessions/{id}/report-issue
  Future<Response> reportSessionIssue(int sessionId, Map<String, dynamic> data) =>
      _dio.post('/sessions/$sessionId/report-issue', data: data);

  // ═══════════════════════════════════════════════════════════════════════════
  // Business APIs
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Response> getBusinessProfile() => _dio.get('/businesses/me');

  Future<Response> updateBusinessProfile(int id, Map<String, dynamic> data) =>
      _dio.patch('/businesses/$id', data: data);

  Future<Response> getBusinessChargers(int businessId) =>
      _dio.get('/chargers', queryParameters: {'business_id': businessId});

  Future<Response> createCharger(Map<String, dynamic> data) =>
      _dio.post('/chargers', data: data);

  Future<Response> updateCharger(int id, Map<String, dynamic> data) =>
      _dio.patch('/chargers/$id', data: data);

  Future<Response> deleteCharger(int id) => _dio.delete('/chargers/$id');

  /// GET /ports/{id}/availability
  Future<Response> getPortAvailability(int portId) =>
      _dio.get('/ports/$portId/availability');

  /// POST /ports/{id}/availability
  Future<Response> createAvailabilityWindow(int portId, Map<String, dynamic> data) =>
      _dio.post('/ports/$portId/availability', data: data);

  /// GET /businesses/{id}/analytics
  Future<Response> getAnalytics(int businessId) =>
      _dio.get('/businesses/$businessId/analytics');
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

/// Standardized error handling for backend error responses.
/// Backend returns: { code, message, request_id, field_errors? }
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null && response.data is Map) {
      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String? ?? 'UNKNOWN_ERROR';
      final message = data['message'] as String? ?? 'An error occurred';
      final fieldErrors = data['field_errors'] as List?;

      // Attach structured error info for callers to parse
      err = DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: ApiError(
          code: code,
          message: message,
          statusCode: response.statusCode ?? 500,
          fieldErrors: fieldErrors?.cast<Map<String, dynamic>>(),
        ),
      );
    }
    handler.next(err);
  }
}

/// Parsed backend error structure.
class ApiError implements Exception {
  ApiError({
    required this.code,
    required this.message,
    required this.statusCode,
    this.fieldErrors,
  });

  final String code;
  final String message;
  final int statusCode;
  final List<Map<String, dynamic>>? fieldErrors;

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;
  bool get isValidationError => statusCode == 422;

  @override
  String toString() => 'ApiError($code: $message)';
}
