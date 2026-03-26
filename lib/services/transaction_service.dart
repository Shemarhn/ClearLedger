import '../models/transaction.dart';
import '../core/supabase_client.dart';

class TransactionService {
  // Fetch transactions with optional filters
  Future<List<TransactionModel>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? searchQuery,
    int limit = 50,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('transactions')
        .select()
        .eq('user_id', user.id)
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);

    var list = (response as List).map((e) => TransactionModel.fromJson(e)).toList();

    if (startDate != null) {
      list = list.where((tx) => !tx.transactionDate.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      list = list.where((tx) => !tx.transactionDate.isAfter(endDate)).toList();
    }
    if (category != null && category != 'All Categories') {
      list = list.where((tx) => tx.category == category).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((tx) {
        final merchant = (tx.merchant ?? '').toLowerCase();
        final description = (tx.description ?? '').toLowerCase();
        return merchant.contains(q) || description.contains(q);
      }).toList();
    }

    return list.take(limit).toList();
  }

  // Create a new transaction
  Future<TransactionModel> createTransaction({
    required double amount,
    String? merchant,
    required String category,
    String? description,
    required DateTime transactionDate,
    required String inputMethod,
    String? receiptImageUrl,
    Map<String, dynamic>? rawLlmResponse,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final data = {
      'user_id': user.id,
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'description': description,
      'transaction_date':
          "${transactionDate.year}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}",
      'input_method': inputMethod,
      'receipt_image_url': receiptImageUrl,
      'raw_llm_response': rawLlmResponse,
    };

    final response = await supabase
        .from('transactions')
        .insert(data)
        .select()
        .single();

    return TransactionModel.fromJson(response);
  }

  // Delete transaction
  Future<void> deleteTransaction(String id) async {
    await supabase.from('transactions').delete().eq('id', id);
  }

  // Update transaction
  Future<TransactionModel> updateTransaction(String id, Map<String, dynamic> updates) async {
    final response = await supabase
        .from('transactions')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return TransactionModel.fromJson(response);
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
        .select('amount')
        .eq('user_id', user.id)
        .gte('transaction_date', _asDate(start))
        .lte('transaction_date', _asDate(end));

    final list = response as List;
    return list.fold<double>(
      0,
      (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<Map<String, double>> getCategoryTotalsForMonth(DateTime month) async {
    final user = supabase.auth.currentUser;
    if (user == null) return {};

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final response = await supabase
        .from('transactions')
        .select('category, amount')
        .eq('user_id', user.id)
        .gte('transaction_date', _asDate(start))
        .lte('transaction_date', _asDate(end));

    final totals = <String, double>{};
    for (final row in (response as List)) {
      final category = row['category'] as String? ?? 'Other';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      totals[category] = (totals[category] ?? 0) + amount;
    }
    return totals;
  }

  String _asDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
