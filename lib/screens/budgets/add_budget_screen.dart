import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/budget.dart';
import '../../services/app_settings_service.dart';
import '../../services/budget_service.dart';

class AddBudgetScreen extends StatefulWidget {
  const AddBudgetScreen({super.key, this.budget});

  final BudgetModel? budget;

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _budgetService = BudgetService();
  final _amountController = TextEditingController();

  late String _category;
  late DateTime _month;
  bool _saving = false;
  bool _deleting = false;

  bool get _editing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final budget = widget.budget;
    _category = budget?.category ?? AppConstants.categories.first;
    _month = budget?.month ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _amountController.text = budget?.monthlyLimit.toStringAsFixed(2) ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly limit.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final budget = widget.budget;
      if (budget == null) {
        await _budgetService.createBudget(
          category: _category,
          monthlyLimit: amount,
          month: _month,
        );
      } else {
        await _budgetService.updateBudget(
          budget.id,
          category: _category,
          monthlyLimit: amount,
          month: _month,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyBudgetError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyBudgetError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('duplicate key') ||
        message.contains('23505') ||
        message.contains('budgets_user_id_category_month_key')) {
      return 'A budget for this category already exists for the selected month.';
    }
    return 'Could not save budget: $error';
  }

  Future<void> _delete() async {
    final budget = widget.budget;
    if (budget == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text('The ${budget.category} budget for this month will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _budgetService.deleteBudget(budget.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete budget: $error')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Pick budget month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    final currency = AppSettingsService.instance.preferredCurrency;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Budget' : 'Add Budget')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: AppConstants.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: busy ? null : (value) => setState(() => _category = value ?? _category),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Monthly limit ($currency)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Month: ${_month.year}-${_month.month.toString().padLeft(2, '0')}-01',
                  ),
                ),
                TextButton(onPressed: busy ? null : _pickMonth, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: busy ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editing ? 'Save Changes' : 'Save Budget'),
            ),
            if (_editing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(_deleting ? 'Deleting...' : 'Delete Budget'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
