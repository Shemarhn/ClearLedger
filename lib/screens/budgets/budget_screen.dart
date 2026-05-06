import 'package:flutter/material.dart';

import '../../models/budget.dart';
import '../../services/budget_alert_service.dart';
import '../../services/budget_service.dart';
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
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(onPressed: () => _openAddBudget(), icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text('Could not load budgets: $_error')),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                )
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
                        final budget = _budgets[index];
                        return BudgetProgressBar(
                          budget: budget,
                          onTap: () => _openAddBudget(budget),
                        );
                      },
                    ),
            ),
    );
  }
}
