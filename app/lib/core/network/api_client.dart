import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  ApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });

  @override
  String toString() => message;
}

class ApiClient {
  static String get baseUrl {
    final customUrl = StorageService.getCustomBaseUrl();
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim();
    }
    return ApiConstants.defaultBaseUrl;
  }

  static Map<String, String> _buildHeaders([Map<String, String>? extraHeaders]) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = StorageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  static dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      if (response.body.isNotEmpty) {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String errorMessage = 'Đã có lỗi xảy ra (${response.statusCode})';
    if (body is Map && body.containsKey('detail')) {
      final detail = body['detail'];
      if (detail is String) {
        errorMessage = detail;
      } else if (detail is List) {
        // FastAPI validation errors
        errorMessage = detail.map((e) => e['msg'] ?? e.toString()).join('\n');
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      data: body,
    );
  }

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ backend. Vui lòng kiểm tra địa chỉ API ($baseUrl) và mạng.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Lỗi kết nối mạng đến $baseUrl.',
      );
    }
  }

  static Future<dynamic> post(String endpoint, {dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ backend. Vui lòng kiểm tra địa chỉ API ($baseUrl).',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Lỗi kết nối mạng đến $baseUrl.',
      );
    }
  }

  static Future<dynamic> patch(String endpoint, {dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .patch(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ backend. Vui lòng kiểm tra địa chỉ API ($baseUrl).',
      );
    }
  }

  static Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .delete(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ backend. Vui lòng kiểm tra địa chỉ API ($baseUrl).',
      );
    }
  }
}
