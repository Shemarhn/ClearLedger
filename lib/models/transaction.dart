class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String? merchant;
  final String category;
  final String? description;
  final DateTime transactionDate;
  final String inputMethod;
  final String? receiptImageUrl;
  final Map<String, dynamic>? rawLlmResponse;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    this.merchant,
    required this.category,
    this.description,
    required this.transactionDate,
    required this.inputMethod,
    this.receiptImageUrl,
    this.rawLlmResponse,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      merchant: json['merchant'] as String?,
      category: json['category'] as String,
      description: json['description'] as String?,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      inputMethod: json['input_method'] as String,
      receiptImageUrl: json['receipt_image_url'] as String?,
      rawLlmResponse: json['raw_llm_response'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'amount': amount,
    'merchant': merchant,
    'category': category,
    'description': description,
    'transaction_date':
        "${transactionDate.year}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}",
    'input_method': inputMethod,
    'receipt_image_url': receiptImageUrl,
    'raw_llm_response': rawLlmResponse,
    'created_at': createdAt.toIso8601String(),
  };
}
