import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/crypto_util.dart';
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
  final _bio = LocalAuthentication();

  SupabaseClient get _supabase => Supabase.instance.client;

  static const _salah = AuthResult(false, 'Username/email atau password salah');

  Future<AuthResult> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final uname = username.trim();
    final mail = email.trim().toLowerCase();

    // 1. Cek di perangkat
    if (await _db.findByIdentifier(uname) != null) {
      return const AuthResult(false, 'Username sudah digunakan');
    }
    if (await _db.findByIdentifier(mail) != null) {
      return const AuthResult(false, 'Email sudah terdaftar');
    }

    final salt = CryptoUtil.generateSalt();
    final hash = CryptoUtil.hashPassword(password, salt);
    final createdAt = DateTime.now().toIso8601String();

    var serverId = -1;
    try {
      // 2. Cek di Supabase (akun bisa saja dibuat dari perangkat lain)
      if (await _adaDiServer('username', uname)) {
        return const AuthResult(false, 'Username sudah digunakan');
      }
      if (await _adaDiServer('email', mail)) {
        return const AuthResult(false, 'Email sudah terdaftar');
      }

      // 3. Buat di Supabase; id dibuat oleh Supabase
      final row = await _supabase
          .from('users')
          .insert({
            'name': name.trim(),
            'username': uname,
            'email': mail,
            'password_hash': hash,
            'salt': salt,
            'created_at': createdAt,
            'synced': 1,
          })
          .select('id')
          .single()
          .timeout(AppConfig.apiTimeout);
      serverId = (row['id'] as num).toInt();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return const AuthResult(false, 'Username atau email sudah terdaftar');
      }
      return AuthResult(false, 'Server menolak pendaftaran: ${e.message}');
    } catch (e) {
      if (_jaringan(e)) {
        return const AuthResult(
            false, 'Registrasi membutuhkan koneksi internet. Coba lagi saat online.');
      }
      return AuthResult(false, 'Registrasi gagal: $e');
    }

    // 4. Simpan salinan lokal dengan id yang sama
    try {
      await _db.upsertUserFromCloud(
        id: serverId,
        name: name.trim(),
        username: uname,
        email: mail,
        passwordHash: hash,
        salt: salt,
        createdAt: createdAt,
      );
    } on DatabaseException {
      return const AuthResult(
          false, 'Akun sudah dibuat, tapi gagal disimpan di perangkat. Coba login.');
    }

    return const AuthResult(true, 'Registrasi berhasil');
  }

  Future<void> syncPending() async {}

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
        return _salah;
      }
    } else {
      // Akun belum ada di perangkat -> ambil dari Supabase.
      final hasil = await _loginDariServer(id, password);
      if (!hasil.ok) return hasil;
      user = hasil.user;
      if (user == null) return const AuthResult(false, 'Gagal menyimpan data lokal');
    }

    await _session.create(user.id!, remember: remember);
    await _session.saveLastIdentifier(remember ? user.username : null);
    return AuthResult(true, 'Login berhasil', user);
  }

  Future<AuthResult> _loginDariServer(String id, String password) async {
    try {
      final pola = _escapeLike(id);

      var rows = await _supabase
          .from('users')
          .select()
          .ilike('username', pola)
          .limit(1)
          .timeout(AppConfig.apiTimeout);
      if (rows.isEmpty) {
        rows = await _supabase
            .from('users')
            .select()
            .ilike('email', pola)
            .limit(1)
            .timeout(AppConfig.apiTimeout);
      }
      if (rows.isEmpty) return _salah;

      final u = rows.first;
      final salt = u['salt'] as String;
      final hash = u['password_hash'] as String;
      if (!CryptoUtil.verify(password, salt, hash)) return _salah;

      // Simpan di perangkat dengan id yang SAMA dengan di Supabase
      final serverId = (u['id'] as num).toInt();
      await _db.upsertUserFromCloud(
        id: serverId,
        name: (u['name'] as String?) ?? id,
        username: (u['username'] as String?) ?? id,
        email: (u['email'] as String?) ?? '$id@local',
        passwordHash: hash,
        salt: salt,
        createdAt: (u['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      );

      final lokal = await _db.findById(serverId);
      if (lokal == null) return const AuthResult(false, 'Gagal menyimpan data lokal');
      return AuthResult(true, 'OK', lokal);
    } on PostgrestException catch (e) {
      return AuthResult(false, 'Server menolak permintaan: ${e.message}');
    } on DatabaseException {
      return const AuthResult(false, 'Gagal menyimpan data lokal');
    } catch (e) {
      if (_jaringan(e)) {
        return const AuthResult(false,
            'Akun tidak ditemukan di perangkat dan tidak ada koneksi internet');
      }
      return AuthResult(false, 'Login gagal: $e');
    }
  }

  Future<bool> _adaDiServer(String kolom, String nilai) async {
    final rows = await _supabase
        .from('users')
        .select('id')
        .ilike(kolom, _escapeLike(nilai))
        .limit(1)
        .timeout(AppConfig.apiTimeout);
    return rows.isNotEmpty;
  }

  String _escapeLike(String s) => s
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  
  bool _jaringan(Object e) =>
      e is IOException || e is TimeoutException || e is http.ClientException;

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

  // SESSION
  Future<bool> hasValidSession() => _session.isValid();

  Future<UserModel?> currentUser() async {
    final id = await _session.currentUserId();
    return id == null ? null : _db.findById(id);
  }

  Future<DateTime?> sessionExpiry() => _session.expiry();

  Future<String?> lastIdentifier() => _session.lastIdentifier();

  Future<void> logout() => _session.clear();
}