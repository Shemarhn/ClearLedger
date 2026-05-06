import 'package:flutter_test/flutter_test.dart';

import 'package:clearledger/core/constants.dart';

void main() {
  test('ClearLedger category defaults are available', () {
    expect(AppConstants.categories, contains('Food'));
    expect(AppConstants.categories, contains('Other'));
    expect(AppConstants.categoryColors.keys, containsAll(AppConstants.categories));
  });
}
