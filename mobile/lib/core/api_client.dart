import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'settings_store.dart';

/// Ошибка API с понятным пользователю сообщением.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// HTTP-клиент поверх Dio: базовый адрес, JWT-токен, разбор ошибок.
class ApiClient {
  ApiClient(this._settings) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _settings.token;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) {
          final isAuthCall = error.requestOptions.path.startsWith('/auth/login') ||
              error.requestOptions.path.startsWith('/auth/register');
          if (error.response?.statusCode == 401 && !isAuthCall) {
            _unauthorized.add(null);
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Адрес API. Можно переопределить: `--dart-define=API_URL=http://192.168.1.10:3000/api`.
  /// Android-эмулятор видит компьютер по адресу 10.0.2.2, iOS-симулятор — по localhost.
  static final String baseUrl = const String.fromEnvironment('API_URL').isNotEmpty
      ? const String.fromEnvironment('API_URL')
      : (Platform.isAndroid ? 'http://10.0.2.2:3000/api' : 'http://localhost:3000/api');

  /// Адрес сервера без `/api` — для картинок из `/uploads`.
  static String get origin => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  /// Полный адрес изображения товара или null.
  static String? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$origin$path';
  }

  final SettingsStore _settings;
  late final Dio _dio;
  final _unauthorized = StreamController<void>.broadcast();

  /// Срабатывает, когда сервер ответил 401 (токен истёк или недействителен).
  Stream<void> get onUnauthorized => _unauthorized.stream;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? data}) => _send(() => _dio.post<dynamic>(path, data: data));

  Future<dynamic> put(String path, {Object? data}) => _send(() => _dio.put<dynamic>(path, data: data));

  Future<void> delete(String path) => _send(() => _dio.delete<dynamic>(path));

  Future<dynamic> uploadFile(String path, {required String field, required String filePath}) {
    return _send(() async {
      final form = FormData.fromMap({
        field: await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
      });
      return _dio.post<dynamic>(path, data: form, options: Options(contentType: 'multipart/form-data'));
    });
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return Map.of(query)..removeWhere((_, v) => v == null || (v is String && v.isEmpty));
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return ApiException(data['error'] as String, statusCode: e.response?.statusCode);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException('Нет связи с сервером ($baseUrl). Проверьте, что бэкенд запущен.');
      default:
        return ApiException(
          'Ошибка сервера${e.response?.statusCode != null ? ' (${e.response!.statusCode})' : ''}',
          statusCode: e.response?.statusCode,
        );
    }
  }
}
