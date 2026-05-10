import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/account.dart';
import '../../models/budget.dart';
import '../../models/transaction.dart';
import '../../services/account_service.dart';
import '../../services/app_settings_service.dart';
import '../../services/budget_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/budget_progress_bar.dart';
import '../../widgets/dark_shell.dart';
import '../../widgets/transaction_tile.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _txService = TransactionService();
  final _budgetService = BudgetService();
  final _accountService = AccountService();

  bool _loading = true;
  double _totalSpent = 0;
  double _totalIncome = 0;
  List<TransactionModel> _recent = [];
  List<BudgetModel> _budgets = [];
  AccountBalanceSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final month = DateTime.now();
      final total = await _txService.getTotalSpentForMonth(month);
      final income = await _txService.getTotalIncomeForMonth(month);
      final recent = await _txService.getRecentTransactions(limit: 5);
      final budgets = await _budgetService.getBudgets(month: month);
      AccountBalanceSummary? summary;
      try {
        summary = await _accountService.getBalanceSummary();
      } catch (_) {
        summary = null;
      }

      if (!mounted) return;
      setState(() {
        _totalSpent = total;
        _totalIncome = income;
        _recent = recent;
        _budgets = budgets;
        _summary = summary;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DarkShell(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        _Header(onSettings: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        }),
                        const SizedBox(height: 18),
                        _NetWorthCard(summary: _summary, spent: _totalSpent, income: _totalIncome),
                        const SizedBox(height: 18),
                        _AccountStrip(accounts: _summary?.accounts ?? const []),
                        const SizedBox(height: 22),
                        SectionHeading(
                          title: 'Recent activity',
                          trailing: '${_recent.length} items',
                        ),
                        const SizedBox(height: 8),
                        if (_recent.isEmpty)
                          const FinanceCard(child: Text('No transactions yet.'))
                        else
                          ..._recent.map((tx) => TransactionTile(transaction: tx)),
                        const SizedBox(height: 18),
                        const SectionHeading(title: 'Budget pulse'),
                        const SizedBox(height: 8),
                        if (_budgets.isEmpty)
                          const FinanceCard(
                            child: Text('No budgets set for this month.'),
                          )
                        else
                          ..._budgets.take(3).map((b) => BudgetProgressBar(budget: b)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return ScreenHeader(
      title: 'Dashboard',
      subtitle: 'Money movement, neatly tracked',
      showLogo: true,
      trailing: IconButton.filledTonal(
        onPressed: onSettings,
        icon: const Icon(Icons.settings_outlined),
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.summary,
    required this.spent,
    required this.income,
  });

  final AccountBalanceSummary? summary;
  final double spent;
  final double income;

  @override
  Widget build(BuildContext context) {
    final currency = AppSettingsService.instance.preferredCurrency;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return FinanceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(icon: Icons.account_balance_wallet_outlined, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Net worth',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AmountText(
            amount: summary?.netWorth ?? income - spent,
            currency: currency,
            compact: false,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Inflow',
                  value: '+$currency ${income.toStringAsFixed(0)}',
                  color: AppConstants.successGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: 'Spent',
                  value: '-$currency ${spent.toStringAsFixed(0)}',
                  color: AppConstants.errorRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.04) : AppConstants.lightStroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _AccountStrip extends StatelessWidget {
  const _AccountStrip({required this.accounts});

  final List<AccountModel> accounts;

  @override
  Widget build(BuildContext context) {
    final preferredCurrency = AppSettingsService.instance.preferredCurrency;
    if (accounts.isEmpty) {
      return const FinanceCard(
        child: Text('Create accounts to track cash, banks, and cards.'),
      );
    }

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.take(5).length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final account = accounts[index];
          return SizedBox(
            width: 208,
            child: FinanceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconBadge(icon: _iconForAccount(account.type), size: 38),
                  const Spacer(),
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  AmountText(
                    amount: account.currentBalance,
                    currency: account.currency.isNotEmpty ? account.currency : preferredCurrency,
                    compact: true,
                    color: account.currentBalance < 0
                        ? AppConstants.errorRed
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconForAccount(AccountType type) {
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FinanceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load dashboard: $message'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
