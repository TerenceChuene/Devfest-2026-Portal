import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session_store.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({required this.sessionStore});

  final SessionStore sessionStore;

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  Map<String, String> _headers({bool auth = false, Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?extra,
    };
    if (auth && sessionStore.accessToken != null) {
      headers['Authorization'] = 'Bearer ${sessionStore.accessToken}';
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: _headers(auth: auth, extra: extraHeaders),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getJson(String path, {bool auth = false}) async {
    final response = await http.get(
      _uri(path),
      headers: _headers(auth: auth),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = await http.patch(
      _uri(path),
      headers: _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> deleteJson(String path, {bool auth = false}) async {
    final response = await http.delete(
      _uri(path),
      headers: _headers(auth: auth),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 204) {
      return <String, dynamic>{};
    }
    final dynamic decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    final message = decoded is Map && decoded['error'] != null
        ? decoded['error'].toString()
        : response.body;
    throw ApiException(response.statusCode, message);
  }
}
