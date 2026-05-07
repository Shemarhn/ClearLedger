class LineItem {
  final String name;
  final double price;

  LineItem({required this.name, required this.price});

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      name: json['name'] as String? ?? 'Unknown',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
  };
}

class ParsedTransaction {
  final String? merchant;
  final double? amount;
  final String transactionType;
  final String currency;
  final String? date;
  final String category;
  final String? description;
  final List<LineItem> lineItems;
  final double confidence;
  final String? accountHint;
  final String? destinationAccountHint;
  final String? cardLast4;
  final double? feeAmount;
  final String? receiptUrl;
  final String? receiptPath;
  final Map<String, dynamic>? rawLlmResponse;

  ParsedTransaction({
    this.merchant,
    this.amount,
    this.transactionType = 'expense',
    this.currency = 'JMD',
    this.date,
    this.category = 'Other',
    this.description,
    this.lineItems = const [],
    this.confidence = 0.0,
    this.accountHint,
    this.destinationAccountHint,
    this.cardLast4,
    this.feeAmount,
    this.receiptUrl,
    this.receiptPath,
    this.rawLlmResponse,
  });

  String? get persistentReceiptReference => receiptPath ?? receiptUrl;

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) {
    return ParsedTransaction(
      merchant: json['merchant'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      transactionType: json['transaction_type'] as String? ?? 'expense',
      currency: json['currency'] as String? ?? 'JMD',
      date: json['date'] as String?,
      category: json['category'] as String? ?? 'Other',
      description: json['description'] as String?,
      lineItems: (json['line_items'] as List<dynamic>?)
              ?.map((e) => LineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      accountHint: json['account_hint'] as String?,
      destinationAccountHint: json['destination_account_hint'] as String?,
      cardLast4: json['card_last4'] as String?,
      feeAmount: (json['fee_amount'] as num?)?.toDouble(),
      receiptUrl: json['receipt_url'] as String?,
      receiptPath: json['receipt_path'] as String?,
      rawLlmResponse: json['raw_llm_response'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'merchant': merchant,
    'amount': amount,
    'transaction_type': transactionType,
    'currency': currency,
    'date': date,
    'category': category,
    'description': description,
    'line_items': lineItems.map((e) => e.toJson()).toList(),
    'confidence': confidence,
    'account_hint': accountHint,
    'destination_account_hint': destinationAccountHint,
    'card_last4': cardLast4,
    'fee_amount': feeAmount,
    'receipt_url': receiptUrl,
    'receipt_path': receiptPath,
    'raw_llm_response': rawLlmResponse,
  };

  ParsedTransaction copyWith({
    String? merchant,
    double? amount,
    String? transactionType,
    String? currency,
    String? date,
    String? category,
    String? description,
    List<LineItem>? lineItems,
    double? confidence,
    String? accountHint,
    String? destinationAccountHint,
    String? cardLast4,
    double? feeAmount,
    String? receiptUrl,
    String? receiptPath,
    Map<String, dynamic>? rawLlmResponse,
  }) {
    return ParsedTransaction(
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      lineItems: lineItems ?? this.lineItems,
      confidence: confidence ?? this.confidence,
      accountHint: accountHint ?? this.accountHint,
      destinationAccountHint: destinationAccountHint ?? this.destinationAccountHint,
      cardLast4: cardLast4 ?? this.cardLast4,
      feeAmount: feeAmount ?? this.feeAmount,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptPath: receiptPath ?? this.receiptPath,
      rawLlmResponse: rawLlmResponse ?? this.rawLlmResponse,
    );
  }
}
