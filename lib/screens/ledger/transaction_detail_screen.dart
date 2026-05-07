import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../models/transaction.dart';
import '../../services/transaction_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _transactionService = TransactionService();

  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late TransactionType _transactionType;
  late String _category;
  late DateTime _date;

  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.transaction.merchant ?? '');
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: widget.transaction.description ?? '',
    );
    _transactionType = widget.transaction.transactionType;
    _category = AppConstants.categories.contains(widget.transaction.category)
        ? widget.transaction.category
        : 'Other';
    _date = widget.transaction.transactionDate;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountController.text.trim());
      await _transactionService.updateTransaction(
        widget.transaction.id,
        {
          'amount': amount,
          'transaction_type': _transactionType.value,
          'merchant': _merchantController.text.trim().isEmpty
              ? null
              : _merchantController.text.trim(),
          'category': _category,
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'transaction_date': _dateOnly(_date),
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update transaction: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This transaction will be permanently removed.'),
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
      await _transactionService.deleteTransaction(widget.transaction.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete transaction: $error')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<String?> _signedReceiptUrl(String reference) async {
    final storagePath = _receiptStoragePathFromUrl(reference);
    if (storagePath != null) {
      return supabase.storage.from('receipts').createSignedUrl(storagePath, 3600);
    }

    if (reference.startsWith('http://') || reference.startsWith('https://')) {
      return reference;
    }

    return supabase.storage.from('receipts').createSignedUrl(reference, 3600);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          if (!_editing)
            IconButton(
              onPressed: busy ? null : () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
            )
          else
            IconButton(
              onPressed: busy ? null : () => setState(() => _editing = false),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_editing) _editForm() else _readOnlyDetails(),
          if (widget.transaction.receiptImageUrl != null &&
              widget.transaction.receiptImageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Receipt Image', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _receiptImage(widget.transaction.receiptImageUrl!),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: Text(_deleting ? 'Deleting...' : 'Delete Transaction'),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyDetails() {
    final lineItems = _lineItemsFromRawResponse();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detail('Merchant', widget.transaction.merchant ?? 'Unknown'),
        _detail('Type', widget.transaction.transactionType.label),
        _detail(
          'Amount',
          '${widget.transaction.currency} ${widget.transaction.amount.toStringAsFixed(2)}',
        ),
        if (widget.transaction.originalAmount != null &&
            widget.transaction.originalCurrency != null)
          _detail(
            'Original amount',
            '${widget.transaction.originalCurrency} ${widget.transaction.originalAmount!.toStringAsFixed(2)}',
          ),
        if (widget.transaction.cardLast4 != null)
          _detail('Card', '****${widget.transaction.cardLast4}'),
        if (widget.transaction.feeAmount != null)
          _detail(
            'Fee',
            '${widget.transaction.currency} ${widget.transaction.feeAmount!.toStringAsFixed(2)}',
          ),
        _detail('Category', widget.transaction.category),
        _detail('Description', widget.transaction.description ?? '-'),
        _detail('Date', DateFormat.yMMMMd().format(widget.transaction.transactionDate)),
        _detail('Input Method', widget.transaction.inputMethod),
        if (lineItems.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Line Items', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...lineItems.map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              trailing: Text('${widget.transaction.currency} ${item.price.toStringAsFixed(2)}'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _editForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _merchantController,
            decoration: const InputDecoration(labelText: 'Merchant'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Amount is required';
              if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TransactionType>(
            initialValue: _transactionType,
            items: TransactionType.values
                .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                .toList(),
            onChanged: (value) => setState(() => _transactionType = value ?? TransactionType.expense),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: AppConstants.categories
                .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                .toList(),
            onChanged: (value) => setState(() => _category = value ?? 'Other'),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Date: ${_dateOnly(_date)}')),
              TextButton(onPressed: _saving ? null : _pickDate, child: const Text('Change')),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _receiptImage(String reference) {
    return FutureBuilder<String?>(
      future: _signedReceiptUrl(reference),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final url = snapshot.data;
        if (url == null || url.isEmpty || snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Unable to load receipt image.'),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Unable to load receipt image.'),
            ),
          ),
        );
      },
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

  String _dateOnly(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  List<_ReceiptLineItem> _lineItemsFromRawResponse() {
    final rawItems = widget.transaction.rawLlmResponse?['line_items'];
    if (rawItems is! List) return [];

    return rawItems.whereType<Map>().map((item) {
      final name = item['name']?.toString().trim();
      final price = item['price'];
      final parsedPrice = price is num ? price.toDouble() : double.tryParse('$price') ?? 0.0;
      return _ReceiptLineItem(
        name: name == null || name.isEmpty ? 'Item' : name,
        price: parsedPrice,
      );
    }).toList();
  }

  String? _receiptStoragePathFromUrl(String reference) {
    final uri = Uri.tryParse(reference);
    if (uri == null || !uri.hasScheme) return null;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('receipts');
    if (bucketIndex == -1 || bucketIndex == segments.length - 1) return null;

    return segments.skip(bucketIndex + 1).join('/');
  }
}

class _ReceiptLineItem {
  const _ReceiptLineItem({required this.name, required this.price});

  final String name;
  final double price;
}
