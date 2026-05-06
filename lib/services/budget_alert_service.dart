import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget.dart';
import 'notification_service.dart';

class BudgetAlertService {
  BudgetAlertService._();
  static final BudgetAlertService instance = BudgetAlertService._();

  Future<void> notifyNewOverspentBudgets(
    List<BudgetModel> budgets, {
    DateTime? month,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final targetMonth = month ?? DateTime.now();
    final monthPrefix =
        'budget_alert_${targetMonth.year}_${targetMonth.month.toString().padLeft(2, '0')}_';
    final overspent = budgets.where((b) => b.spent > b.monthlyLimit).toList();
    final overspentKeys = overspent.map((b) => '$monthPrefix${b.category}').toSet();

    for (final key in prefs.getKeys().where((key) => key.startsWith(monthPrefix)).toList()) {
      if (!overspentKeys.contains(key)) {
        await prefs.remove(key);
      }
    }

    final newlyOverspent =
        overspent.where((b) => prefs.getBool('$monthPrefix${b.category}') != true).toList();

    if (newlyOverspent.isEmpty) return;

    await NotificationService.instance.showLocalNotification(
      title: 'Budget alert',
      body: newlyOverspent.length == 1
          ? 'You have exceeded your ${newlyOverspent.first.category} budget.'
          : 'You have ${newlyOverspent.length} over-budget categories this month.',
    );

    for (final budget in newlyOverspent) {
      await prefs.setBool('$monthPrefix${budget.category}', true);
    }
  }
}
