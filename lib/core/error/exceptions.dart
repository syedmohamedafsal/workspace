/// Data-layer exceptions thrown by remote or local data sources.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

class ServerException extends AppException {
  const ServerException(
    super.message, {
    this.statusCode,
    super.code,
    super.cause,
  });

  final int? statusCode;

  bool get isRetryable =>
      statusCode == null || statusCode == 408 || statusCode == 429 || statusCode! >= 500;
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'No internet connection available.',
  ]);
}

class CacheException extends AppException {
  const CacheException(super.message, {super.cause});
}

class ConflictException extends AppException {
  const ConflictException(
    super.message, {
    this.serverPayload,
    super.code,
  });

  final Map<String, dynamic>? serverPayload;
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}
