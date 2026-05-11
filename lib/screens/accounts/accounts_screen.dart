import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/account.dart';
import '../../services/account_service.dart';
import '../../services/app_refresh_service.dart';
import '../../services/app_settings_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../widgets/dark_shell.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _accountService = AccountService();
  final _refreshService = AppRefreshService.instance;
  bool _loading = true;
  String? _error;
  List<AccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _refreshService.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    _refreshService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final accounts = await _accountService.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAccount() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AccountSheet(),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _editAccount(AccountModel account) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountSheet(account: account),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _linkCard(AccountModel account) async {
    final controller = TextEditingController();
    final digits = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Link card to ${account.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'Last 4 digits'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted) return;
    final cardLast4 = digits?.trim();
    if (cardLast4 == null || cardLast4.isEmpty) return;
    try {
      await _accountService.linkCardDigits(
        accountId: account.id,
        cardLast4: cardLast4,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not link card: $error')),
      );
    }
  }

  Future<void> _deleteAccount(AccountModel account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${account.name}?'),
        content: const Text(
          'This removes the account from your active accounts and unlinks saved card digits. Existing transactions stay in the ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _accountService.deleteAccount(account.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $error')),
      );
    }
  }

  Future<void> _manageCards(AccountModel account) async {
    if (account.linkedCardLast4.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${account.name} cards'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: account.linkedCardLast4
              .map(
                (card) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIconBadge(glyph: AppGlyph.card, size: 38),
                  title: Text('Card ****$card'),
                  subtitle: const Text('Used for receipt auto-routing'),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await _accountService.unlinkCardDigits(
                          accountId: account.id,
                          cardLast4: card,
                        );
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        await _load();
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not delete card: $error')),
                        );
                      }
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: AppConstants.errorRed),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DarkShell(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  children: [
                    ScreenHeader(
                      title: 'Accounts',
                      subtitle: 'Cash, banks, cards, and routing rules',
                      glyph: AppGlyph.accounts,
                      trailing: IconButton.filled(
                        onPressed: _addAccount,
                        icon: const Icon(Icons.add),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_error != null)
                      FinanceCard(
                        child: Text(
                          'Run the Supabase schema update to enable accounts.\n\n$_error',
                        ),
                      )
                    else if (_accounts.isEmpty)
                      FinanceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No accounts yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cash, bank, and card accounts will appear here.',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.62),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _addAccount,
                              icon: const Icon(Icons.add),
                              label: const Text('Add account'),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._accounts.map(
                        (account) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AccountCard(
                            account: account,
                            onEdit: () => _editAccount(account),
                            onLinkCard: () => _linkCard(account),
                            onManageCards: () => _manageCards(account),
                            onDelete: () => _deleteAccount(account),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onLinkCard,
    required this.onManageCards,
    required this.onDelete,
  });

  final AccountModel account;
  final VoidCallback onEdit;
  final VoidCallback onLinkCard;
  final VoidCallback onManageCards;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final negative = account.currentBalance < 0;
    final currency = account.currency.isNotEmpty
        ? account.currency
        : AppSettingsService.instance.preferredCurrency;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return FinanceCard(
      child: Row(
        children: [
          AppIconBadge(glyph: _glyphFor(account.type)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    account.type.label,
                    if (account.linkedCardLast4.isNotEmpty)
                      'card ${account.linkedCardLast4.map((d) => '****$d').join(', ')}',
                  ].join(' - '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency ${account.currentBalance.toStringAsFixed(0)}',
                style: TextStyle(
                  color: negative
                      ? AppConstants.errorRed
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  TextButton(onPressed: onEdit, child: const Text('Edit')),
                  TextButton(onPressed: onLinkCard, child: const Text('Link')),
                  if (account.linkedCardLast4.isNotEmpty)
                    TextButton(onPressed: onManageCards, child: const Text('Cards')),
                  TextButton(
                    onPressed: onDelete,
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: AppConstants.errorRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  AppGlyph _glyphFor(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return AppGlyph.cash;
      case AccountType.checking:
      case AccountType.savings:
        return AppGlyph.bank;
      case AccountType.credit:
        return AppGlyph.card;
      case AccountType.wallet:
        return AppGlyph.wallet;
      case AccountType.other:
        return AppGlyph.accounts;
    }
  }
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({this.account});

  final AccountModel? account;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final _name = TextEditingController();
  final _opening = TextEditingController();
  final _service = AccountService();
  final _exchangeRateService = ExchangeRateService();
  AccountType _type = AccountType.checking;
  String _currency = AppSettingsService.instance.preferredCurrency;
  String _originalCurrency = AppSettingsService.instance.preferredCurrency;
  bool _cashDefault = false;
  bool _saving = false;
  bool _convertingOpening = false;

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _name.text = account?.name ?? '';
    _opening.text = account?.openingBalance.toStringAsFixed(2) ?? '0';
    _type = account?.type ?? AccountType.checking;
    _currency = account?.currency.isNotEmpty == true
        ? account!.currency
        : AppSettingsService.instance.preferredCurrency;
    _originalCurrency = _currency;
    _cashDefault = account?.isDefaultCash ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final openingBalance = double.tryParse(_opening.text.trim());
    if (openingBalance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid opening balance.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final account = widget.account;
      if (account == null) {
        await _service.createAccount(
          name: _name.text.trim(),
          type: _type,
          openingBalance: openingBalance,
          currency: _currency,
          isDefaultCash: _cashDefault,
        );
      } else {
        await _service.updateAccount(
          accountId: account.id,
          name: _name.text.trim(),
          type: _type,
          openingBalance: openingBalance,
          currency: _currency,
          isDefaultCash: _cashDefault,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save account: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeCurrency(String nextCurrency) async {
    if (nextCurrency == _currency || _convertingOpening) return;

    final currentAmount = double.tryParse(_opening.text.trim());
    if (currentAmount == null) {
      setState(() => _currency = nextCurrency);
      return;
    }

    final fromCurrency = _currency;
    setState(() {
      _currency = nextCurrency;
      _convertingOpening = true;
    });

    try {
      final conversion = await _exchangeRateService.convert(
        amount: currentAmount.abs(),
        fromCurrency: fromCurrency,
        toCurrency: nextCurrency,
      );
      if (!mounted) return;
      final converted = currentAmount < 0
          ? -conversion.convertedAmount
          : conversion.convertedAmount;
      _opening.text = converted.toStringAsFixed(2);
    } catch (error) {
      if (!mounted) return;
      setState(() => _currency = fromCurrency);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not convert $fromCurrency to $nextCurrency: $error')),
      );
    } finally {
      if (mounted) setState(() => _convertingOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editing ? 'Edit account' : 'Add account',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            items: AccountType.values
                .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? AccountType.other),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            items: AppSettingsService.supportedCurrencies
                .map((currency) => DropdownMenuItem(value: currency, child: Text(currency)))
                .toList(),
            onChanged: _convertingOpening
                ? null
                : (value) {
                    if (value != null) _changeCurrency(value);
                  },
            decoration: const InputDecoration(labelText: 'Account currency'),
          ),
          if (_convertingOpening) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Opening balance ($_currency)',
              helperText: _editing && _currency != _originalCurrency
                  ? 'Converted from $_originalCurrency to preserve this account value.'
                  : null,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _cashDefault,
            onChanged: (value) => setState(() => _cashDefault = value ?? false),
            title: const Text('Default cash account'),
          ),
          ElevatedButton(
            onPressed: _saving || _convertingOpening ? null : _save,
            child: Text(
              _saving
                  ? 'Saving...'
                  : _convertingOpening
                      ? 'Converting...'
                      : (_editing ? 'Save changes' : 'Save account'),
            ),
          ),
        ],
      ),
    );
  }
}
