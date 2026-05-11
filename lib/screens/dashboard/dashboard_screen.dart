import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/account.dart';
import '../../models/budget.dart';
import '../../models/transaction.dart';
import '../../services/account_service.dart';
import '../../services/app_refresh_service.dart';
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
  final _refreshService = AppRefreshService.instance;

  bool _loading = true;
  double _totalSpent = 0;
  double _totalIncome = 0;
  List<TransactionModel> _recent = [];
  List<BudgetModel> _budgets = [];
  List<AccountBalancePoint> _history = [];
  AccountBalanceSummary? _summary;
  String? _error;

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
      List<AccountBalancePoint> history = const [];
      try {
        history = await _accountService.getNetWorthHistory(days: 30);
      } catch (_) {
        history = const [];
      }

      if (!mounted) return;
      setState(() {
        _totalSpent = total;
        _totalIncome = income;
        _recent = recent;
        _budgets = budgets;
        _summary = summary;
        _history = history;
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
                        _NetWorthCard(
                          summary: _summary,
                          spent: _totalSpent,
                          income: _totalIncome,
                          history: _history,
                        ),
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
    required this.history,
  });

  final AccountBalanceSummary? summary;
  final double spent;
  final double income;
  final List<AccountBalancePoint> history;

  @override
  Widget build(BuildContext context) {
    final currency = AppSettingsService.instance.preferredCurrency;
    final scheme = Theme.of(context).colorScheme;
    final balance = summary?.netWorth ?? income - spent;
    final trendDelta = history.length < 2 ? 0.0 : history.last.balance - history.first.balance;
    final rising = trendDelta >= 0;
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
                  color: rising ? scheme.primary : AppConstants.errorRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  rising ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: scheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InteractiveBalanceChart(
            points: history,
            currency: currency,
            lineColor: rising ? scheme.primary : AppConstants.errorRed,
            fillColor: (rising ? scheme.primary : AppConstants.errorRed)
                .withValues(alpha: 0.14),
            gridColor: Colors.white.withValues(alpha: 0.08),
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

class _InteractiveBalanceChart extends StatefulWidget {
  const _InteractiveBalanceChart({
    required this.points,
    required this.currency,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<AccountBalancePoint> points;
  final String currency;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  State<_InteractiveBalanceChart> createState() => _InteractiveBalanceChartState();
}

class _InteractiveBalanceChartState extends State<_InteractiveBalanceChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex == null || widget.points.isEmpty
        ? null
        : widget.points[_selectedIndex!.clamp(0, widget.points.length - 1)];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => _selectNearest(details.localPosition.dx),
      onLongPressMoveUpdate: (details) => _selectNearest(details.localPosition.dx),
      onLongPressEnd: (_) => setState(() => _selectedIndex = null),
      onPanStart: (details) => _selectNearest(details.localPosition.dx),
      onPanUpdate: (details) => _selectNearest(details.localPosition.dx),
      onPanEnd: (_) => setState(() => _selectedIndex = null),
      child: SizedBox(
        height: 104,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 32,
              child: selected == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Text(
                          '${_dateLabel(selected.date)}  ${widget.currency} ${selected.balance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: CustomPaint(
                painter: _BalanceSparklinePainter(
                  points: widget.points,
                  selectedIndex: _selectedIndex,
                  lineColor: widget.lineColor,
                  fillColor: widget.fillColor,
                  gridColor: widget.gridColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectNearest(double dx) {
    final count = widget.points.length;
    if (count == 0) return;
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 1;
    final index = ((dx / width).clamp(0.0, 1.0) * (count - 1)).round();
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _BalanceSparklinePainter extends CustomPainter {
  const _BalanceSparklinePainter({
    required this.points,
    required this.selectedIndex,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<AccountBalancePoint> points;
  final int? selectedIndex;
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

    final chartPoints = _chartPoints(size);
    if (chartPoints.isEmpty) {
      final y = size.height * 0.62;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = lineColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final line = Path()..moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (var i = 1; i < chartPoints.length; i++) {
      final previous = chartPoints[i - 1];
      final current = chartPoints[i];
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

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < chartPoints.length) {
      final point = chartPoints[selected];
      final markerPaint = Paint()..color = Colors.white;
      final markerStroke = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawLine(
        Offset(point.dx, 0),
        Offset(point.dx, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 6, markerPaint);
      canvas.drawCircle(point, 6, markerStroke);
    }
  }

  List<Offset> _chartPoints(Size size) {
    if (points.isEmpty) return [];
    final minValue = points.map((point) => point.balance).reduce((a, b) => a < b ? a : b);
    final maxValue = points.map((point) => point.balance).reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;
    final horizontalStep = points.length == 1 ? 0.0 : size.width / (points.length - 1);
    return [
      for (var i = 0; i < points.length; i++)
        Offset(
          horizontalStep * i,
          size.height - ((points[i].balance - minValue) / range * size.height * 0.76) -
              size.height * 0.12,
        ),
    ];
  }

  @override
  bool shouldRepaint(covariant _BalanceSparklinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
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
