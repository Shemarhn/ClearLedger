import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyConversion {
  const CurrencyConversion({
    required this.originalAmount,
    required this.convertedAmount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.exchangeRate,
    this.lastUpdatedUtc,
    this.nextUpdatedUtc,
  });

  final double originalAmount;
  final double convertedAmount;
  final String fromCurrency;
  final String toCurrency;
  final double exchangeRate;
  final String? lastUpdatedUtc;
  final String? nextUpdatedUtc;

  bool get converted => fromCurrency != toCurrency;
}

class ExchangeRateSnapshot {
  const ExchangeRateSnapshot({
    required this.baseCurrency,
    required this.lastUpdatedUtc,
    required this.nextUpdatedUtc,
  });

  final String baseCurrency;
  final String? lastUpdatedUtc;
  final String? nextUpdatedUtc;
}

class ExchangeRateService {
  ExchangeRateService({Dio? dio}) : _dio = dio ?? Dio();

  static const attributionName = 'ExchangeRate-API';
  static const attributionUrl = 'https://www.exchangerate-api.com';
  static const docsUrl = 'https://www.exchangerate-api.com/docs/free';
  static const _baseUrl = 'https://open.er-api.com/v6/latest';

  final Dio _dio;

  Future<CurrencyConversion> convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final from = _normalizeCurrency(fromCurrency);
    final to = _normalizeCurrency(toCurrency);
    if (from == to) {
      return CurrencyConversion(
        originalAmount: amount,
        convertedAmount: amount,
        fromCurrency: from,
        toCurrency: to,
        exchangeRate: 1,
      );
    }

    final payload = await _ratesFor(from);
    final rates = payload['rates'];
    if (rates is! Map || rates[to] is! num) {
      throw Exception('No exchange rate found for $from to $to.');
    }

    final rate = (rates[to] as num).toDouble();
    return CurrencyConversion(
      originalAmount: amount,
      convertedAmount: amount * rate,
      fromCurrency: from,
      toCurrency: to,
      exchangeRate: rate,
      lastUpdatedUtc: payload['time_last_update_utc'] as String?,
      nextUpdatedUtc: payload['time_next_update_utc'] as String?,
    );
  }

  Future<ExchangeRateSnapshot?> latestSnapshot(String baseCurrency) async {
    try {
      final payload = await _ratesFor(_normalizeCurrency(baseCurrency));
      return ExchangeRateSnapshot(
        baseCurrency: payload['base_code'] as String? ?? baseCurrency,
        lastUpdatedUtc: payload['time_last_update_utc'] as String?,
        nextUpdatedUtc: payload['time_next_update_utc'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _ratesFor(String baseCurrency) async {
    final prefs = await SharedPreferences.getInstance();
    final cachePrefix = 'exchange_rates_$baseCurrency';
    final bodyKey = '${cachePrefix}_body';
    final dateKey = '${cachePrefix}_date';
    final today = _dateKey(DateTime.now().toUtc());

    final cachedBody = prefs.getString(bodyKey);
    if (prefs.getString(dateKey) == today && cachedBody != null) {
      return jsonDecode(cachedBody) as Map<String, dynamic>;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/$baseCurrency',
        options: Options(
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
        ),
      );
      final data = response.data;
      if (data == null || data['result'] != 'success') {
        throw Exception(data?['error-type'] ?? 'Exchange rate request failed.');
      }
      await prefs.setString(bodyKey, jsonEncode(data));
      await prefs.setString(dateKey, today);
      return data;
    } catch (_) {
      if (cachedBody != null) {
        return jsonDecode(cachedBody) as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  String _normalizeCurrency(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.length != 3) {
      throw Exception('Currency must be a 3-letter ISO code.');
    }
    return normalized;
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
