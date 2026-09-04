// ignore_for_file: use_null_aware_elements, unintended_html_in_doc_comment
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor(() => _token));
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode != 401 ||
              error.requestOptions.extra['voltez_retried'] == true ||
              _refreshToken == null) {
            handler.next(error);
            return;
          }
          try {
            final refreshClient = Dio(
              BaseOptions(baseUrl: _dio.options.baseUrl),
            );
            final response = await refreshClient.post(
              '/auth/refresh',
              data: {'refresh_token': _refreshToken},
            );
            final data = response.data as Map<String, dynamic>;
            final access = data['access_token'] as String;
            final refresh = data['refresh_token'] as String? ?? _refreshToken!;
            setToken(access);
            setRefreshToken(refresh);
            const storage = FlutterSecureStorage();
            await storage.write(key: 'voltez_access_token', value: access);
            await storage.write(key: 'voltez_refresh_token', value: refresh);
            final request = error.requestOptions;
            request.extra['voltez_retried'] = true;
            request.headers['Authorization'] = 'Bearer $access';
            handler.resolve(await _dio.fetch(request));
          } catch (_) {
            setToken(null);
            setRefreshToken(null);
            const storage = FlutterSecureStorage();
            await storage.delete(key: 'voltez_access_token');
            await storage.delete(key: 'voltez_refresh_token');
            handler.next(error);
          }
        },
      ),
    );
    _dio.interceptors.add(_ErrorInterceptor());
  }

  // ─── Backend base URL ───
  // Backend serves under /api/v1
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://voltez-sb0w.onrender.com/api/v1',
  );

  late final Dio _dio;

  Dio get dio => _dio;

  String get baseUrl => _dio.options.baseUrl;

  void setBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }

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
    String role = 'driver',
    String? phone,
  }) => _dio.post(
    '/auth/register',
    data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role.toLowerCase(),
      if (phone != null) 'phone': phone,
    },
  );

  /// POST /auth/login
  /// OAuth2 form body: { username: email, password }
  /// Returns: { access_token, refresh_token, token_type: "bearer" }
  Future<Response> login(String email, String password) => _dio.post(
    '/auth/login',
    data: {'username': email, 'password': password},
    options: Options(contentType: Headers.formUrlEncodedContentType),
  );

  /// POST /auth/refresh
  /// Body: { refresh_token }
  /// Returns: { access_token, refresh_token, token_type: "bearer" }
  Future<Response> refreshTokens(String refreshToken) =>
      _dio.post('/auth/refresh', data: {'refresh_token': refreshToken});

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

  /// GET /users/me/notifications
  Future<Response> getNotifications() => _dio.get('/users/me/notifications');

  /// PATCH /users/me/notifications/{id}
  Future<Response> markNotificationRead(String id) =>
      _dio.patch('/users/me/notifications/$id', data: {'status': 'read'});

  // ═══════════════════════════════════════════════════════════════════════════
  // Vehicles — CRUD under /vehicles
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /vehicles
  /// Body: { make, model, vehicle_class, battery_kwh, connector_type_ids: [1], max_ac_kw?, max_dc_kw?, estimated_range_km? }
  Future<Response> createVehicle(Map<String, dynamic> data) =>
      _dio.post('/vehicles/', data: data);

  /// GET /vehicles
  Future<Response> getVehicles() => _dio.get('/vehicles/');

  /// GET /vehicles/{id}
  Future<Response> getVehicle(String id) => _dio.get('/vehicles/$id');

  /// PATCH /vehicles/{id}
  Future<Response> updateVehicle(String id, Map<String, dynamic> data) =>
      _dio.patch('/vehicles/$id', data: data);

  /// DELETE /vehicles/{id}
  Future<Response> deleteVehicle(String id) => _dio.delete('/vehicles/$id');

  // ═══════════════════════════════════════════════════════════════════════════
  // Chargers — GET /chargers/nearby, GET /chargers/{id}
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /chargers/nearby?latitude=...&longitude=...&radius_meters=5000
  /// Returns: List<ChargerResponse> with nested ports
  Future<Response> getNearbyChargers({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
  }) => _dio.get(
    '/chargers/nearby',
    queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
    },
  );

  /// GET /locations/search?q=...&limit=...
  /// The backend normalises provider results and returns real coordinates.
  Future<Response> searchLocations(String query, {int limit = 5}) => _dio.get(
    '/locations/search',
    queryParameters: {'q': query, 'limit': limit},
  );

  /// GET /chargers/{id}
  /// Returns: ChargerResponse with nested ports
  Future<Response> getChargerById(String id) => _dio.get('/chargers/$id');

  // ═══════════════════════════════════════════════════════════════════════════
  // Recommendations — POST /recommendations/
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /recommendations/
  Future<Response> getRouteRecommendations({
    required double originLat,
    required double originLng,
    double? destinationLat,
    double? destinationLng,
    required String vehicleId,
    required double currentSOC,
    required double targetSOC,
    required double reserveSOC,
    required String preference,
    double? routeDistanceKm,
    int? routeDurationMinutes,
    String? routePolyline,
    double radiusMeters = 25000,
  }) => _dio.post(
    '/recommendations/',
    data: {
      'latitude': originLat,
      'longitude': originLng,
      if (destinationLat != null && destinationLng != null) ...{
        'destination_latitude': destinationLat,
        'destination_longitude': destinationLng,
      },
      'radius_meters': radiusMeters,
      'vehicle_id': vehicleId,
      'current_soc': currentSOC / 100,
      'target_soc': targetSOC / 100,
      'reserve_soc': reserveSOC / 100,
      'preferences': {'mode': preference},
      if (routeDistanceKm != null) 'route_distance_km': routeDistanceKm,
      if (routeDurationMinutes != null)
        'route_duration_minutes': routeDurationMinutes,
      if (routePolyline != null) 'route_polyline': routePolyline,
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Bookings — POST /bookings/, POST /bookings/{id}/cancel, GET /bookings
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /bookings/
  /// Body: { port_id: int, start_at: datetime, end_at: datetime, vehicle_id?: int, idempotency_key?: str }
  /// Returns: BookingResponse
  Future<Response> createBooking(Map<String, dynamic> data) =>
      _dio.post('/bookings/', data: data);

  /// POST /bookings/{id}/confirm
  /// Confirm a booking after payment verification.
  Future<Response> confirmBooking(String bookingId) =>
      _dio.post('/bookings/$bookingId/confirm');

  /// POST /bookings/{id}/cancel
  /// Returns: BookingResponse
  Future<Response> cancelBooking(String bookingId) =>
      _dio.post('/bookings/$bookingId/cancel');

  /// GET /bookings
  /// Returns: List<BookingResponse>
  Future<Response> getDriverBookings() => _dio.get('/bookings/');

  /// GET /bookings/{id}
  Future<Response> getBooking(String bookingId) =>
      _dio.get('/bookings/$bookingId');

  // ═══════════════════════════════════════════════════════════════════════════
  // Payments — POST /payments/create-order, POST /payments/verify
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /payments/create-order
  Future<Response> createPaymentOrder(Map<String, dynamic> data) =>
      _dio.post('/payments/create-order', data: data);

  /// POST /payments/verify
  Future<Response> verifyPayment(Map<String, dynamic> data) =>
      _dio.post('/payments/verify', data: data);

  /// POST /payments/stripe/verify
  Future<Response> verifyStripePayment(Map<String, dynamic> data) =>
      _dio.post('/payments/stripe/verify', data: data);

  // ═══════════════════════════════════════════════════════════════════════════
  // Sessions — POST /sessions/check-in, POST /sessions/{id}/start,
  //           POST /sessions/{id}/complete, POST /sessions/{id}/report-issue
  // ═══════════════════════════════════════════════════════════════════════════

  /// POST /sessions/check-in
  /// Body: { booking_id: int }
  /// Returns: ChargingSessionResponse
  Future<Response> checkIn(String bookingId) =>
      _dio.post('/sessions/check-in', data: {'booking_id': bookingId});

  /// POST /sessions/{id}/start
  /// Mark charging has begun (plug connected, power flowing).
  /// Returns: ChargingSessionResponse
  Future<Response> startCharging(String sessionId) =>
      _dio.post('/sessions/$sessionId/start');

  /// POST /sessions/{id}/complete
  /// Body: { energy_kwh: float }
  /// Returns: ChargingSessionResponse
  Future<Response> completeSession(String sessionId, double energyKwh) => _dio
      .post('/sessions/$sessionId/complete', data: {'energy_kwh': energyKwh});

  Future<Response> getSession(String sessionId) =>
      _dio.get('/sessions/$sessionId');

  Future<Response> getSessions() => _dio.get('/sessions/');

  Future<Response> submitSessionRating(
    String sessionId,
    Map<String, dynamic> data,
  ) => _dio.post('/sessions/$sessionId/rating', data: data);

  /// POST /sessions/{id}/report-issue
  Future<Response> reportSessionIssue(
    String sessionId,
    Map<String, dynamic> data,
  ) => _dio.post('/sessions/$sessionId/report-issue', data: data);

  // ═══════════════════════════════════════════════════════════════════════════
  // Business APIs
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Response> getBusinessProfile() => _dio.get('/businesses/me');

  Future<Response> createBusiness(Map<String, dynamic> data) =>
      _dio.post('/businesses/', data: data);

  Future<Response> updateBusinessProfile(
    String id,
    Map<String, dynamic> data,
  ) => _dio.patch('/businesses/$id', data: data);

  Future<Response> getBusinessChargers(String businessId) =>
      _dio.get('/chargers/', queryParameters: {'business_id': businessId});

  Future<Response> createCharger(Map<String, dynamic> data) =>
      _dio.post('/chargers/', data: data);

  Future<Response> createChargerPort(
    String chargerId,
    Map<String, dynamic> data,
  ) => _dio.post('/chargers/$chargerId/ports', data: data);

  Future<Response> updateChargerPort(
    String portId,
    Map<String, dynamic> data,
  ) => _dio.patch('/chargers/ports/$portId', data: data);

  Future<Response> updateCharger(String id, Map<String, dynamic> data) =>
      _dio.patch('/chargers/$id', data: data);

  Future<Response> deleteCharger(String id) => _dio.delete('/chargers/$id');

  /// GET /ports/{id}/availability
  Future<Response> getPortAvailability(String portId) =>
      _dio.get('/availability/port/$portId');

  Future<Response> getPortSlots(String portId, DateTime day) => _dio.get(
    '/availability/port/$portId/slots',
    queryParameters: {
      'day':
          '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}',
    },
  );

  /// POST /ports/{id}/availability
  Future<Response> createAvailabilityWindow(
    String portId,
    Map<String, dynamic> data,
  ) => _dio.post('/availability/', data: {'charger_port_id': portId, ...data});

  /// GET /businesses/{id}/analytics
  Future<Response> getAnalytics(String businessId) =>
      _dio.get('/analytics/businesses/$businessId/recommendations');

  Future<Response> getBusinessBookings(String businessId) =>
      _dio.get('/businesses/$businessId/bookings');

  Future<Response> cancelBusinessBooking(String businessId, String bookingId) =>
      _dio.post('/businesses/$businessId/bookings/$bookingId/cancel');

  Future<Response> verifyCashBookingOtp(
    String businessId,
    String bookingId,
    String code,
  ) => _dio.post(
    '/businesses/$businessId/bookings/$bookingId/cash-verify',
    data: {'code': code},
  );

  Future<Response> getBusinessDashboard(String businessId) =>
      _dio.get('/analytics/businesses/$businessId/dashboard');

  // ═══════════════════════════════════════════════════════════════════════════
  // KYC APIs
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Response> getUserKyc() => _dio.get('/users/me/kyc');

  Future<Response> submitUserKyc(Map<String, dynamic> data) =>
      _dio.post('/users/me/kyc', data: data);

  Future<Response> getBusinessKyc(String businessId) =>
      _dio.get('/businesses/$businessId/kyc');

  Future<Response> submitBusinessKyc(
    String businessId,
    Map<String, dynamic> data,
  ) => _dio.post('/businesses/$businessId/kyc', data: data);

  // ═══════════════════════════════════════════════════════════════════════════
  // Routes & Sponsor APIs
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Response> computeRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) => _dio.get(
    '/locations/route',
    queryParameters: {
      'origin_lat': originLat,
      'origin_lng': originLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
    },
  );

  Future<Response> getSponsorTariffs([String state = 'Maharashtra']) =>
      _dio.get('/sponsors/tariffs', queryParameters: {'state': state});

  Future<Response> askSponsorCopilot(Map<String, dynamic> data) =>
      _dio.post('/sponsors/copilot', data: data);

  Future<Response> getSponsorEcosystem() => _dio.get('/sponsors/ecosystem');
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
      final detail = data['detail'];
      final message =
          data['message'] as String? ??
          (detail is String ? detail : 'An error occurred');
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
