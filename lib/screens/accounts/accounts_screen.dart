import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/account.dart';
import '../../services/account_service.dart';
import '../../services/app_settings_service.dart';
import '../../widgets/dark_shell.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _accountService = AccountService();
  bool _loading = true;
  String? _error;
  List<AccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountSheet(onSaved: _load),
    );
  }

  Future<void> _linkCard(AccountModel account) async {
    final controller = TextEditingController();
    await showDialog<void>(
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
            onPressed: () async {
              try {
                await _accountService.linkCardDigits(
                  accountId: account.id,
                  cardLast4: controller.text,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                _load();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not link card: $error')),
                );
              }
            },
            child: const Text('Save'),
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
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Accounts',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Cash, banks, cards, and routing rules',
                                style: TextStyle(color: AppConstants.darkMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          onPressed: _addAccount,
                          icon: const Icon(Icons.add),
                        ),
                      ],
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
                            const Text(
                              'Create a cash account, then add bank or card accounts.',
                              style: TextStyle(color: AppConstants.darkMuted),
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
                            onLinkCard: () => _linkCard(account),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    const FinanceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How automatic routing works',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'If a receipt shows linked card digits, ClearLedger assigns the transaction to that account. ATM withdrawals move money from that account into cash. Deposits move cash into the bank account.',
                            style: TextStyle(color: AppConstants.darkMuted, height: 1.35),
                          ),
                        ],
                      ),
                    ),
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
    required this.onLinkCard,
  });

  final AccountModel account;
  final VoidCallback onLinkCard;

  @override
  Widget build(BuildContext context) {
    final negative = account.currentBalance < 0;
    final currency = account.currency.isNotEmpty
        ? account.currency
        : AppSettingsService.instance.preferredCurrency;
    return FinanceCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppConstants.mint.withValues(alpha: 0.16),
            child: Icon(_iconFor(account.type), color: AppConstants.mint),
          ),
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
                  style: const TextStyle(color: AppConstants.darkMuted, fontSize: 12),
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
              TextButton(onPressed: onLinkCard, child: const Text('Link card')),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.checking:
      case AccountType.savings:
        return Icons.account_balance_outlined;
      case AccountType.credit:
        return Icons.credit_card_outlined;
      case AccountType.wallet:
        return Icons.account_balance_wallet_outlined;
      case AccountType.other:
        return Icons.savings_outlined;
    }
  }
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({required this.onSaved});

  final VoidCallback onSaved;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final _name = TextEditingController();
  final _opening = TextEditingController(text: '0');
  final _service = AccountService();
  AccountType _type = AccountType.checking;
  bool _cashDefault = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _service.createAccount(
        name: _name.text.trim(),
        type: _type,
        openingBalance: double.tryParse(_opening.text.trim()) ?? 0,
        currency: AppSettingsService.instance.preferredCurrency,
        isDefaultCash: _cashDefault,
      );
      widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add account: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = AppSettingsService.instance.preferredCurrency;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
          TextField(
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Opening balance ($currency)'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _cashDefault,
            onChanged: (value) => setState(() => _cashDefault = value ?? false),
            title: const Text('Default cash account'),
          ),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save account'),
          ),
        ],
      ),
    );
  }
}
