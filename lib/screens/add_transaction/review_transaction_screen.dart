import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/account.dart';
import '../../models/parsed_transaction.dart';
import '../../models/transaction.dart';
import '../../services/account_service.dart';
import '../../services/app_settings_service.dart';
import '../../services/budget_alert_service.dart';
import '../../services/budget_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/dark_shell.dart';

class ReviewTransactionScreen extends StatefulWidget {
  const ReviewTransactionScreen({
    super.key,
    required this.parsed,
    required this.inputMethod,
  });

  final ParsedTransaction parsed;
  final String inputMethod;

  @override
  State<ReviewTransactionScreen> createState() => _ReviewTransactionScreenState();
}

class _ReviewTransactionScreenState extends State<ReviewTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _transactionService = TransactionService();
  final _budgetService = BudgetService();
  final _accountService = AccountService();
  final _settingsService = AppSettingsService.instance;
  final _exchangeRateService = ExchangeRateService();

  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _feeController;
  Timer? _conversionDebounce;

  List<AccountModel> _accounts = [];
  TransactionType _transactionType = TransactionType.expense;
  String? _accountId;
  String? _destinationAccountId;
  AccountModel? _detectedAccount;
  bool _unlinkedDetectedCard = false;
  late String _category;
  late DateTime _date;
  late String _receiptCurrency;
  String _preferredCurrency = 'JMD';
  CurrencyConversion? _conversion;
  String? _conversionError;
  bool _saving = false;
  bool _loadingAccounts = true;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.parsed.merchant ?? '');
    _amountController = TextEditingController(
      text: widget.parsed.amount?.toStringAsFixed(2) ?? '',
    );
    _descriptionController = TextEditingController(text: widget.parsed.description ?? '');
    _feeController = TextEditingController(
      text: widget.parsed.feeAmount?.toStringAsFixed(2) ?? '',
    );
    _amountController.addListener(_scheduleConversion);
    _transactionType = transactionTypeFromString(widget.parsed.transactionType);
    _receiptCurrency = _normalizeCurrency(widget.parsed.currency);
    _category = AppConstants.categories.contains(widget.parsed.category)
        ? widget.parsed.category
        : 'Other';
    _date = DateTime.tryParse(widget.parsed.date ?? '') ?? DateTime.now();
    _bootstrap();
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    _conversionDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _settingsService.load();
    if (!mounted) return;
    setState(() => _preferredCurrency = _settingsService.preferredCurrency);
    _refreshConversion();
  }

  Future<void> _bootstrap() async {
    await _loadSettings();
    await _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      var accounts = await _accountService.getAccounts();
      if (accounts.isEmpty) {
        final cash = await _accountService.createAccount(
          name: 'Cash Wallet',
          type: AccountType.cash,
          currency: _preferredCurrency,
          isDefaultCash: true,
        );
        accounts = [cash];
      }
      AccountModel? detected;
      if (widget.parsed.cardLast4 != null) {
        detected = await _accountService.findAccountForCard(widget.parsed.cardLast4);
      }
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _detectedAccount = detected;
        _unlinkedDetectedCard = widget.parsed.cardLast4 != null && detected == null;
        _reconcileAccountSelection();
      });
    } catch (_) {
      // Schema may not be applied yet. The save call will surface the real issue.
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  void _reconcileAccountSelection() {
    if (_accountId != null && !_accounts.any((account) => account.id == _accountId)) {
      _accountId = null;
    }
    if (_destinationAccountId != null &&
        !_accounts.any((account) => account.id == _destinationAccountId)) {
      _destinationAccountId = null;
    }

    final cash = _cashAccount() ?? (_accounts.isEmpty ? null : _accounts.first);
    final detected = _detectedAccount;
    final hasCard = widget.parsed.cardLast4 != null;

    switch (_transactionType) {
      case TransactionType.withdrawal:
        _accountId = detected?.id ?? _accountId;
        _destinationAccountId = cash?.id;
        break;
      case TransactionType.deposit:
        _accountId = cash?.id ?? _accountId;
        _destinationAccountId = detected?.id ?? _destinationAccountId;
        break;
      case TransactionType.transfer:
        _accountId = detected?.id ?? _accountId;
        _destinationAccountId ??= _firstAccountExcept(_accountId)?.id;
        break;
      case TransactionType.expense:
      case TransactionType.income:
      case TransactionType.refund:
        _destinationAccountId = null;
        _accountId = detected?.id ?? (hasCard ? _accountId : cash?.id);
        break;
    }
  }

  AccountModel? _cashAccount() {
    for (final account in _accounts) {
      if (account.isDefaultCash || account.type == AccountType.cash) {
        return account;
      }
    }
    return null;
  }

  AccountModel? _firstAccountExcept(String? accountId) {
    for (final account in _accounts) {
      if (account.id != accountId) return account;
    }
    return null;
  }

  AccountModel? _accountById(String? accountId) {
    if (accountId == null) return null;
    for (final account in _accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  void _scheduleConversion() {
    _conversionDebounce?.cancel();
    _conversionDebounce = Timer(
      const Duration(milliseconds: 450),
      _refreshConversion,
    );
  }

  Future<void> _refreshConversion() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _receiptCurrency == _preferredCurrency) {
      if (!mounted) return;
      setState(() {
        _conversion = null;
        _conversionError = null;
        _converting = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _converting = true;
      _conversionError = null;
    });

    try {
      final conversion = await _exchangeRateService.convert(
        amount: amount,
        fromCurrency: _receiptCurrency,
        toCurrency: _preferredCurrency,
      );
      if (!mounted) return;
      setState(() {
        _conversion = conversion;
        _conversionError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _conversion = null;
        _conversionError = error.toString();
      });
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<CurrencyConversion> _conversionForSave(double amount) async {
    if (_receiptCurrency == _preferredCurrency) {
      return CurrencyConversion(
        originalAmount: amount,
        convertedAmount: amount,
        fromCurrency: _receiptCurrency,
        toCurrency: _preferredCurrency,
        exchangeRate: 1,
      );
    }
    return _exchangeRateService.convert(
      amount: amount,
      fromCurrency: _receiptCurrency,
      toCurrency: _preferredCurrency,
    );
  }

  String _normalizeCurrency(String currency) {
    final normalized = currency.trim().toUpperCase();
    return RegExp(r'^[A-Z]{3}$').hasMatch(normalized) ? normalized : 'JMD';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_unlinkedDetectedCard) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Link card ****${widget.parsed.cardLast4} to an account before saving.',
          ),
        ),
      );
      return;
    }

    if (_accounts.isNotEmpty && _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the account for this movement.')),
      );
      return;
    }

    if (_transactionType.isTransfer && _destinationAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the destination account for this movement.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final originalAmount = double.parse(_amountController.text.trim());
      final conversion = await _conversionForSave(originalAmount);
      await _transactionService.createTransaction(
        amount: conversion.convertedAmount,
        currency: conversion.toCurrency,
        originalAmount: conversion.converted ? conversion.originalAmount : null,
        originalCurrency: conversion.converted ? conversion.fromCurrency : null,
        exchangeRate: conversion.converted ? conversion.exchangeRate : null,
        transactionType: _transactionType,
        merchant: _merchantController.text.trim().isEmpty
            ? null
            : _merchantController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        transactionDate: _date,
        inputMethod: widget.inputMethod,
        accountId: _accountId,
        destinationAccountId: _destinationAccountId,
        cardLast4: widget.parsed.cardLast4,
        feeAmount: double.tryParse(_feeController.text.trim()),
        receiptImageUrl: widget.parsed.persistentReceiptReference,
        rawLlmResponse: widget.parsed.rawLlmResponse,
      );

      final over = await _budgetService.getOverspentBudgets(month: _date);
      await BudgetAlertService.instance.notifyNewOverspentBudgets(over, month: _date);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save transaction: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _linkDetectedCardToSelectedAccount() async {
    final card = widget.parsed.cardLast4;
    final account = _accountById(_cardLinkCandidateAccountId());
    if (card == null || account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an account to link this card to.')),
      );
      return;
    }

    try {
      await _accountService.linkCardDigits(accountId: account.id, cardLast4: card);
      if (!mounted) return;
      setState(() {
        _detectedAccount = account;
        _unlinkedDetectedCard = false;
        _accountId = _transactionType == TransactionType.deposit ? _accountId : account.id;
        if (_transactionType == TransactionType.deposit) {
          _destinationAccountId = account.id;
        }
        _reconcileAccountSelection();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Card ****$card linked to ${account.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not link card: $error')),
      );
    }
  }

  String? _cardLinkCandidateAccountId() {
    if (_transactionType == TransactionType.deposit) {
      return _destinationAccountId;
    }
    return _accountId;
  }

  Future<void> _createAccountForDetectedCard() async {
    final card = widget.parsed.cardLast4;
    if (card == null) return;

    final nameController = TextEditingController(text: 'Card ****$card');
    final openingController = TextEditingController(text: '0');
    var type = AccountType.checking;

    final created = await showDialog<AccountModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Create account for ****$card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                initialValue: type,
                items: AccountType.values
                    .where((value) => value != AccountType.cash)
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => type = value ?? type),
                decoration: const InputDecoration(labelText: 'Account type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: openingController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Opening balance ($_preferredCurrency)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final account = await _accountService.createAccount(
                    name: name,
                    type: type,
                    openingBalance: double.tryParse(openingController.text.trim()) ?? 0,
                    currency: _preferredCurrency,
                  );
                  await _accountService.linkCardDigits(
                    accountId: account.id,
                    cardLast4: card,
                  );
                  if (context.mounted) Navigator.of(context).pop(account);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not create account: $error')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    openingController.dispose();

    if (created == null || !mounted) return;
    final accounts = await _accountService.getAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _detectedAccount = created;
      _unlinkedDetectedCard = false;
      if (_transactionType == TransactionType.deposit) {
        _destinationAccountId = created.id;
      } else {
        _accountId = created.id;
      }
      _reconcileAccountSelection();
    });
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

  @override
  Widget build(BuildContext context) {
    final confidence = (widget.parsed.confidence * 100).toStringAsFixed(0);
    final receiptCurrencyOptions = {
      _receiptCurrency,
      ...AppSettingsService.supportedCurrencies,
    }.toList();

    return Scaffold(
      body: DarkShell(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Review movement',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FinanceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.document_scanner_outlined, color: AppConstants.mint),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_transactionType.label} detected',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text('$confidence%', style: const TextStyle(color: AppConstants.mint)),
                      ],
                    ),
                    if (widget.parsed.cardLast4 != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _unlinkedDetectedCard
                            ? 'Card ****${widget.parsed.cardLast4} needs an account link'
                            : 'Card ****${widget.parsed.cardLast4} found on receipt',
                        style: TextStyle(
                          color: _unlinkedDetectedCard
                              ? AppConstants.warningAmber
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _typeSelector(),
              const SizedBox(height: 14),
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(labelText: 'Merchant / source'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount ($_receiptCurrency)'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Amount is required';
                  if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _receiptCurrency,
                items: receiptCurrencyOptions
                    .map((currency) => DropdownMenuItem(value: currency, child: Text(currency)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _receiptCurrency = value);
                  _refreshConversion();
                },
                decoration: const InputDecoration(labelText: 'Receipt currency'),
              ),
              if (_receiptCurrency != _preferredCurrency) ...[
                const SizedBox(height: 12),
                _conversionNotice(),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: AppConstants.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) => setState(() => _category = value ?? 'Other'),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              if (_loadingAccounts)
                const LinearProgressIndicator()
              else if (_accounts.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  items: _accounts
                      .map((account) => DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _accountId = value),
                  decoration: InputDecoration(
                    labelText: _transactionType == TransactionType.deposit
                        ? 'From account'
                        : 'Account',
                  ),
                ),
                if (_transactionType.isTransfer) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _destinationAccountId,
                    items: _accounts
                        .map((account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(account.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _destinationAccountId = value),
                    decoration: const InputDecoration(labelText: 'Destination account'),
                  ),
                ],
                if (_unlinkedDetectedCard) ...[
                  const SizedBox(height: 12),
                  _unlinkedCardPrompt(),
                ],
              ],
              if (_transactionType.isTransfer) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _feeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Fee, if any'),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              FinanceCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date: ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    TextButton(onPressed: _pickDate, child: const Text('Change')),
                  ],
                ),
              ),
              if (widget.parsed.lineItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Line items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                FinanceCard(
                  child: Column(
                    children: widget.parsed.lineItems
                        .map(
                          (item) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.name),
                            trailing: Text('$_receiptCurrency ${item.price.toStringAsFixed(2)}'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Save ${_transactionType.label.toLowerCase()}'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversionNotice() {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    if (_converting) {
      return const FinanceCard(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Expanded(child: Text('Updating conversion...')),
          ],
        ),
      );
    }

    if (_conversionError != null) {
      return FinanceCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          'Could not convert $_receiptCurrency to $_preferredCurrency yet. Saving will retry.',
          style: const TextStyle(color: AppConstants.warningAmber),
        ),
      );
    }

    final conversion = _conversion;
    return FinanceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.currency_exchange, color: AppConstants.mint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              conversion == null
                  ? 'This will save in $_preferredCurrency.'
                  : 'Saves as $_preferredCurrency ${conversion.convertedAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            ExchangeRateService.attributionName,
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _unlinkedCardPrompt() {
    final selected = _accountById(_cardLinkCandidateAccountId());
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return FinanceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_off_outlined, color: AppConstants.warningAmber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Unknown card ****${widget.parsed.cardLast4}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selected == null
                ? 'Choose or create the account this card belongs to before saving.'
                : 'Link this card to ${selected.name} so future receipts route automatically.',
            style: TextStyle(color: muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: selected == null ? null : _linkDetectedCardToSelectedAccount,
                icon: const Icon(Icons.link),
                label: const Text('Link selected'),
              ),
              OutlinedButton.icon(
                onPressed: _createAccountForDetectedCard,
                icon: const Icon(Icons.add),
                label: const Text('Create account'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeSelector() {
    final types = [
      TransactionType.expense,
      TransactionType.income,
      TransactionType.withdrawal,
      TransactionType.deposit,
      TransactionType.transfer,
      TransactionType.refund,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final selected = _transactionType == type;
        return ChoiceChip(
          selected: selected,
          label: Text(type.label),
          avatar: Icon(_iconForType(type), size: 18),
          onSelected: (_) => setState(() {
            _transactionType = type;
            _reconcileAccountSelection();
          }),
        );
      }).toList(),
    );
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return Icons.trending_down;
      case TransactionType.income:
        return Icons.trending_up;
      case TransactionType.withdrawal:
        return Icons.atm_outlined;
      case TransactionType.deposit:
        return Icons.savings_outlined;
      case TransactionType.transfer:
        return Icons.compare_arrows;
      case TransactionType.refund:
        return Icons.replay;
    }
  }
}
