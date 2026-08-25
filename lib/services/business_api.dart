import 'dart:async';

/// Single adapter boundary for the business API. Replace [MockBusinessApi] with
/// an HTTP implementation when backend schemas/endpoints are finalized.
abstract class BusinessApi {
  Future<BusinessSnapshot> loadDashboard();
  Future<void> recommendationAction(String id, String action);
  Future<void> cancelBooking(String id);
}

class BusinessSnapshot {
  const BusinessSnapshot({required this.businessName, required this.verification, required this.revenue, required this.utilization, required this.chargers, required this.bookings, required this.recommendations});
  final String businessName, verification; final double revenue, utilization;
  final List<Charger> chargers; final List<Booking> bookings; final List<Recommendation> recommendations;
}
class Charger { const Charger({required this.id,required this.name,required this.power,required this.status,required this.reliability,required this.ports}); final String id,name,status; final int power; final double reliability; final List<Port> ports; }
class Port { const Port({required this.name,required this.status}); final String name,status; }
class Booking { const Booking({required this.id,required this.vehicle,required this.slot,required this.status,required this.amount}); final String id,vehicle,slot,status; final double amount; }
class Recommendation { const Recommendation({required this.id,required this.title,required this.reason,required this.price,required this.confidence}); final String id,title,reason; final double price,confidence; }

class MockBusinessApi implements BusinessApi {
  @override Future<BusinessSnapshot> loadDashboard() async { await Future<void>.delayed(const Duration(milliseconds: 450)); return const BusinessSnapshot(businessName:'ABC Motors',verification:'verified',revenue:18420,utilization:.76,chargers:[Charger(id:'c1',name:'Charger 01',power:60,status:'active',reliability:.98,ports:[Port(name:'CCS 2',status:'available'),Port(name:'Type 2',status:'occupied')]),Charger(id:'c2',name:'Charger 02',power:22,status:'paused',reliability:.87,ports:[Port(name:'Type 2',status:'offline')])],bookings:[Booking(id:'BK-1284',vehicle:'Tata Nexon EV',slot:'10:00 – 11:00',status:'CONFIRMED',amount:420),Booking(id:'BK-1285',vehicle:'MG ZS EV',slot:'12:30 – 13:30',status:'HELD',amount:510)],recommendations:[Recommendation(id:'r1',title:'Raise noon price by 8%',reason:'Demand forecast is high; nearby supply is low.',price:24,confidence:.91)]); }
  @override Future<void> recommendationAction(String id,String action) async { await Future<void>.delayed(const Duration(milliseconds:200)); }
  @override Future<void> cancelBooking(String id) async { await Future<void>.delayed(const Duration(milliseconds:200)); }
}
