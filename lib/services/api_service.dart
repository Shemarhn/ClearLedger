import 'dart:io';
import 'package:dio/dio.dart';
import '../models/parsed_transaction.dart';
import '../core/constants.dart';
import '../core/supabase_client.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  Future<String?> _getToken() async {
    final session = supabase.auth.currentSession;
    return session?.accessToken;
  }

  Future<ParsedTransaction> processReceiptImage(File image) async {
    final token = await _getToken();
    if (token == null) throw ApiException("Not authenticated");

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(image.path,
          filename: image.path.split('/').last),
    });

    try {
      final response = await _dio.post(
        '/parse-receipt',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.data['success'] == true) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        data['receipt_url'] = response.data['receipt_url'];
        data['raw_llm_response'] = response.data['raw_llm_response'];
        return ParsedTransaction.fromJson(data);
      } else {
        throw ApiException("Failed to parse receipt");
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final detail = e.response?.data['detail'];
        throw ApiException(detail?.toString() ?? "Server error processing image");
      }
      throw ApiException("Network error: ${e.message}");
    }
  }

  Future<ParsedTransaction> processTextDescription(String text) async {
    final token = await _getToken();
    if (token == null) throw ApiException("Not authenticated");

    try {
      final response = await _dio.post(
        '/parse-text',
        data: {'text': text},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.data['success'] == true) {
        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        data['raw_llm_response'] = response.data['raw_llm_response'];
        return ParsedTransaction.fromJson(data);
      } else {
        throw ApiException("Failed to parse text description");
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final detail = e.response?.data['detail'];
        throw ApiException(detail?.toString() ?? "Server error processing text");
      }
      throw ApiException("Network error: ${e.message}");
    }
  }

  Future<List<int>> exportPdf({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final token = await _getToken();
    if (token == null) throw ApiException("Not authenticated");

    final response = await _dio.post<List<int>>(
      '/export/pdf',
      data: {
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
      },
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );

    return response.data ?? [];
  }

  Future<List<int>> exportCsv({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final token = await _getToken();
    if (token == null) throw ApiException("Not authenticated");

    final response = await _dio.post<List<int>>(
      '/export/csv',
      data: {
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
      },
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );

    return response.data ?? [];
  }

  String _dateOnly(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
