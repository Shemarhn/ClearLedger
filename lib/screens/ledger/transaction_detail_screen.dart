import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/transaction.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _detail('Merchant', transaction.merchant ?? 'Unknown'),
          _detail('Amount', 'JMD ${transaction.amount.toStringAsFixed(2)}'),
          _detail('Category', transaction.category),
          _detail('Description', transaction.description ?? '-'),
          _detail('Date', DateFormat.yMMMMd().format(transaction.transactionDate)),
          _detail('Input Method', transaction.inputMethod),
          if (transaction.receiptImageUrl != null && transaction.receiptImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Receipt Image', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                transaction.receiptImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Unable to load receipt image.'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
