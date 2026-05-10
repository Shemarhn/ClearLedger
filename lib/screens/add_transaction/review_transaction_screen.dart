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

  List<AccountModel> _accounts = [];
  TransactionType _transactionType = TransactionType.expense;
  String? _accountId;
  String? _destinationAccountId;
  AccountModel? _detectedAccount;
  bool _unlinkedDetectedCard = false;
  late String _category;
  late DateTime _date;
  late String _receiptCurrency;
  late double _receiptAmount;
  String _preferredCurrency = 'JMD';
  CurrencyConversion? _conversion;
  String? _conversionError;
  bool _saving = false;
  bool _loadingAccounts = true;
  bool _converting = false;
  bool _linkingDetectedCard = false;
  bool _creatingDetectedAccount = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.parsed.merchant ?? '');
    _receiptAmount = _initialReceiptAmount(widget.parsed);
    _amountController = TextEditingController(text: _receiptAmount.toStringAsFixed(2));
    _descriptionController = TextEditingController(text: widget.parsed.description ?? '');
    _feeController = TextEditingController(
      text: widget.parsed.feeAmount?.toStringAsFixed(2) ?? '',
    );
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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    await _settingsService.load();
    if (!mounted) return;
    setState(() => _preferredCurrency = _settingsService.preferredCurrency);
    await _refreshConversion(updateAmountField: true);
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
      await _refreshConversion(updateAmountField: true);
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

  Future<void> _refreshConversion({bool updateAmountField = false}) async {
    final amountCurrency = _amountCurrency;
    if (_receiptAmount <= 0 || _receiptCurrency == amountCurrency) {
      if (!mounted) return;
      setState(() {
        _conversion = null;
        _conversionError = null;
        _converting = false;
      });
      if (updateAmountField) {
        _setAmountText(_receiptAmount);
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _converting = true;
      _conversionError = null;
    });

    try {
      final conversion = await _exchangeRateService.convert(
        amount: _receiptAmount,
        fromCurrency: _receiptCurrency,
        toCurrency: amountCurrency,
      );
      if (!mounted) return;
      setState(() {
        _conversion = conversion;
        _conversionError = null;
      });
      if (updateAmountField) {
        _setAmountText(conversion.convertedAmount);
      }
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

  Future<CurrencyConversion> _conversionForSave() async {
    final amountCurrency = _amountCurrency;
    if (_receiptCurrency == amountCurrency) {
      return CurrencyConversion(
        originalAmount: _receiptAmount,
        convertedAmount: _receiptAmount,
        fromCurrency: _receiptCurrency,
        toCurrency: amountCurrency,
        exchangeRate: 1,
      );
    }
    return _exchangeRateService.convert(
      amount: _receiptAmount,
      fromCurrency: _receiptCurrency,
      toCurrency: amountCurrency,
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
      final accountAmount = double.parse(_amountController.text.trim());
      final conversion = await _conversionForSave();
      final effectiveRate =
          conversion.converted && _receiptAmount > 0 ? accountAmount / _receiptAmount : null;
      await _transactionService.createTransaction(
        amount: accountAmount,
        currency: conversion.toCurrency,
        originalAmount: conversion.converted ? _receiptAmount : null,
        originalCurrency: conversion.converted ? conversion.fromCurrency : null,
        exchangeRate: effectiveRate,
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
    if (_linkingDetectedCard) return;

    final card = widget.parsed.cardLast4;
    final account = _accountById(_cardLinkCandidateAccountId());
    if (card == null || account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an account to link this card to.')),
      );
      return;
    }

    try {
      setState(() => _linkingDetectedCard = true);
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
      await _refreshConversion(updateAmountField: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Card ****$card linked to ${account.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not link card: $error')),
      );
    } finally {
      if (mounted) setState(() => _linkingDetectedCard = false);
    }
  }

  String? _cardLinkCandidateAccountId() {
    if (_transactionType == TransactionType.deposit) {
      return _destinationAccountId;
    }
    return _accountId;
  }

  Future<void> _createAccountForDetectedCard() async {
    if (_creatingDetectedAccount) return;

    final card = widget.parsed.cardLast4;
    if (card == null) return;

    final draft = await showDialog<_DetectedCardAccountDraft>(
      context: context,
      builder: (_) => _DetectedCardAccountDialog(
        cardLast4: card,
        currency: _amountCurrency,
      ),
    );

    if (draft == null || !mounted) return;

    setState(() => _creatingDetectedAccount = true);
    try {
      final created = await _accountService.createAccount(
        name: draft.name,
        type: draft.type,
        openingBalance: draft.openingBalance,
        currency: draft.currency,
      );
      await _accountService.linkCardDigits(accountId: created.id, cardLast4: card);

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
      await _refreshConversion(updateAmountField: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Card ****$card linked to ${created.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create account: $error')),
      );
    } finally {
      if (mounted) setState(() => _creatingDetectedAccount = false);
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
      if (!mounted) return;
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
              ScreenHeader(
                title: 'Review movement',
                subtitle: 'Confirm the detected details before saving',
                glyph: AppGlyph.document,
                trailing: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              const SizedBox(height: 16),
              FinanceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppIconBadge(glyph: AppGlyph.scan, size: 42),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_transactionType.label} detected',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '$confidence%',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
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
                decoration: InputDecoration(labelText: 'Amount ($_amountCurrency)'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Amount is required';
                  final amount = double.tryParse(value.trim());
                  if (amount == null) return 'Enter a valid number';
                  if (amount <= 0) return 'Amount must be greater than zero';
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
                  _refreshConversion(updateAmountField: true);
                },
                decoration: const InputDecoration(labelText: 'Receipt currency'),
              ),
              if (_receiptCurrency != _amountCurrency) ...[
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
                            child: Text(
                              '${account.name} (${account.currency})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _accountId = value);
                    _refreshConversion(updateAmountField: true);
                  },
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
                              child: Text(
                                '${account.name} (${account.currency})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _destinationAccountId = value);
                      _refreshConversion(updateAmountField: true);
                    },
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
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final fee = double.tryParse(trimmed);
                    if (fee == null) return 'Enter a valid fee';
                    if (fee < 0) return 'Fee cannot be negative';
                    return null;
                  },
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
                const SectionHeading(title: 'Line items'),
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
          'Could not convert $_receiptCurrency to $_amountCurrency yet. Saving will retry.',
          style: const TextStyle(color: AppConstants.warningAmber),
        ),
      );
    }

    final conversion = _conversion;
    return FinanceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const AppIconBadge(glyph: AppGlyph.exchange, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              conversion == null
                  ? 'Receipt total: $_receiptCurrency ${_receiptAmount.toStringAsFixed(2)}.'
                  : 'Receipt total: $_receiptCurrency ${_receiptAmount.toStringAsFixed(2)} -> $_amountCurrency ${conversion.convertedAmount.toStringAsFixed(2)}',
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
              const AppIconBadge(
                glyph: AppGlyph.card,
                color: AppConstants.warningAmber,
                size: 38,
              ),
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
                onPressed: selected == null || _linkingDetectedCard || _creatingDetectedAccount
                    ? null
                    : _linkDetectedCardToSelectedAccount,
                icon: const Icon(Icons.link),
                label: Text(_linkingDetectedCard ? 'Linking...' : 'Link selected'),
              ),
              OutlinedButton.icon(
                onPressed: _linkingDetectedCard || _creatingDetectedAccount
                    ? null
                    : _createAccountForDetectedCard,
                icon: const Icon(Icons.add),
                label: Text(_creatingDetectedAccount ? 'Creating...' : 'Create account'),
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
          onSelected: (_) {
            setState(() {
              _transactionType = type;
              _reconcileAccountSelection();
            });
            _refreshConversion(updateAmountField: true);
          },
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

  String get _amountCurrency {
    final account = _accountById(_amountAccountId);
    return _normalizeCurrency(account?.currency ?? _preferredCurrency);
  }

  String? get _amountAccountId {
    if (_transactionType == TransactionType.deposit) {
      return _destinationAccountId ?? _accountId;
    }
    return _accountId ?? _destinationAccountId;
  }

  double _initialReceiptAmount(ParsedTransaction parsed) {
    final lineTotal = parsed.lineItems.fold<double>(0, (sum, item) => sum + item.price);
    final parsedAmount = parsed.amount;
    if (parsedAmount == null || parsedAmount <= 0) {
      return lineTotal > 0 ? lineTotal : 0;
    }
    if (lineTotal > parsedAmount + 0.01) {
      return lineTotal;
    }
    return parsedAmount;
  }

  void _setAmountText(double value) {
    final next = value.toStringAsFixed(2);
    if (_amountController.text == next) return;
    _amountController.text = next;
  }
}

class _DetectedCardAccountDraft {
  const _DetectedCardAccountDraft({
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.currency,
  });

  final String name;
  final AccountType type;
  final double openingBalance;
  final String currency;
}

class _DetectedCardAccountDialog extends StatefulWidget {
  const _DetectedCardAccountDialog({
    required this.cardLast4,
    required this.currency,
  });

  final String cardLast4;
  final String currency;

  @override
  State<_DetectedCardAccountDialog> createState() => _DetectedCardAccountDialogState();
}

class _DetectedCardAccountDialogState extends State<_DetectedCardAccountDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _openingController;
  late String _currency;
  AccountType _type = AccountType.checking;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Card ****${widget.cardLast4}');
    _openingController = TextEditingController(text: '0');
    _currency = widget.currency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create account for ****${widget.cardLast4}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Account name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              items: AccountType.values
                  .where((value) => value != AccountType.cash)
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
              decoration: const InputDecoration(labelText: 'Account type'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              items: AppSettingsService.supportedCurrencies
                  .map((currency) => DropdownMenuItem(value: currency, child: Text(currency)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _currency = value);
              },
              decoration: const InputDecoration(labelText: 'Account currency'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _openingController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Opening balance ($_currency)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              _DetectedCardAccountDraft(
                name: name,
                type: _type,
                openingBalance: double.tryParse(_openingController.text.trim()) ?? 0,
                currency: _currency,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
