import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_model.dart';
import '../utils/crypto_util.dart';
import 'api_service.dart';
import 'db_helper.dart';
import 'session_manager.dart';

class AuthResult {
  final bool ok;
  final String message;
  final UserModel? user;
  const AuthResult(this.ok, this.message, [this.user]);
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _db = DbHelper.instance;
  final _session = SessionManager.instance;
  final _api = ApiService.instance;
  final _bio = LocalAuthentication();

  // ---------------------------------------------------------------- REGISTER
  Future<AuthResult> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    if (await _db.findByIdentifier(username) != null) {
      return const AuthResult(false, 'Username sudah digunakan');
    }
    if (await _db.findByIdentifier(email) != null) {
      return const AuthResult(false, 'Email sudah terdaftar');
    }

    final salt = CryptoUtil.generateSalt();
    final user = UserModel(
      name: name.trim(),
      username: username.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: CryptoUtil.hashPassword(password, salt),
      salt: salt,
      createdAt: DateTime.now().toIso8601String(),
    );

    late int id;
    try {
      id = await _db.insertUser(user);
    } on DatabaseException {
      return const AuthResult(false, 'Gagal menyimpan akun');
    }

    // Kirim ke database online (kalau ada koneksi).
    final res = await _api.register(
      name: user.name,
      username: user.username,
      email: user.email,
      password: password,
    );
    if (res.ok) {
      await _db.markSynced(id);
    }
    return AuthResult(
      true,
      res.ok
          ? 'Registrasi berhasil'
          : 'Registrasi berhasil (disimpan di perangkat, akan disinkronkan saat online)',
    );
  }

  /// Kirim akun yang masih offline ke server. Panggil saat app dibuka / online.
  Future<void> syncPending() async {
    for (final u in await _db.getUnsynced()) {
      final res = await _api.syncUser(
        name: u.name,
        username: u.username,
        email: u.email,
        passwordHash: u.passwordHash,
        salt: u.salt,
      );
      if (res.ok && u.id != null) await _db.markSynced(u.id!);
    }
  }

  // ------------------------------------------------------------------- LOGIN
  Future<AuthResult> login({
    required String identifier,
    required String password,
    required bool remember,
  }) async {
    final id = identifier.trim();
    var user = await _db.findByIdentifier(id);

    if (user != null) {
      // Login lokal (offline-first).
      if (!CryptoUtil.verify(password, user.salt, user.passwordHash)) {
        return const AuthResult(false, 'Username/email atau password salah');
      }
    } else {
      // Akun belum ada di perangkat -> coba database online.
      final res = await _api.login(id, password);
      if (res.networkError) {
        return const AuthResult(
            false, 'Akun tidak ditemukan di perangkat dan tidak ada koneksi internet');
      }
      if (!res.ok) {
        return const AuthResult(false, 'Username/email atau password salah');
      }
      final u = (res.data?['user'] ?? {}) as Map<String, dynamic>;
      final salt = CryptoUtil.generateSalt();
      final newUser = UserModel(
        name: (u['name'] ?? id) as String,
        username: (u['username'] ?? id) as String,
        email: ((u['email'] ?? '$id@local') as String).toLowerCase(),
        passwordHash: CryptoUtil.hashPassword(password, salt),
        salt: salt,
        createdAt: DateTime.now().toIso8601String(),
        synced: true,
      );
      try {
        await _db.insertUser(newUser);
      } on DatabaseException {
        // abaikan, kemungkinan sudah ada
      }
      user = await _db.findByIdentifier(newUser.username);
      if (user == null) return const AuthResult(false, 'Gagal menyimpan data lokal');
    }

    await _session.create(user.id!, remember: remember);
    await _session.saveLastIdentifier(remember ? user.username : null);
    return AuthResult(true, 'Login berhasil', user);
  }

  // --------------------------------------------------------------- BIOMETRIK
  Future<bool> isBiometricAvailable() async {
    try {
      return await _bio.isDeviceSupported() &&
          (await _bio.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async =>
      await _session.biometricUserId() != null;

  Future<bool> _authenticate(String reason) async {
    try {
      return await _bio.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Aktifkan login biometrik untuk user yang sedang login.
  Future<bool> enableBiometric(int userId) async {
    if (!await isBiometricAvailable()) return false;
    if (!await _authenticate('Verifikasi untuk mengaktifkan login biometrik')) {
      return false;
    }
    await _session.enableBiometric(userId);
    return true;
  }

  Future<void> disableBiometric() => _session.disableBiometric();

  Future<AuthResult> loginWithBiometric({bool remember = true}) async {
    final uid = await _session.biometricUserId();
    if (uid == null) {
      return const AuthResult(false,
          'Biometrik belum diaktifkan. Login dengan password dulu, lalu aktifkan.');
    }
    if (!await isBiometricAvailable()) {
      return const AuthResult(false, 'Biometrik tidak tersedia di perangkat ini');
    }
    if (!await _authenticate('Gunakan sidik jari / wajah untuk masuk ke AgriSmart')) {
      return const AuthResult(false, 'Autentikasi biometrik dibatalkan / gagal');
    }
    final user = await _db.findById(uid);
    if (user == null) {
      await _session.disableBiometric();
      return const AuthResult(false, 'Akun tidak ditemukan');
    }
    await _session.create(user.id!, remember: remember);
    return AuthResult(true, 'Login berhasil', user);
  }

  // ----------------------------------------------------------------- SESSION
  Future<bool> hasValidSession() => _session.isValid();

  Future<UserModel?> currentUser() async {
    final id = await _session.currentUserId();
    return id == null ? null : _db.findById(id);
  }

  Future<DateTime?> sessionExpiry() => _session.expiry();

  Future<String?> lastIdentifier() => _session.lastIdentifier();

  Future<void> logout() => _session.clear();
}
