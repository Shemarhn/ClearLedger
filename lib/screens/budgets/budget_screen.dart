import 'package:flutter/material.dart';

import '../../models/budget.dart';
import '../../services/budget_alert_service.dart';
import '../../services/budget_service.dart';
import '../../widgets/budget_progress_bar.dart';
import '../../widgets/dark_shell.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final budgets = await _budgetService.getBudgets();
      if (!mounted) return;

      await BudgetAlertService.instance.notifyNewOverspentBudgets(budgets);

      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddBudget([BudgetModel? budget]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddBudgetScreen(budget: budget)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DarkShell(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  children: [
                    ScreenHeader(
                      title: 'Budgets',
                      subtitle: 'Limits and category progress',
                      icon: Icons.pie_chart_outline,
                      trailing: IconButton.filled(
                        onPressed: () => _openAddBudget(),
                        icon: const Icon(Icons.add),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_error != null)
                      FinanceCard(
                        child: Column(
                          children: [
                            Text('Could not load budgets: $_error'),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else if (_budgets.isEmpty)
                      const FinanceCard(
                        child: Column(
                          children: [
                            AppIconBadge(icon: Icons.pie_chart_outline),
                            SizedBox(height: 14),
                            Text(
                              'No budgets yet.',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._budgets.map(
                        (budget) => BudgetProgressBar(
                          budget: budget,
                          onTap: () => _openAddBudget(budget),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
