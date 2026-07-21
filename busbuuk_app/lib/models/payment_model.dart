// payment data model - used on the Payment screen
class PaymentModel {
  final String id;
  final String bookingId;
  final double amount;
  final String method; // "card" or "mobile_money"
  final String status; // "pending", "successful", "failed"
  final DateTime transactionDate;

  PaymentModel({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.status,
    required this.transactionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'amount': amount,
      'method': method,
      'status': status,
      'transactionDate': transactionDate.toIso8601String(),
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as String,
      bookingId: map['bookingId'] as String,
      amount: (map['amount'] as num).toDouble(),
      method: map['method'] as String,
      status: map['status'] as String,
      transactionDate: DateTime.parse(map['transactionDate'] as String),
    );
  }
}