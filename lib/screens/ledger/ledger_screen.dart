import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/transaction.dart';
import '../../services/transaction_service.dart';
import '../../widgets/category_chip.dart';
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
  String _selectedCategory = 'All Categories';

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
        category: _selectedCategory,
        searchQuery: _searchController.text.trim(),
        limit: 300,
      );
      if (mounted) {
        setState(() => _transactions = rows);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ledger')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search merchant or description',
                suffixIcon: IconButton(
                  onPressed: _loadTransactions,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _loadTransactions(),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                CategoryChip(
                  category: 'All Categories',
                  selected: _selectedCategory == 'All Categories',
                  onTap: () {
                    setState(() => _selectedCategory = 'All Categories');
                    _loadTransactions();
                  },
                ),
                const SizedBox(width: 8),
                ...AppConstants.categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      category: category,
                      selected: _selectedCategory == category,
                      onTap: () {
                        setState(() => _selectedCategory = category);
                        _loadTransactions();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: _transactions.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: 100),
                              Center(child: Text('No transactions found.')),
                            ],
                          )
                        : ListView.builder(
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: TransactionTile(
                                  transaction: tx,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => TransactionDetailScreen(transaction: tx),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
