enum TransactionType {
  expense,
  income,
  transfer,
  withdrawal,
  deposit,
  refund,
}

extension TransactionTypeLabel on TransactionType {
  String get value => name;

  String get label {
    switch (this) {
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.income:
        return 'Income';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.refund:
        return 'Refund';
    }
  }

  bool get isOutflow => this == TransactionType.expense;
  bool get isInflow => this == TransactionType.income || this == TransactionType.refund;
  bool get isTransfer =>
      this == TransactionType.transfer ||
      this == TransactionType.withdrawal ||
      this == TransactionType.deposit;
}

TransactionType transactionTypeFromString(String? value) {
  return TransactionType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => TransactionType.expense,
  );
}

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final double? originalAmount;
  final String? originalCurrency;
  final double? exchangeRate;
  final TransactionType transactionType;
  final String? merchant;
  final String category;
  final String? description;
  final DateTime transactionDate;
  final String inputMethod;
  final String? accountId;
  final String? destinationAccountId;
  final String? cardLast4;
  final double? feeAmount;
  final String? receiptImageUrl;
  final Map<String, dynamic>? rawLlmResponse;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    this.currency = 'JMD',
    this.originalAmount,
    this.originalCurrency,
    this.exchangeRate,
    this.transactionType = TransactionType.expense,
    this.merchant,
    required this.category,
    this.description,
    required this.transactionDate,
    required this.inputMethod,
    this.accountId,
    this.destinationAccountId,
    this.cardLast4,
    this.feeAmount,
    this.receiptImageUrl,
    this.rawLlmResponse,
    required this.createdAt,
  });

  double get signedAmount {
    if (transactionType.isInflow) return amount;
    if (transactionType.isTransfer) return 0;
    return -amount;
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'JMD',
      originalAmount: (json['original_amount'] as num?)?.toDouble(),
      originalCurrency: json['original_currency'] as String?,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
      transactionType: transactionTypeFromString(json['transaction_type'] as String?),
      merchant: json['merchant'] as String?,
      category: json['category'] as String,
      description: json['description'] as String?,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      inputMethod: json['input_method'] as String,
      accountId: json['account_id'] as String?,
      destinationAccountId: json['destination_account_id'] as String?,
      cardLast4: json['card_last4'] as String?,
      feeAmount: (json['fee_amount'] as num?)?.toDouble(),
      receiptImageUrl: json['receipt_image_url'] as String?,
      rawLlmResponse: json['raw_llm_response'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'amount': amount,
    'currency': currency,
    'original_amount': originalAmount,
    'original_currency': originalCurrency,
    'exchange_rate': exchangeRate,
    'transaction_type': transactionType.value,
    'merchant': merchant,
    'category': category,
    'description': description,
    'transaction_date':
        "${transactionDate.year}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}",
    'input_method': inputMethod,
    'account_id': accountId,
    'destination_account_id': destinationAccountId,
    'card_last4': cardLast4,
    'fee_amount': feeAmount,
    'receipt_image_url': receiptImageUrl,
    'raw_llm_response': rawLlmResponse,
    'created_at': createdAt.toIso8601String(),
  };
}
