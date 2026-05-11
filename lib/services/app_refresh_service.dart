import 'package:flutter/foundation.dart';

class AppRefreshService extends ChangeNotifier {
  AppRefreshService._();

  static final AppRefreshService instance = AppRefreshService._();

  int _transactionsVersion = 0;
  int _accountsVersion = 0;
  int _budgetsVersion = 0;
  int _settingsVersion = 0;

  int get transactionsVersion => _transactionsVersion;
  int get accountsVersion => _accountsVersion;
  int get budgetsVersion => _budgetsVersion;
  int get settingsVersion => _settingsVersion;

  void transactionsChanged() {
    _transactionsVersion++;
    notifyListeners();
  }

  void accountsChanged() {
    _accountsVersion++;
    notifyListeners();
  }

  void budgetsChanged() {
    _budgetsVersion++;
    notifyListeners();
  }

  void settingsChanged() {
    _settingsVersion++;
    notifyListeners();
  }
}
