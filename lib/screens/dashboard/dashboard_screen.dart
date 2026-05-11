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
                        const SizedBox(height: 12),
                        _NetWorthCard(summary: _summary, spent: _totalSpent, income: _totalIncome),
                        const SizedBox(height: 14),
                        _AccountStrip(accounts: _summary?.accounts ?? const []),
                        const SizedBox(height: 20),
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
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Row(
        children: [
          const AppLogoMark(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ClearLedger',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Money movement cockpit',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final balance = summary?.netWorth ?? income - spent;
    return FinanceHeroPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net worth',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AmountText(
                      amount: balance,
                      currency: currency,
                      compact: false,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up_rounded, color: scheme.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 62,
            width: double.infinity,
            child: CustomPaint(
              painter: _BalanceSparklinePainter(
                lineColor: scheme.primary,
                fillColor: scheme.primary.withValues(alpha: 0.14),
                gridColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Inflow',
                  value: '+$currency ${income.toStringAsFixed(0)}',
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: 'Spent',
                  value: '-$currency ${spent.toStringAsFixed(0)}',
                  color: const Color(0xFFFFB4AB),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
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
      return const FinanceSurface(
        child: Text('Create accounts to track cash, banks, and cards.'),
      );
    }

    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.take(5).length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final account = accounts[index];
          return SizedBox(
            width: 178,
            child: FinanceSurface(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppIconBadge(glyph: _glyphForAccount(account.type), size: 38),
                      const Spacer(),
                      Text(
                        account.currency.isNotEmpty
                            ? account.currency
                            : preferredCurrency,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.56),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    minHeight: 4,
                    value: (account.currentBalance.abs() % 100000) / 100000,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.28),
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  AppGlyph _glyphForAccount(AccountType type) {
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

class _BalanceSparklinePainter extends CustomPainter {
  const _BalanceSparklinePainter({
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final y in [0.28, 0.56, 0.84]) {
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * y),
        gridPaint,
      );
    }

    final points = <Offset>[
      Offset(0, size.height * 0.78),
      Offset(size.width * 0.12, size.height * 0.70),
      Offset(size.width * 0.22, size.height * 0.74),
      Offset(size.width * 0.34, size.height * 0.48),
      Offset(size.width * 0.47, size.height * 0.55),
      Offset(size.width * 0.60, size.height * 0.34),
      Offset(size.width * 0.73, size.height * 0.38),
      Offset(size.width * 0.86, size.height * 0.21),
      Offset(size.width, size.height * 0.28),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _BalanceSparklinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
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
