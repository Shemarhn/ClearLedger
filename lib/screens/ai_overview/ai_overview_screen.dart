import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../models/daily_overview.dart';
import '../../models/transaction.dart';
import '../../services/api_service.dart';
import '../../services/app_settings_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/dark_shell.dart';

class AiOverviewScreen extends StatefulWidget {
  const AiOverviewScreen({super.key});

  @override
  State<AiOverviewScreen> createState() => _AiOverviewScreenState();
}

class _AiOverviewScreenState extends State<AiOverviewScreen> {
  static const _lastGeneratedKey = 'ai_overview_last_generated_date';

  final _apiService = ApiService();
  final _transactionService = TransactionService();
  bool _loading = true;
  bool _generating = false;
  String? _error;
  String? _lastGenerated;
  List<String> _insights = [];
  List<String> _suggestions = [];
  String _summary = 'Generate an overview to get a detailed read on today.';
  double _income = 0;
  double _spent = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final txs = await _transactionService.getTransactions(limit: 500);
      final month = DateTime.now();
      final income = await _transactionService.getTotalIncomeForMonth(month);
      final spent = await _transactionService.getTotalSpentForMonth(month);
      if (!mounted) return;
      final storedInsights = prefs.getStringList('ai_overview_insights');
      final storedSuggestions = prefs.getStringList('ai_overview_suggestions');
      setState(() {
        _lastGenerated = prefs.getString(_lastGeneratedKey);
        _income = income;
        _spent = spent;
        _insights = storedInsights ?? _buildInsights(txs, income, spent);
        _suggestions = storedSuggestions ?? _buildSuggestions(txs, income, spent);
        _summary = prefs.getString('ai_overview_summary') ?? _summary;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final overview = await _apiService.generateDailyOverview();
      await _storeOverview(overview);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI overview unavailable: $error')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  bool get _canGenerateToday => _lastGenerated != _todayKey();

  @override
  Widget build(BuildContext context) {
    final currency = AppSettingsService.instance.preferredCurrency;
    return Scaffold(
      body: DarkShell(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const ScreenHeader(
                        title: 'AI Overview',
                        subtitle: 'A once-daily read on your money habits',
                        glyph: AppGlyph.insight,
                      ),
                      const SizedBox(height: 18),
                      FinanceCard(
                        child: Column(
                          children: [
                            Text('Could not load overview: $_error'),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    ],
                  )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  children: [
                    const ScreenHeader(
                      title: 'AI Overview',
                      subtitle: 'A once-daily read on your money habits',
                      glyph: AppGlyph.insight,
                    ),
                    const SizedBox(height: 18),
                    FinanceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppIconBadge(glyph: AppGlyph.insight, size: 42),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _canGenerateToday
                                      ? 'Ready for today'
                                      : 'Generated today',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _summary,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _canGenerateToday && !_generating ? _generate : null,
                            icon: const Icon(Icons.bolt_outlined),
                            label: Text(_generating ? 'Generating...' : 'Generate overview'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Inflows',
                            value: '+$currency ${_income.toStringAsFixed(0)}',
                            color: AppConstants.successGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Outflows',
                            value: '-$currency ${_spent.toStringAsFixed(0)}',
                            color: AppConstants.errorRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _InsightCard(title: 'Insights', items: _insights, glyph: AppGlyph.insight),
                    const SizedBox(height: 12),
                    _InsightCard(
                      title: 'Suggestions',
                      items: _suggestions,
                      glyph: AppGlyph.document,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  List<String> _buildInsights(List<TransactionModel> txs, double income, double spent) {
    final transfers = txs.where((tx) => tx.transactionType.isTransfer).length;
    final recentExpenses = txs.where((tx) => tx.transactionType == TransactionType.expense).take(30);
    final categoryTotals = <String, double>{};
    for (final tx in recentExpenses) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
    }
    final top = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      if (income > 0) 'You have kept ${(spent / income * 100).clamp(0, 999).toStringAsFixed(0)}% of recorded inflows this month.',
      if (top.isNotEmpty) '${top.first.key} is your largest recent spending category.',
      if (transfers > 0) '$transfers recent money moves were transfers, withdrawals, or deposits.',
      if (txs.any((tx) => tx.cardLast4 != null)) 'Linked card digits are helping route receipts to the right account.',
      if (txs.isEmpty) 'Add a few transactions to unlock stronger insights.',
    ];
  }

  List<String> _buildSuggestions(List<TransactionModel> txs, double income, double spent) {
    return [
      if (income > 0 && spent > income * 0.75)
        'Set a soft limit for flexible spending before the month gets tight.',
      if (txs.any((tx) => tx.transactionType == TransactionType.withdrawal))
        'Review cash withdrawals weekly so cash spending does not disappear from the ledger.',
      'Link card last-4 digits for each bank account you use most often.',
      'Use transfers for deposits and withdrawals so account balances stay clean.',
    ];
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _storeOverview(DailyOverview overview) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastGeneratedKey, overview.generatedFor);
    await prefs.setString('ai_overview_summary', overview.summary);
    await prefs.setStringList('ai_overview_insights', overview.insights);
    await prefs.setStringList('ai_overview_suggestions', overview.suggestions);
    if (!mounted) return;
    setState(() {
      _summary = overview.summary;
      _insights = overview.insights;
      _suggestions = overview.suggestions;
      _lastGenerated = overview.generatedFor;
    });
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: muted)),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.items,
    required this.glyph,
  });

  final String title;
  final List<String> items;
  final AppGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(glyph: glyph, size: 40),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7, right: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: muted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
