import '../models/transaction.dart';
import '../core/supabase_client.dart';
import 'app_refresh_service.dart';
import 'exchange_rate_service.dart';

class TransactionService {
  final _exchangeRateService = ExchangeRateService();

  // Fetch transactions with optional filters
  Future<List<TransactionModel>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    TransactionType? transactionType,
    String? searchQuery,
    int limit = 50,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    dynamic query = supabase.from('transactions').select().eq('user_id', user.id);
    final trimmedSearch = searchQuery?.trim();
    final safeSearch =
        trimmedSearch == null || trimmedSearch.isEmpty ? '' : _postgrestSearchTerm(trimmedSearch);

    if (trimmedSearch != null && trimmedSearch.isNotEmpty && safeSearch.isEmpty) {
      return [];
    }

    if (startDate != null) {
      query = query.gte('transaction_date', _asDate(startDate));
    }
    if (endDate != null) {
      query = query.lte('transaction_date', _asDate(endDate));
    }
    if (category != null && category != 'All Categories') {
      query = query.eq('category', category);
    }
    if (transactionType != null) {
      query = query.eq('transaction_type', transactionType.value);
    }
    if (safeSearch.isNotEmpty) {
      query = query.or('merchant.ilike.*$safeSearch*,description.ilike.*$safeSearch*');
    }

    final response = await query
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = (response as List).map((e) => TransactionModel.fromJson(e)).toList();

    return list.take(limit).toList();
  }

  // Create a new transaction
  Future<TransactionModel> createTransaction({
    required double amount,
    String currency = 'JMD',
    double? originalAmount,
    String? originalCurrency,
    double? exchangeRate,
    TransactionType transactionType = TransactionType.expense,
    String? merchant,
    required String category,
    String? description,
    required DateTime transactionDate,
    required String inputMethod,
    String? accountId,
    String? destinationAccountId,
    String? cardLast4,
    double? feeAmount,
    String? receiptImageUrl,
    Map<String, dynamic>? rawLlmResponse,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final data = {
      'user_id': user.id,
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
    };

    final response = await supabase
        .from('transactions')
        .insert(data)
        .select()
        .single();

    AppRefreshService.instance.transactionsChanged();
    return TransactionModel.fromJson(response);
  }

  // Delete transaction
  Future<void> deleteTransaction(String id) async {
    await supabase.from('transactions').delete().eq('id', id);
    AppRefreshService.instance.transactionsChanged();
  }

  // Update transaction
  Future<TransactionModel> updateTransaction(String id, Map<String, dynamic> updates) async {
    final response = await supabase
        .from('transactions')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    AppRefreshService.instance.transactionsChanged();
    return TransactionModel.fromJson(response);
  }

  Future<void> convertUserTransactionsCurrency(
    String targetCurrency, {
    bool notify = true,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final target = _normalizeCurrency(targetCurrency);
    final response = await supabase
        .from('transactions')
        .select('id, amount, currency, original_amount, original_currency, fee_amount')
        .eq('user_id', user.id);

    for (final row in response as List) {
      final id = row['id'] as String?;
      final amount = (row['amount'] as num?)?.toDouble();
      final currency = _normalizeCurrency(row['currency'] as String? ?? target);
      if (id == null || amount == null || currency == target) continue;

      final conversion = await _exchangeRateService.convert(
        amount: amount.abs(),
        fromCurrency: currency,
        toCurrency: target,
      );
      final convertedAmount =
          amount < 0 ? -conversion.convertedAmount : conversion.convertedAmount;

      final fee = (row['fee_amount'] as num?)?.toDouble();
      double? convertedFee;
      if (fee != null) {
        final feeConversion = await _exchangeRateService.convert(
          amount: fee.abs(),
          fromCurrency: currency,
          toCurrency: target,
        );
        convertedFee = fee < 0 ? -feeConversion.convertedAmount : feeConversion.convertedAmount;
      }

      await supabase.from('transactions').update({
        'amount': convertedAmount,
        'currency': target,
        'fee_amount': convertedFee,
        'exchange_rate': conversion.exchangeRate,
        if (row['original_amount'] == null) 'original_amount': amount,
        if (row['original_currency'] == null) 'original_currency': currency,
      }).eq('id', id);
    }

    if (notify) {
      AppRefreshService.instance.transactionsChanged();
    }
  }

  Future<List<TransactionModel>> getRecentTransactions({int limit = 5}) async {
    return getTransactions(limit: limit);
  }

  Future<double> getTotalSpentForMonth(DateTime month) async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0;

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final response = await supabase
        .from('transactions')
        .select('amount, transaction_type')
        .eq('user_id', user.id)
        .gte('transaction_date', _asDate(start))
        .lte('transaction_date', _asDate(end));

    final list = response as List;
    return list.fold<double>(
      0,
      (sum, item) {
        final type = transactionTypeFromString(item['transaction_type'] as String?);
        if (type != TransactionType.expense) return sum;
        return sum + ((item['amount'] as num?)?.toDouble() ?? 0);
      },
    );
  }

  Future<double> getTotalIncomeForMonth(DateTime month) async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0;

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final response = await supabase
        .from('transactions')
        .select('amount, transaction_type')
        .eq('user_id', user.id)
        .gte('transaction_date', _asDate(start))
        .lte('transaction_date', _asDate(end));

    final list = response as List;
    return list.fold<double>(0, (sum, item) {
      final type = transactionTypeFromString(item['transaction_type'] as String?);
      if (!type.isInflow) return sum;
      return sum + ((item['amount'] as num?)?.toDouble() ?? 0);
    });
  }

  Future<Map<String, double>> getCategoryTotalsForMonth(DateTime month) async {
    final user = supabase.auth.currentUser;
    if (user == null) return {};

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final response = await supabase
        .from('transactions')
        .select('category, amount, transaction_type')
        .eq('user_id', user.id)
        .gte('transaction_date', _asDate(start))
        .lte('transaction_date', _asDate(end));

    final totals = <String, double>{};
    for (final row in (response as List)) {
      final category = row['category'] as String? ?? 'Other';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final type = transactionTypeFromString(row['transaction_type'] as String?);
      if (type != TransactionType.expense) continue;
      totals[category] = (totals[category] ?? 0) + amount;
    }
    return totals;
  }

  String _asDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _postgrestSearchTerm(String value) {
    return value
        .replaceAll(RegExp(r'[^A-Za-z0-9 .&-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeCurrency(String currency) {
    final normalized = currency.trim().toUpperCase();
    return RegExp(r'^[A-Z]{3}$').hasMatch(normalized) ? normalized : 'JMD';
  }
}
