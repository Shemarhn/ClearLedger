import 'package:flutter/material.dart';

import '../../models/budget.dart';
import '../../services/budget_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/budget_progress_bar.dart';
import 'add_budget_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _budgetService = BudgetService();
  List<BudgetModel> _budgets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final budgets = await _budgetService.getBudgets();
    if (!mounted) return;

    final overspent = budgets.where((b) => b.spent > b.monthlyLimit).toList();
    if (overspent.isNotEmpty) {
      await NotificationService.instance.showLocalNotification(
        title: 'Budget alert',
        body: 'You have ${overspent.length} over-budget categories this month.',
      );
    }

    setState(() {
      _budgets = budgets;
      _loading = false;
    });
  }

  Future<void> _openAddBudget() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddBudgetScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(onPressed: _openAddBudget, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _budgets.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 100),
                        Center(child: Text('No budgets yet. Tap + to add one.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _budgets.length,
                      itemBuilder: (context, index) {
                        return BudgetProgressBar(budget: _budgets[index]);
                      },
                    ),
            ),
    );
  }
}
