import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/transaction.dart';
import 'dark_shell.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(transaction.transactionType);
    final dateText = DateFormat.MMMd().format(transaction.transactionDate);
    final amountPrefix = transaction.transactionType.isInflow
        ? '+'
        : transaction.transactionType.isTransfer
            ? ''
            : '-';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppConstants.darkSurface : Theme.of(context).colorScheme.surface;
    final stroke = dark ? AppConstants.darkStroke : AppConstants.lightStroke;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: AppIconBadge(icon: _iconForType(transaction.transactionType), color: color),
        title: Text(
          transaction.merchant ?? transaction.transactionType.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${transaction.transactionType.label} - ${transaction.category} - $dateText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: muted),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: Text(
            '$amountPrefix${transaction.currency} ${transaction.amount.toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Color _colorForType(TransactionType type) {
    if (type.isInflow) return AppConstants.successGreen;
    if (type.isTransfer) return AppConstants.accentColor;
    return AppConstants.errorRed;
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return Icons.trending_down;
      case TransactionType.income:
        return Icons.trending_up;
      case TransactionType.transfer:
        return Icons.compare_arrows;
      case TransactionType.withdrawal:
        return Icons.atm_outlined;
      case TransactionType.deposit:
        return Icons.savings_outlined;
      case TransactionType.refund:
        return Icons.replay;
    }
  }
}
