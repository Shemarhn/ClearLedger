import 'transaction.dart';

enum AccountType {
  cash,
  checking,
  savings,
  credit,
  wallet,
  other,
}

extension AccountTypeLabel on AccountType {
  String get value => name;

  String get label {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.checking:
        return 'Checking';
      case AccountType.savings:
        return 'Savings';
      case AccountType.credit:
        return 'Credit';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.other:
        return 'Other';
    }
  }
}

AccountType accountTypeFromString(String? value) {
  return AccountType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => AccountType.other,
  );
}

class AccountModel {
  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final String currency;
  final double openingBalance;
  final bool isDefaultCash;
  final bool archived;
  final DateTime createdAt;
  final List<String> linkedCardLast4;
  final double currentBalance;

  AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalance,
    required this.isDefaultCash,
    required this.archived,
    required this.createdAt,
    this.linkedCardLast4 = const [],
    double? currentBalance,
  }) : currentBalance = currentBalance ?? openingBalance;

  factory AccountModel.fromJson(
    Map<String, dynamic> json, {
    List<String> linkedCardLast4 = const [],
    double? currentBalance,
  }) {
    return AccountModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? 'Account',
      type: accountTypeFromString(json['type'] as String?),
      currency: json['currency'] as String? ?? 'JMD',
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0,
      isDefaultCash: json['is_default_cash'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      linkedCardLast4: linkedCardLast4,
      currentBalance: currentBalance,
    );
  }

  AccountModel copyWith({
    List<String>? linkedCardLast4,
    double? currentBalance,
  }) {
    return AccountModel(
      id: id,
      userId: userId,
      name: name,
      type: type,
      currency: currency,
      openingBalance: openingBalance,
      isDefaultCash: isDefaultCash,
      archived: archived,
      createdAt: createdAt,
      linkedCardLast4: linkedCardLast4 ?? this.linkedCardLast4,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }
}

class AccountBalanceSummary {
  final List<AccountModel> accounts;
  final double totalAssets;
  final double totalDebt;
  final double netWorth;

  const AccountBalanceSummary({
    required this.accounts,
    required this.totalAssets,
    required this.totalDebt,
    required this.netWorth,
  });

  factory AccountBalanceSummary.fromAccounts(
    List<AccountModel> accounts,
    List<TransactionModel> transactions,
  ) {
    final balances = {
      for (final account in accounts) account.id: account.openingBalance,
    };

    for (final tx in transactions) {
      final source = tx.accountId;
      final destination = tx.destinationAccountId;
      switch (tx.transactionType) {
        case TransactionType.income:
        case TransactionType.refund:
          if (source != null) balances[source] = (balances[source] ?? 0) + tx.amount;
          break;
        case TransactionType.transfer:
        case TransactionType.withdrawal:
        case TransactionType.deposit:
          if (source != null) balances[source] = (balances[source] ?? 0) - tx.amount;
          if (destination != null) {
            balances[destination] = (balances[destination] ?? 0) + tx.amount;
          }
          if (tx.feeAmount != null && source != null) {
            balances[source] = (balances[source] ?? 0) - tx.feeAmount!;
          }
          break;
        case TransactionType.expense:
          if (source != null) balances[source] = (balances[source] ?? 0) - tx.amount;
          break;
      }
    }

    final enriched = accounts
        .map((account) => account.copyWith(currentBalance: balances[account.id] ?? 0))
        .toList();
    double assets = 0;
    double debt = 0;
    for (final account in enriched) {
      if (account.type == AccountType.credit && account.currentBalance < 0) {
        debt += account.currentBalance.abs();
      } else if (account.currentBalance >= 0) {
        assets += account.currentBalance;
      } else {
        debt += account.currentBalance.abs();
      }
    }

    return AccountBalanceSummary(
      accounts: enriched,
      totalAssets: assets,
      totalDebt: debt,
      netWorth: assets - debt,
    );
  }
}

class AccountBalancePoint {
  const AccountBalancePoint({
    required this.date,
    required this.balance,
  });

  final DateTime date;
  final double balance;
}
