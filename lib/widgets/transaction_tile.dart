import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/transaction.dart';

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
    final color = AppConstants.categoryColors[transaction.category] ?? Colors.grey;
    final dateText = DateFormat.yMMMd().format(transaction.transactionDate);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(
            AppConstants.categoryIcons[transaction.category] ?? Icons.payments_outlined,
            color: color,
          ),
        ),
        title: Text(transaction.merchant ?? 'Unknown merchant'),
        subtitle: Text('${transaction.category} • $dateText'),
        trailing: Text(
          'JMD ${transaction.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
