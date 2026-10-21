import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'db_helper.dart'; 

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  // Mengambil instance client Supabase
  final _supabase = Supabase.instance.client;

  /// Fungsi untuk mendorong data lokal yang belum tersinkron ke Supabase (PostgreSQL)
  Future<void> syncUsersToCloud() async {
    try {
      // 1. Ambil data dari SQLite lokal yang synced = 0
      final List<UserModel> unsyncedUsers = await DbHelper.instance.getUnsynced();

      if (unsyncedUsers.isEmpty) {
        print('Semua data pengguna sudah tersinkronisasi.');
        return;
      }

      // 2. Looping data dan kirim ke Supabase
      for (var user in unsyncedUsers) {
        // Insert ke tabel 'users' di PostgreSQL Supabase
        await _supabase.from('users').insert({
          // Pastikan nama key ini sesuai dengan kolom di tabel PostgreSQL Supabase-mu
          'name': user.name,
          'username': user.username,
          'email': user.email,
          'password_hash': user.passwordHash,
          'salt': user.salt,
          'created_at': user.createdAt,
        });

        // 3. Jika berhasil insert ke online, tandai synced = 1 di SQLite lokal
        await DbHelper.instance.markSynced(user.id!);
        print('User ${user.email} berhasil disinkronisasi ke cloud.');
      }
    } catch (e) {
      print('Gagal melakukan sinkronisasi: $e');
      // Data tetap aman di SQLite (synced = 0) dan akan dicoba lagi nanti
    }
  }
}