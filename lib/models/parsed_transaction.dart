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
  final String currency;
  final String? date;
  final String category;
  final String? description;
  final List<LineItem> lineItems;
  final double confidence;
  final String? receiptUrl;
  final Map<String, dynamic>? rawLlmResponse;

  ParsedTransaction({
    this.merchant,
    this.amount,
    this.currency = 'JMD',
    this.date,
    this.category = 'Other',
    this.description,
    this.lineItems = const [],
    this.confidence = 0.0,
    this.receiptUrl,
    this.rawLlmResponse,
  });

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) {
    return ParsedTransaction(
      merchant: json['merchant'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'JMD',
      date: json['date'] as String?,
      category: json['category'] as String? ?? 'Other',
      description: json['description'] as String?,
      lineItems: (json['line_items'] as List<dynamic>?)
              ?.map((e) => LineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      receiptUrl: json['receipt_url'] as String?,
      rawLlmResponse: json['raw_llm_response'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'merchant': merchant,
    'amount': amount,
    'currency': currency,
    'date': date,
    'category': category,
    'description': description,
    'line_items': lineItems.map((e) => e.toJson()).toList(),
    'confidence': confidence,
    'receipt_url': receiptUrl,
    'raw_llm_response': rawLlmResponse,
  };

  ParsedTransaction copyWith({
    String? merchant,
    double? amount,
    String? currency,
    String? date,
    String? category,
    String? description,
    List<LineItem>? lineItems,
    double? confidence,
    String? receiptUrl,
    Map<String, dynamic>? rawLlmResponse,
  }) {
    return ParsedTransaction(
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      lineItems: lineItems ?? this.lineItems,
      confidence: confidence ?? this.confidence,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      rawLlmResponse: rawLlmResponse ?? this.rawLlmResponse,
    );
  }
}
