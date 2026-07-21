// bus company data model - one per operator, onboarders are scoped to a companyId
class BusCompanyModel {
  final String id;
  final String name;
  final DateTime createdAt;

  BusCompanyModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BusCompanyModel.fromMap(Map<String, dynamic> map) {
    return BusCompanyModel(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}