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
    final color = _colorForType(context, transaction.transactionType);
    final dateText = DateFormat.MMMd().format(transaction.transactionDate);
    final amountPrefix = transaction.transactionType.isInflow
        ? '+'
        : transaction.transactionType.isTransfer
            ? ''
            : '-';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final surface = dark ? const Color(0xFF0B1927) : Colors.white;
    final stroke = scheme.outlineVariant.withValues(alpha: dark ? 0.58 : 0.72);
    final muted = scheme.onSurface.withValues(alpha: 0.62);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stroke),
        boxShadow: [
          if (dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        leading: AppIconBadge(
          glyph: _glyphForType(transaction.transactionType),
          color: color,
          size: 42,
        ),
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
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Color _colorForType(BuildContext context, TransactionType type) {
    if (type.isInflow) return AppConstants.successGreen;
    if (type.isTransfer) return Theme.of(context).colorScheme.primary;
    return AppConstants.errorRed;
  }

  AppGlyph _glyphForType(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return AppGlyph.outflow;
      case TransactionType.income:
        return AppGlyph.inflow;
      case TransactionType.transfer:
        return AppGlyph.transfer;
      case TransactionType.withdrawal:
        return AppGlyph.cash;
      case TransactionType.deposit:
        return AppGlyph.bank;
      case TransactionType.refund:
        return AppGlyph.inflow;
    }
  }
}
