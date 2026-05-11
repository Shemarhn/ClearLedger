import '../core/supabase_client.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import 'app_settings_service.dart';
import 'exchange_rate_service.dart';
import 'transaction_service.dart';

class AccountService {
  final _exchangeRateService = ExchangeRateService();

  Future<List<AccountModel>> getAccounts() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final accountResponse = await supabase
        .from('accounts')
        .select()
        .eq('user_id', user.id)
        .eq('archived', false)
        .order('is_default_cash', ascending: false)
        .order('created_at');

    final cardResponse = await supabase
        .from('account_card_links')
        .select('account_id, card_last4')
        .eq('user_id', user.id);

    final cardsByAccount = <String, List<String>>{};
    for (final row in (cardResponse as List)) {
      final accountId = row['account_id'] as String?;
      final last4 = row['card_last4'] as String?;
      if (accountId != null && last4 != null) {
        cardsByAccount.putIfAbsent(accountId, () => []).add(last4);
      }
    }

    final transactions = await TransactionService().getTransactions(limit: 1000);
    final accounts = (accountResponse as List)
        .map(
          (row) => AccountModel.fromJson(
            row as Map<String, dynamic>,
            linkedCardLast4: cardsByAccount[row['id']] ?? const [],
          ),
        )
        .toList();

