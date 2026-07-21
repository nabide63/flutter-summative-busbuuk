// bus trip/route data model
class BusModel {
  final String id;
  final String operatorName;
  // contact number for the operator's terminal desk - shown on the
  // passenger's ticket so they can call for a followup after booking
  final String operatorPhone;
  final String from;
  final String to;
  final String fromTerminal; // e.g "Nyabugogo Bus Terminal" - required so passengers always know where to board
  final String? toTerminal;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final double price;
  final int totalSeats;
  final int availableSeats;
  final String busType; // e.g "Standard", "VIP"
  final double? originalPrice; // set when this trip is discounted, for the "SALE" badge
  final String companyId; // owning bus company - onboarders are scoped to this
  final List<String> busServices; // e.g "WiFi", "AC", "Charging"

  BusModel({
    required this.id,
    required this.operatorName,
    required this.operatorPhone,
    required this.from,
    required this.to,
    required this.fromTerminal,
    this.toTerminal,
    required this.departureTime,
    required this.arrivalTime,
    required this.price,
    required this.totalSeats,
    required this.availableSeats,
    required this.busType,
    this.originalPrice,
    required this.companyId,
    this.busServices = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operatorName': operatorName,
      'operatorPhone': operatorPhone,
      'from': from,
      'to': to,
      'fromTerminal': fromTerminal,
      if (toTerminal != null) 'toTerminal': toTerminal,
      'departureTime': departureTime.toIso8601String(),
      'arrivalTime': arrivalTime.toIso8601String(),
      'price': price,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'busType': busType,
      if (originalPrice != null) 'originalPrice': originalPrice,
      'companyId': companyId,
      'busServices': busServices,
    };
  }

  factory BusModel.fromMap(Map<String, dynamic> map) {
    return BusModel(
      id: map['id'] as String,
      operatorName: map['operatorName'] as String,
      // older bus docs predate this field - fall back to empty rather than
      // crashing the search/results screens for trips created before it existed
      operatorPhone: map['operatorPhone'] as String? ?? '',
      from: map['from'] as String,
      to: map['to'] as String,
      // older bus docs predate this field - fall back to empty rather than
      // crashing on trips created before the terminal became required
      fromTerminal: map['fromTerminal'] as String? ?? '',
      toTerminal: map['toTerminal'] as String?,
      departureTime: DateTime.parse(map['departureTime'] as String),
      arrivalTime: DateTime.parse(map['arrivalTime'] as String),
      price: (map['price'] as num).toDouble(),
      totalSeats: map['totalSeats'] as int,
      availableSeats: map['availableSeats'] as int,
      busType: map['busType'] as String,
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      companyId: map['companyId'] as String,
      busServices: (map['busServices'] as List?)?.cast<String>() ?? const [],
    );
  }
}