import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_service.dart';

class BusinessProvider extends ChangeNotifier {
  BusinessProvider({required ApiService api}) : _api = api;

  final ApiService _api;

  bool isLoading = false;
  String? errorMessage;
  Map<String, dynamic>? business;
  List<Map<String, dynamic>> chargers = const [];
  List<Map<String, dynamic>> bookings = const [];
  List<Map<String, dynamic>> recommendations = const [];
  Map<String, dynamic> dashboard = const {};

  bool get needsOnboarding => !isLoading && business == null;
  String? get businessId => business?['id']?.toString();

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.getBusinessProfile();
      business = Map<String, dynamic>.from(response.data as Map);
      await _loadBusinessData();
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        business = null;
        chargers = const [];
        bookings = const [];
        recommendations = const [];
        dashboard = const {};
      } else {
        errorMessage = _message(error);
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadBusinessData() async {
    final id = businessId;
    if (id == null) return;
    final responses = await Future.wait([
      _api.getBusinessChargers(id),
      _api.getBusinessBookings(id),
      _api.getAnalytics(id),
      _api.getBusinessDashboard(id),
    ]);
    chargers = _maps(responses[0].data);
    bookings = _maps(responses[1].data);
    recommendations = _maps(responses[2].data);
    dashboard = Map<String, dynamic>.from(responses[3].data as Map);
  }

  Future<bool> createBusiness({
    required String name,
    required String category,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    return _mutate(() async {
      final response = await _api.createBusiness({
        'name': name,
        'category': category,
        'address_text': address,
        'latitude': latitude,
        'longitude': longitude,
      });
      business = Map<String, dynamic>.from(response.data as Map);
      await _loadBusinessData();
    });
  }

  Future<bool> createCharger({
    required String name,
    required String chargerType,
    required double powerKw,
    required double pricePerKwh,
    required double latitude,
    required double longitude,
  }) async {
    final id = businessId;
    if (id == null) return false;
    return _mutate(() async {
      await _api.createCharger({
        'business_id': id,
        'name': name,
        'charger_type': chargerType,
        'power_kw': powerKw,
        'price_per_kwh': pricePerKwh,
        'status': 'available',
        'latitude': latitude,
        'longitude': longitude,
      });
      await _loadBusinessData();
    });
  }

  Future<bool> createPort({
    required String chargerId,
    required int connectorTypeId,
    required int portNumber,
    required double maxPowerKw,
  }) async {
    return _mutate(() async {
      await _api.createChargerPort(chargerId, {
        'connector_type_id': connectorTypeId,
        'port_number': portNumber,
        'max_power_kw': maxPowerKw,
        'is_active': true,
      });
      await _loadBusinessData();
    });
  }

  Future<bool> setChargerStatus(String chargerId, String status) async {
    return _mutate(() async {
      await _api.updateCharger(chargerId, {'status': status});
      await _loadBusinessData();
    });
  }

  Future<bool> cancelBooking(String bookingId) async {
    final id = businessId;
    if (id == null) return false;
    return _mutate(() async {
      await _api.cancelBusinessBooking(id, bookingId);
      await _loadBusinessData();
    });
  }

  Future<bool> submitKyc({
    required String businessId,
    String? gstin,
    String? panNumber,
    String? electricityMeterId,
    String? payoutUpiId,
  }) async {
    return _mutate(() async {
      final payload = <String, dynamic>{};
      if (gstin != null) payload['gstin'] = gstin;
      if (panNumber != null) payload['pan_number'] = panNumber;
      if (electricityMeterId != null) payload['electricity_meter_id'] = electricityMeterId;
      if (payoutUpiId != null) payload['payout_upi_id'] = payoutUpiId;
      await _api.submitBusinessKyc(businessId, payload);
      await _loadBusinessData();
    });
  }



  Future<bool> createAvailability({
    required String portId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    return _mutate(() async {
      await _api.createAvailabilityWindow(portId, {
        'day_of_week': dayOfWeek,
        'start_local_time': startTime,
        'end_local_time': endTime,
        'is_unavailable': false,
      });
      await _loadBusinessData();
    });
  }

  Future<bool> updateBusiness({
    required String name,
    required String category,
    required String address,
  }) async {
    final id = businessId;
    if (id == null) return false;
    return _mutate(() async {
      final response = await _api.updateBusinessProfile(id, {
        'name': name,
        'category': category,
        'address_text': address,
      });
      business = Map<String, dynamic>.from(response.data as Map);
    });
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on DioException catch (error) {
      errorMessage = _message(error);
      return false;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  static List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  static String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    return error.error?.toString() ?? error.message ?? 'Request failed';
  }
}
