class BudgetModel {
  final String id;
  final String userId;
  final String category;
  final double monthlyLimit;
  final DateTime month; // First day of the month
  final DateTime createdAt;

  // Added field for frontend calculated usage
  final double spent;

  BudgetModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.monthlyLimit,
    required this.month,
    required this.createdAt,
    this.spent = 0.0,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json, {double spent = 0.0}) {
    return BudgetModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      monthlyLimit: (json['monthly_limit'] as num).toDouble(),
      month: DateTime.parse(json['month'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      spent: spent,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'category': category,
    'monthly_limit': monthlyLimit,
    'month':
        "${month.year}-${month.month.toString().padLeft(2, '0')}-${month.day.toString().padLeft(2, '0')}",
    'created_at': createdAt.toIso8601String(),
  };

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? category,
    double? monthlyLimit,
    DateTime? month,
    DateTime? createdAt,
    double? spent,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      month: month ?? this.month,
      createdAt: createdAt ?? this.createdAt,
      spent: spent ?? this.spent,
    );
  }
}
