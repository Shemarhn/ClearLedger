class ProfileModel {
  final String id;
  final String fullName;
  final String currency;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    required this.fullName,
    required this.currency,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      currency: json['currency'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'currency': currency,
    'created_at': createdAt.toIso8601String(),
  };

  ProfileModel copyWith({
    String? id,
    String? fullName,
    String? currency,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
