import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';

/// Callback that returns the current bearer token once Auth is wired in.
typedef AuthTokenProvider = Future<String?> Function();

/// Centralized HTTP client built on [Dio] with consistent exception mapping
/// and idempotency header support for reliable offline-sync retries.
class ApiClient {
  ApiClient({
    required AppConfig config,
    Dio? dio,
    AuthTokenProvider? tokenProvider,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.apiBaseUrl,
                connectTimeout: config.connectTimeout,
                receiveTimeout: config.receiveTimeout,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    if (tokenProvider != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await tokenProvider();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );
    }
  }

  final Dio _dio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _normalizeResponse(response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        options: _buildOptions(idempotencyKey),
      );
      return _normalizeResponse(response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        path,
        data: body,
        options: _buildOptions(idempotencyKey),
      );
      return _normalizeResponse(response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(
        path,
        options: _buildOptions(idempotencyKey),
      );
      return _normalizeResponse(response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Options? _buildOptions(String? idempotencyKey) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) {
      return null;
    }
    return Options(headers: {'X-Idempotency-Key': idempotencyKey});
  }

  Map<String, dynamic> _normalizeResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is List) {
      return {'items': data};
    }
    return const {};
  }

  AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException('Unable to reach REBS server.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        final message = _extractErrorMessage(data) ??
            e.message ??
            'Server returned an error.';

        if (statusCode == 409) {
          return ConflictException(
            message,
            serverPayload: data is Map<String, dynamic> ? data : null,
          );
        }
        if (statusCode == 400 || statusCode == 422) {
          return ValidationException(message);
        }
        return ServerException(message, statusCode: statusCode, cause: e);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return NetworkException(
          e.message ?? 'Network communication failed.',
        );
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final msg = data['message'] ?? data['error'];
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    return null;
  }
}
