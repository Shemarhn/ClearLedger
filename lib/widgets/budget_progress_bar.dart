import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/budget.dart';

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({super.key, required this.budget});

  final BudgetModel budget;

  @override
  Widget build(BuildContext context) {
    final percent = budget.monthlyLimit <= 0 ? 0.0 : (budget.spent / budget.monthlyLimit);
    final clamped = percent.clamp(0.0, 1.0);
    final color = percent > 1
        ? AppConstants.errorRed
        : AppConstants.categoryColors[budget.category] ?? AppConstants.accentColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  budget.category,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'JMD ${budget.spent.toStringAsFixed(2)} / ${budget.monthlyLimit.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: percent > 1 ? AppConstants.errorRed : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: clamped,
              minHeight: 10,
              borderRadius: BorderRadius.circular(12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 6),
            Text(
              '${(percent * 100).toStringAsFixed(1)}% used',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
