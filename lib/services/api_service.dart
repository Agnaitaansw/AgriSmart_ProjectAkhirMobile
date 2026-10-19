import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';

class ApiResult {
  final bool ok;
  final bool networkError;
  final String message;
  final Map<String, dynamic>? data;
  const ApiResult(this.ok, this.message, {this.data, this.networkError = false});
}

/// Koneksi ke database online lewat REST API
///   POST /auth/register   {name, username, email, password}
///   POST /auth/login      {identifier, password} -> {user:{name,username,email}}
///   POST /auth/sync-user  {name, username, email, password_hash, salt}
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _headers = {'Content-Type': 'application/json'};

  Future<ApiResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(Uri.parse('${AppConfig.apiBaseUrl}$path'),
              headers: _headers, body: jsonEncode(body))
          .timeout(AppConfig.apiTimeout);
      final json = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return ApiResult(ok, (json['message'] as String?) ?? (ok ? 'OK' : 'Gagal'),
          data: json);
    } catch (_) {
      return const ApiResult(false, 'Tidak dapat terhubung ke server',
          networkError: true);
    }
  }

  Future<ApiResult> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) =>
      _post('/auth/register', {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      });

  Future<ApiResult> login(String identifier, String password) =>
      _post('/auth/login', {'identifier': identifier, 'password': password});

  /// Dipakai untuk mengirim akun yang dibuat saat offline (hash + salt saja).
  Future<ApiResult> syncUser({
    required String name,
    required String username,
    required String email,
    required String passwordHash,
    required String salt,
  }) =>
      _post('/auth/sync-user', {
        'name': name,
        'username': username,
        'email': email,
        'password_hash': passwordHash,
        'salt': salt,
      });
}
