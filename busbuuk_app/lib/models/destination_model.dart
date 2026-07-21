// carousel destination shown on the home screen - super-admin curated
class DestinationModel {
  final String id;
  final String city;
  final String country;
  // no Firebase Storage on the free plan, so just base64 the photo onto the doc
  final String imageBase64;
  // lower sorts first in the carousel
  final int order;
  final DateTime createdAt;

  DestinationModel({
    required this.id,
    required this.city,
    required this.country,
    required this.imageBase64,
    this.order = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'city': city,
      'country': country,
      'imageBase64': imageBase64,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DestinationModel.fromMap(Map<String, dynamic> map) {
    return DestinationModel(
      id: map['id'] as String,
      city: map['city'] as String,
      country: map['country'] as String,
      imageBase64: map['imageBase64'] as String,
      order: map['order'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  DestinationModel copyWith({
    String? city,
    String? country,
    String? imageBase64,
    int? order,
  }) {
    return DestinationModel(
      id: id,
      city: city ?? this.city,
      country: country ?? this.country,
      imageBase64: imageBase64 ?? this.imageBase64,
      order: order ?? this.order,
      createdAt: createdAt,
    );
  }
}