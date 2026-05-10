import '../core/supabase_client.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';

class AccountService {
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

    return AccountBalanceSummary.fromAccounts(accounts, transactions).accounts;
  }

  Future<AccountBalanceSummary> getBalanceSummary() async {
    final accounts = await getAccounts();
    final transactions = await TransactionService().getTransactions(limit: 1000);
    return AccountBalanceSummary.fromAccounts(accounts, transactions);
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
}
