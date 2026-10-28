import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/constants.dart';
import '../utils/crypto_util.dart';

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kToken = 'session_token';
  static const _kUserId = 'session_user_id';
  static const _kExpiry = 'session_expiry';
  static const _kBioUser = 'biometric_user_id';
  static const _kLastIdentifier = 'last_identifier';

  Future<void> create(int userId, {required bool remember}) async {
    final expiry = DateTime.now()
        .add(remember ? AppConfig.sessionRemember : AppConfig.sessionDefault);
    await _storage.write(key: _kToken, value: CryptoUtil.generateToken());
    await _storage.write(key: _kUserId, value: userId.toString());
    await _storage.write(key: _kExpiry, value: expiry.toIso8601String());
  }

  Future<bool> isValid() async {
    final token = await _storage.read(key: _kToken);
    final expiry = await _storage.read(key: _kExpiry);
    if (token == null || expiry == null) return false;
    final exp = DateTime.tryParse(expiry);
    if (exp == null || DateTime.now().isAfter(exp)) {
      await clear();
      return false;
    }
    return true;
  }

  Future<int?> currentUserId() async {
    if (!await isValid()) return null;
    return int.tryParse(await _storage.read(key: _kUserId) ?? '');
  }

  Future<DateTime?> expiry() async {
    final e = await _storage.read(key: _kExpiry);
    return e == null ? null : DateTime.tryParse(e);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kExpiry);
  }

  // ---- Biometrik ----
  Future<void> enableBiometric(int userId) =>
      _storage.write(key: _kBioUser, value: userId.toString());

  Future<void> disableBiometric() => _storage.delete(key: _kBioUser);

  Future<int?> biometricUserId() async =>
      int.tryParse(await _storage.read(key: _kBioUser) ?? '');

  Future<void> saveLastIdentifier(String? v) async {
    if (v == null) {
      await _storage.delete(key: _kLastIdentifier);
    } else {
      await _storage.write(key: _kLastIdentifier, value: v);
    }
  }

  Future<String?> lastIdentifier() => _storage.read(key: _kLastIdentifier);
}
