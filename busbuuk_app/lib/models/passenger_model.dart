// passenger details data model - used on the Passenger Details screen
class PassengerModel {
  final String firstName;
  final String lastName;
  final String nationality;
  final String email;
  final String phone;
  final String seatNumber;
  final String? documentFileName;
  // passport/national ID PDF, stored as base64 text right on the passenger
  // data - there's no Storage bucket (needs the paid plan)
  final String? documentBase64;

  PassengerModel({
    required this.firstName,
    required this.lastName,
    required this.nationality,
    required this.email,
    required this.phone,
    required this.seatNumber,
    this.documentFileName,
    this.documentBase64,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'nationality': nationality,
      'email': email,
      'phone': phone,
      'seatNumber': seatNumber,
      'documentFileName': documentFileName,
      'documentBase64': documentBase64,
    };
  }

  factory PassengerModel.fromMap(Map<String, dynamic> map) {
    return PassengerModel(
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      nationality: map['nationality'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      seatNumber: map['seatNumber'] as String,
      documentFileName: map['documentFileName'] as String?,
      documentBase64: map['documentBase64'] as String?,
    );
  }
}