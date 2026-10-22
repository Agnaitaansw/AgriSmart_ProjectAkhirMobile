import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_helper.dart';

/// Riwayat poin (blockchain_logs): ditulis ke SQLite dulu, lalu dikirim ke
/// Supabase. Baris yang belum terkirim (synced = 0) dicoba lagi nanti.
/// Simpan di: lib/services/blockchain_service.dart
class BlockchainService {
  BlockchainService._();

  static const String tipePemasukan = 'pemasukan';
  static const String tipePengeluaran = 'pengeluaran';

  static final String _hashAwal = '0' * 64;
  static bool _sedangSinkron = false;

  /// Catat satu transaksi poin milik [userId].
  ///
  /// [poin] selalu positif; tanda +/- ditentukan oleh [tipe]
  /// (pemasukan = positif, pengeluaran = negatif).
  static Future<void> catat({
    required int userId,
    required int poin,
    required String deskripsi,
    required String tipe,
  }) async {
    final db = await DbHelper.instance.database;
    final jumlah = tipe == tipePemasukan ? poin : -poin;
    final waktu = _formatWaktu(DateTime.now());

    // previous_hash = current_hash blok terakhir milik user ini
    final terakhir = await db.query(
      'blockchain_logs',
      columns: ['current_hash'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: 1,
    );
    final previousHash =
        terakhir.isEmpty ? _hashAwal : terakhir.first['current_hash'] as String;

    // current_hash = SHA-256 dari isi blok + hash sebelumnya
    final currentHash = sha256
        .convert(utf8.encode('$previousHash|$deskripsi|$jumlah|$waktu'))
        .toString();

    await db.insert('blockchain_logs', {
      'user_id': userId,
      'action_type': deskripsi,
      'points_amount': jumlah,
      'timestamp': waktu,
      'previous_hash': previousHash,
      'current_hash': currentHash,
      'synced': 0,
    });

    unawaited(sinkronkan());
  }

  /// Riwayat milik [userId] dari SQLite, terbaru di atas.
  static Future<List<Map<String, dynamic>>> ambilRiwayat(int userId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'blockchain_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Kirim semua baris yang belum terkirim ke Supabase (berurutan).
  /// Aman dipanggil berkali-kali; kalau offline, baris tetap menunggu.
  static Future<void> sinkronkan() async {
    if (_sedangSinkron) return;
    _sedangSinkron = true;
    try {
      final db = await DbHelper.instance.database;
      final rows =
          await db.query('blockchain_logs', where: 'synced = 0', orderBy: 'id ASC');
      for (final r in rows) {
        await Supabase.instance.client.from('blockchain_logs').insert({
          'user_id': r['user_id'],
          'action_type': r['action_type'],
          'points_amount': r['points_amount'],
          'timestamp': r['timestamp'],
          'previous_hash': r['previous_hash'],
          'current_hash': r['current_hash'],
          'synced': 1,
        });
        await db.update('blockchain_logs', {'synced': 1},
            where: 'id = ?', whereArgs: [r['id']]);
      }
    } catch (e) {
      debugPrint('Sinkronisasi blockchain_logs tertunda: $e');
    } finally {
      _sedangSinkron = false;
    }
  }

  static String _formatWaktu(DateTime t) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(t.day)}/${dua(t.month)}/${t.year} ${dua(t.hour)}:${dua(t.minute)}';
  }
}