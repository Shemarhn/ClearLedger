import '../models/budget.dart';
import '../core/supabase_client.dart';

class BudgetService {
  // Fetch budgets with calculated spent amounts
  Future<List<BudgetModel>> getBudgets({DateTime? month}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final now = month ?? DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    // 1. Fetch all budgets
    final budgetResponse = await supabase
        .from('budgets')
        .select()
        .eq('user_id', user.id)
        .eq('month',
            "${firstDayOfMonth.year}-${firstDayOfMonth.month.toString().padLeft(2, '0')}-${firstDayOfMonth.day.toString().padLeft(2, '0')}")
        .order('month', ascending: false);

    final budgets = (budgetResponse as List).map((e) => BudgetModel.fromJson(e)).toList();

    // 2. Fetch spending for those budgets
    final txResponse = await supabase
        .from('transactions')
        .select('category, amount')
        .eq('user_id', user.id)
        .gte(
          'transaction_date',
          "${firstDayOfMonth.year}-${firstDayOfMonth.month.toString().padLeft(2, '0')}-${firstDayOfMonth.day.toString().padLeft(2, '0')}",
        )
        .lte(
          'transaction_date',
          "${lastDayOfMonth.year}-${lastDayOfMonth.month.toString().padLeft(2, '0')}-${lastDayOfMonth.day.toString().padLeft(2, '0')}",
        );

    final categoryTotals = <String, double>{};
    for (var tx in (txResponse as List)) {
      final category = tx['category'] as String;
      final amount = (tx['amount'] as num).toDouble();
      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
    }

    return budgets.map((b) {
      if (b.month.year == firstDayOfMonth.year && b.month.month == firstDayOfMonth.month) {
        return b.copyWith(spent: categoryTotals[b.category] ?? 0.0);
      }
      return b;
    }).toList();
  }

  Future<List<BudgetModel>> getOverspentBudgets({DateTime? month}) async {
    final budgets = await getBudgets(month: month);
    return budgets.where((b) => b.spent > b.monthlyLimit).toList();
  }

  // Create a budget
  Future<BudgetModel> createBudget({
    required String category,
    required double monthlyLimit,
    required DateTime month,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final data = {
      'user_id': user.id,
      'category': category,
      'monthly_limit': monthlyLimit,
      'month':
          "${month.year}-${month.month.toString().padLeft(2, '0')}-${month.day.toString().padLeft(2, '0')}",
    };

    final response = await supabase
        .from('budgets')
        .insert(data)
        .select()
        .single();

    return BudgetModel.fromJson(response);
  }

  // Delete budget
  Future<void> deleteBudget(String id) async {
    await supabase.from('budgets').delete().eq('id', id);
  }

  // Update budget
  Future<BudgetModel> updateBudget(String id, double monthlyLimit) async {
    final response = await supabase
        .from('budgets')
        .update({'monthly_limit': monthlyLimit})
        .eq('id', id)
        .select()
        .single();
    return BudgetModel.fromJson(response);
  }
}