    return _accountsWithConvertedBalances(accounts, transactions);
  }

  Future<AccountBalanceSummary> getBalanceSummary() async {
    final accounts = await getAccounts();
    final summary = _summaryFromBalancedAccounts(accounts);
    final preferredCurrency = AppSettingsService.instance.preferredCurrency;
    return _summaryInCurrency(summary, preferredCurrency);
  }

  Future<AccountModel> createAccount({
    required String name,
    required AccountType type,
    double openingBalance = 0,
    String currency = 'JMD',
    bool isDefaultCash = false,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    if (isDefaultCash) {
      await _clearOtherDefaultCashAccounts(user.id);
    }

    final response = await supabase
        .from('accounts')
        .insert({
          'user_id': user.id,
          'name': name,
          'type': type.value,
          'currency': currency,
          'opening_balance': openingBalance,
          'is_default_cash': isDefaultCash,
        })
        .select()
        .single();

    return AccountModel.fromJson(response);
  }

  Future<AccountModel> updateAccount({
    required String accountId,
    required String name,
    required AccountType type,
    required double openingBalance,
    required String currency,
    required bool isDefaultCash,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    if (isDefaultCash) {
      await _clearOtherDefaultCashAccounts(user.id, exceptAccountId: accountId);
    }

    final response = await supabase
        .from('accounts')
        .update({
          'name': name,
          'type': type.value,
          'currency': currency,
          'opening_balance': openingBalance,
          'is_default_cash': isDefaultCash,
        })
        .eq('id', accountId)
        .select()
        .single();

    return AccountModel.fromJson(response);
  }

  Future<AccountBalanceSummary> _summaryInCurrency(
    AccountBalanceSummary summary,
    String preferredCurrency,
  ) async {
    var assets = 0.0;
    var debt = 0.0;

    for (final account in summary.accounts) {
      final converted = await _convertAmount(
        account.currentBalance,
        account.currency,
        preferredCurrency,
      );
      if (account.type == AccountType.credit && converted < 0) {
        debt += converted.abs();
      } else if (converted >= 0) {
        assets += converted;
      } else {
        debt += converted.abs();
      }
    }

    return AccountBalanceSummary(
      accounts: summary.accounts,
      totalAssets: assets,
      totalDebt: debt,
      netWorth: assets - debt,
    );
  }

  Future<List<AccountModel>> _accountsWithConvertedBalances(
    List<AccountModel> accounts,
    List<TransactionModel> transactions,
  ) async {
    final balances = {
      for (final account in accounts) account.id: account.openingBalance,
    };
    final accountsById = {for (final account in accounts) account.id: account};

    for (final tx in transactions) {
      final source = tx.accountId == null ? null : accountsById[tx.accountId];
      final destination = tx.destinationAccountId == null
          ? null
          : accountsById[tx.destinationAccountId];

      switch (tx.transactionType) {
        case TransactionType.income:
        case TransactionType.refund:
          if (source != null) {
            balances[source.id] = (balances[source.id] ?? 0) +
                await _convertAmount(tx.amount, tx.currency, source.currency);
          }
          break;
        case TransactionType.transfer:
        case TransactionType.withdrawal:
        case TransactionType.deposit:
          if (source != null) {
            balances[source.id] = (balances[source.id] ?? 0) -
                await _convertAmount(tx.amount, tx.currency, source.currency);
          }
          if (destination != null) {
            balances[destination.id] = (balances[destination.id] ?? 0) +
                await _convertAmount(tx.amount, tx.currency, destination.currency);
          }
          if (tx.feeAmount != null && source != null) {
            balances[source.id] = (balances[source.id] ?? 0) -
                await _convertAmount(tx.feeAmount!, tx.currency, source.currency);
          }
          break;
        case TransactionType.expense:
          if (source != null) {
            balances[source.id] = (balances[source.id] ?? 0) -
                await _convertAmount(tx.amount, tx.currency, source.currency);
          }
          break;
      }
    }

    return accounts
        .map((account) => account.copyWith(currentBalance: balances[account.id] ?? 0))
        .toList();
  }

  AccountBalanceSummary _summaryFromBalancedAccounts(List<AccountModel> accounts) {
    var assets = 0.0;
    var debt = 0.0;
    for (final account in accounts) {
      if (account.type == AccountType.credit && account.currentBalance < 0) {
        debt += account.currentBalance.abs();
      } else if (account.currentBalance >= 0) {
        assets += account.currentBalance;
      } else {
        debt += account.currentBalance.abs();
      }
    }

    return AccountBalanceSummary(
      accounts: accounts,
      totalAssets: assets,
      totalDebt: debt,
      netWorth: assets - debt,
    );
  }

  Future<double> _convertAmount(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    final from = _normalizeCurrency(fromCurrency);
    final to = _normalizeCurrency(toCurrency);
    if (from == to || amount == 0) return amount;
    final conversion = await _exchangeRateService.convert(
      amount: amount.abs(),
      fromCurrency: from,
      toCurrency: to,
    );
    return amount < 0 ? -conversion.convertedAmount : conversion.convertedAmount;
  }

  Future<void> linkCardDigits({
    required String accountId,
    required String cardLast4,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final sanitized = cardLast4.replaceAll(RegExp(r'\D'), '');
    if (sanitized.length != 4) {
      throw Exception('Enter exactly 4 card digits.');
    }

    await supabase.from('account_card_links').upsert({
      'user_id': user.id,
      'account_id': accountId,
      'card_last4': sanitized,
    }, onConflict: 'user_id,card_last4');
  }

  Future<AccountModel?> findAccountForCard(String? cardLast4) async {
    final user = supabase.auth.currentUser;
    final sanitized = cardLast4?.replaceAll(RegExp(r'\D'), '');
    if (user == null || sanitized == null || sanitized.length != 4) return null;

    final response = await supabase
        .from('account_card_links')
        .select('account_id, accounts(*)')
        .eq('user_id', user.id)
        .eq('card_last4', sanitized)
        .maybeSingle();

    final account = response?['accounts'];
    if (account is Map<String, dynamic>) {
      return AccountModel.fromJson(account);
    }
    return null;
  }

  Future<AccountModel?> defaultCashAccount() async {
    final accounts = await getAccounts();
    for (final account in accounts) {
      if (account.isDefaultCash || account.type == AccountType.cash) {
        return account;
      }
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  Future<void> _clearOtherDefaultCashAccounts(
    String userId, {
    String? exceptAccountId,
  }) async {
    dynamic query = supabase
        .from('accounts')
        .update({'is_default_cash': false})
        .eq('user_id', userId)
        .eq('is_default_cash', true);

    if (exceptAccountId != null) {
      query = query.neq('id', exceptAccountId);
    }

    await query;
  }

  String _normalizeCurrency(String currency) {
    final normalized = currency.trim().toUpperCase();
    return RegExp(r'^[A-Z]{3}$').hasMatch(normalized) ? normalized : 'JMD';
  }
}
