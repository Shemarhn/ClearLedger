import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../../services/transaction_service.dart';
import '../../widgets/dark_shell.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_detail_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final _txService = TransactionService();
  final _searchController = TextEditingController();

  List<TransactionModel> _transactions = [];
  bool _loading = true;
  String? _error;
  TransactionType? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
      final rows = await _txService.getTransactions(
        transactionType: _selectedType,
        searchQuery: _searchController.text.trim(),
        limit: 300,
      );
      if (mounted) {
        setState(() {
          _transactions = rows;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DarkShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(
              title: 'Ledger',
              subtitle: 'Expenses, inflows, deposits, withdrawals, and transfers',
              icon: Icons.list_alt_outlined,
            ),
            const SizedBox(height: 18),
            FinanceCard(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search merchant, account, or card digits',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton.filledTonal(
                    onPressed: _loadTransactions,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
                onSubmitted: (_) => _loadTransactions(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _typeChip(null, 'All'),
                  ...TransactionType.values.map((type) => _typeChip(type, type.label)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionHeading(
              title: 'Transactions',
              trailing: '${_transactions.length}',
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            FinanceCard(child: Text('Could not load transactions: $_error')),
                          ],
                        )
                      : RefreshIndicator(
                          onRefresh: _loadTransactions,
                          child: _transactions.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 80),
                                    FinanceCard(
                                      child: Column(
                                        children: const [
                                          AppIconBadge(icon: Icons.receipt_long_outlined),
                                          SizedBox(height: 14),
                                          Text(
                                            'No transactions found.',
                                            style: TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: _transactions.length,
                                  itemBuilder: (context, index) {
                                    final tx = _transactions[index];
                                    return TransactionTile(
                                      transaction: tx,
                                      onTap: () async {
                                        final changed = await Navigator.of(context).push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                TransactionDetailScreen(transaction: tx),
                                          ),
                                        );
                                        if (changed == true && mounted) {
                                          _loadTransactions();
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(TransactionType? type, String label) {
    final selected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) {
          setState(() => _selectedType = type);
          _loadTransactions();
        },
      ),
    );
  }
}
