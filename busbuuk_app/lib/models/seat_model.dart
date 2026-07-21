// seat data model - used on the Seat Selection screen
class SeatModel {
  final String seatNumber;
  final bool isBooked;
  bool isSelected; // toggled locally as the user picks seats, not stored

  SeatModel({
    required this.seatNumber,
    required this.isBooked,
    this.isSelected = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'seatNumber': seatNumber,
      'isBooked': isBooked,
    };
  }

  factory SeatModel.fromMap(Map<String, dynamic> map) {
    return SeatModel(
      seatNumber: map['seatNumber'] as String,
      isBooked: map['isBooked'] as bool,
    );
  }
}