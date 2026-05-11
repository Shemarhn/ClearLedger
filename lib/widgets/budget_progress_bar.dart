import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/budget.dart';
import '../services/app_settings_service.dart';
import 'dark_shell.dart';

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.budget,
    this.onTap,
  });

  final BudgetModel budget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final percent = budget.monthlyLimit <= 0 ? 0.0 : (budget.spent / budget.monthlyLimit);
    final clamped = percent.clamp(0.0, 1.0);
    final color = percent > 1
        ? AppConstants.errorRed
        : AppConstants.categoryColors[budget.category] ?? AppConstants.accentColor;
    final currency = AppSettingsService.instance.preferredCurrency;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.62);

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FinanceCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        budget.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$currency ${budget.spent.toStringAsFixed(2)} / ${budget.monthlyLimit.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: percent > 1 ? AppConstants.errorRed : onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: clamped,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : scheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(percent * 100).toStringAsFixed(1)}% used',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
