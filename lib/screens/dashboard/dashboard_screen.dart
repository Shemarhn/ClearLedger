import 'package:flutter/material.dart';

import '../../models/budget.dart';
import '../../models/transaction.dart';
import '../../services/budget_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/budget_progress_bar.dart';
import '../../widgets/spending_chart.dart';
import '../../widgets/transaction_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _txService = TransactionService();
  final _budgetService = BudgetService();

  bool _loading = true;
  double _totalSpent = 0;
  Map<String, double> _categoryTotals = {};
  List<TransactionModel> _recent = [];
  List<BudgetModel> _budgets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final month = DateTime.now();
    final total = await _txService.getTotalSpentForMonth(month);
    final categories = await _txService.getCategoryTotalsForMonth(month);
    final recent = await _txService.getRecentTransactions(limit: 5);
    final budgets = await _budgetService.getBudgets(month: month);

    if (!mounted) return;
    setState(() {
      _totalSpent = total;
      _categoryTotals = categories;
      _recent = recent;
      _budgets = budgets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF073B4C), Color(0xFF118AB2)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spent this month',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'JMD ${_totalSpent.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: SpendingChart(categoryTotals: _categoryTotals),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Recent transactions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._recent.map((tx) => TransactionTile(transaction: tx)),
                  const SizedBox(height: 16),
                  const Text(
                    'Budget usage',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_budgets.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No budgets set for this month.'),
                      ),
                    )
                  else
                    ..._budgets.map((b) => BudgetProgressBar(budget: b)),
                ],
              ),
            ),
    );
  }
}
