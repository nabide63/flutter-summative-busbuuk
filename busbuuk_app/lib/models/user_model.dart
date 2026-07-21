// user profile data model
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  // profile pic stored as a base64 string right in the user doc - no Firebase
  // Storage on the free plan, so this skips needing a paid bucket
  final String? profileImageBase64;
  final DateTime createdAt;
  // 'passenger' | 'companyAdmin' | 'superAdmin' - defaults to passenger so
  // every account created before this field existed still reads back fine
  final String role;
  // set only for companyAdmin - the bus company this onboarder manages
  final String? companyId;
  // 'mtn' | 'airtel' | 'card' - preselected on the payment step during
  // checkout, set from the Payment Methods screen under Profile
  final String? defaultPaymentMethod;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImageBase64,
    required this.createdAt,
    this.role = 'passenger',
    this.companyId,
    this.defaultPaymentMethod,
  });

  bool get isPassenger => role == 'passenger';
  bool get isCompanyAdmin => role == 'companyAdmin';
  bool get isSuperAdmin => role == 'superAdmin';

  // for writing to firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImageBase64': profileImageBase64,
      'createdAt': createdAt.toIso8601String(),
      'role': role,
      'companyId': companyId,
      'defaultPaymentMethod': defaultPaymentMethod,
    };
  }

  // for reading a firestore doc back into a UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      profileImageBase64: map['profileImageBase64'] as String?,
      createdAt: _parseCreatedAt(map['createdAt']),
      role: map['role'] as String? ?? 'passenger',
      companyId: map['companyId'] as String?,
      defaultPaymentMethod: map['defaultPaymentMethod'] as String?,
    );
  }

  // normally the app writes createdAt as an ISO8601 string, but the one-off
  // super-admin doc gets typed by hand into the Firestore console (see the
  // README's admin setup section), where "Add field" defaults to a
  // timestamp type instead - so just accept either shape here.
  static DateTime _parseCreatedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? profileImageBase64,
    String? defaultPaymentMethod,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      createdAt: createdAt,
      role: role,
      companyId: companyId,
      defaultPaymentMethod: defaultPaymentMethod ?? this.defaultPaymentMethod,
    );
  }
}