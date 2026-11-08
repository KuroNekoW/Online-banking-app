import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../storage/storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  ApiException({required this.statusCode, required this.message, this.data});

  @override
  String toString() => message;
}

class ApiClient {
  static Future<bool>? _refreshInFlight;

  static String get baseUrl {
    final customUrl = StorageService.getCustomBaseUrl();
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    return ApiConstants.defaultBaseUrl;
  }

  static Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool includeAuthorization = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuthorization) {
      final token = await StorageService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    if (extraHeaders != null) headers.addAll(extraHeaders);
    return headers;
  }

  static dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      if (response.bodyBytes.isNotEmpty) {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    var errorMessage = 'Đã xảy ra lỗi (${response.statusCode}).';
    if (body is Map && body.containsKey('detail')) {
      final detail = body['detail'];
      if (detail is String) {
        errorMessage = detail;
      } else if (detail is List) {
        errorMessage = detail.map((item) {
          if (item is Map) return item['msg']?.toString() ?? item.toString();
          return item.toString();
        }).join('\n');
      }
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      data: body,
    );
  }

  static Uri _uri(String endpoint, [Map<String, String>? queryParams]) {
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  static Future<http.Response> _send(
    String method,
    Uri uri, {
    dynamic body,
    bool includeAuthorization = true,
  }) async {
    final headers = await _buildHeaders(includeAuthorization: includeAuthorization);
    final encodedBody = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      case 'POST':
        return http.post(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 15));
      case 'PATCH':
        return http.patch(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 15));
      case 'DELETE':
        return http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }
  }

  static bool _isAuthEndpoint(String endpoint) {
    return endpoint == ApiConstants.login ||
        endpoint == ApiConstants.register ||
        endpoint == ApiConstants.registerVerify ||
        endpoint.startsWith('/auth/otp/') ||
        endpoint == ApiConstants.passwordReset ||
        endpoint == ApiConstants.passwordResetConfirm ||
        endpoint == ApiConstants.refresh;
  }

  static Future<bool> _refreshAccessToken() async {
    final current = _refreshInFlight;
    if (current != null) return current;

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  static Future<bool> _performRefresh() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await http
          .post(
            _uri(ApiConstants.refresh),
            headers: await _buildHeaders(includeAuthorization: false),
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 || response.statusCode == 403) {
          await StorageService.clearTokens();
        }
        return false;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      await StorageService.setAccessToken(data['access_token'] as String);
      await StorageService.setRefreshToken(data['refresh_token'] as String);
      return true;
    } on Exception {
      // Keep local tokens on temporary network failures so the user can retry later.
      return false;
    }
  }

  static Future<dynamic> _request(
    String method,
    String endpoint, {
    dynamic body,
    Map<String, String>? queryParams,
  }) async {
    final uri = _uri(endpoint, queryParams);
    try {
      var response = await _send(method, uri, body: body);
      if (response.statusCode == 401 && !_isAuthEndpoint(endpoint)) {
        final token = await StorageService.getAccessToken();
        if (token != null && await _refreshAccessToken()) {
          response = await _send(method, uri, body: body);
        }
      }
      return _processResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(statusCode: 0, message: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối tới backend tại $baseUrl. Hãy kiểm tra địa chỉ API và mạng.',
      );
    } on Exception catch (error) {
      throw ApiException(statusCode: 0, message: 'Lỗi kết nối tới backend: $error');
    }
  }

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) =>
      _request('GET', endpoint, queryParams: queryParams);

  static Future<dynamic> post(String endpoint, {dynamic body}) =>
      _request('POST', endpoint, body: body);

  static Future<dynamic> patch(String endpoint, {dynamic body}) =>
      _request('PATCH', endpoint, body: body);

  static Future<dynamic> delete(String endpoint) => _request('DELETE', endpoint);
}
