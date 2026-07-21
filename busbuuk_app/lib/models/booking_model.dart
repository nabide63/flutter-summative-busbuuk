// ticket booking data model
import 'passenger_model.dart';

class BookingModel {
  final String id;
  final String userId;
  final String busId;
  final List<String> seatNumbers;
  final List<PassengerModel> passengers;
  final double totalAmount;
  final DateTime bookingDate;
  final String status; // "pending", "confirmed", "cancelled"
  final String? paymentId;

  // snapshot of the trip details at booking time, so My Bookings doesn't
  // have to re-fetch the bus (and still works even if it changes later)
  final String operatorName;
  final String operatorPhone;
  final String from;
  final String to;
  // departure terminal name (e.g "Nyabugogo"), so the passenger knows where to board
  final String fromTerminal;
  final DateTime departureTime;
  final DateTime arrivalTime;
  // which company owns this, so their admin dashboard can list bookings
  // without having to join through buses/{busId}
  final String companyId;

  BookingModel({
    required this.id,
    required this.userId,
    required this.busId,
    required this.seatNumbers,
    required this.passengers,
    required this.totalAmount,
    required this.bookingDate,
    required this.status,
    this.paymentId,
    required this.operatorName,
    required this.operatorPhone,
    required this.from,
    required this.to,
    required this.fromTerminal,
    required this.departureTime,
    required this.arrivalTime,
    required this.companyId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'busId': busId,
      'seatNumbers': seatNumbers,
      'passengers': passengers.map((p) => p.toMap()).toList(),
      'totalAmount': totalAmount,
      'bookingDate': bookingDate.toIso8601String(),
      'status': status,
      'paymentId': paymentId,
      'operatorName': operatorName,
      'operatorPhone': operatorPhone,
      'from': from,
      'to': to,
      'fromTerminal': fromTerminal,
      'departureTime': departureTime.toIso8601String(),
      'arrivalTime': arrivalTime.toIso8601String(),
      'companyId': companyId,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      busId: map['busId'] as String,
      seatNumbers: List<String>.from(map['seatNumbers'] as List),
      passengers: (map['passengers'] as List)
          .map((p) => PassengerModel.fromMap(p as Map<String, dynamic>))
          .toList(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      bookingDate: DateTime.parse(map['bookingDate'] as String),
      status: map['status'] as String,
      paymentId: map['paymentId'] as String?,
      operatorName: map['operatorName'] as String,
      operatorPhone: map['operatorPhone'] as String? ?? '',
      from: map['from'] as String,
      to: map['to'] as String,
      // older booking docs predate this field - fall back to empty rather
      // than crashing My Bookings for tickets created before it existed
      fromTerminal: map['fromTerminal'] as String? ?? '',
      departureTime: DateTime.parse(map['departureTime'] as String),
      arrivalTime: DateTime.parse(map['arrivalTime'] as String),
      companyId: map['companyId'] as String? ?? '',
    );
  }
}