
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_helper.dart';

/// Riwayat poin disimpan di SQLite dan disinkronkan dengan Supabase.
class BlockchainService {
  BlockchainService._();

  static const String tipePemasukan = 'pemasukan';
  static const String tipePengeluaran = 'pengeluaran';

  static final String _hashAwal = '0' * 64;
  static bool _sedangSinkron = false;

  /// Mencatat satu transaksi poin milik pengguna.
  static Future<void> catat({
    required int userId,
    required int poin,
    required String deskripsi,
    required String tipe,
  }) async {
    final db = await DbHelper.instance.database;
    final jumlah = tipe == tipePemasukan ? poin : -poin;
    final waktu = _formatWaktu(DateTime.now());

    final terakhir = await db.query(
      'blockchain_logs',
      columns: ['current_hash'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: 1,
    );

    final previousHash = terakhir.isEmpty
        ? _hashAwal
        : terakhir.first['current_hash'] as String;

    final currentHash = sha256
        .convert(
          utf8.encode('$previousHash|$deskripsi|$jumlah|$waktu'),
        )
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

    // Tetap simpan transaksi lokal meskipun server sedang offline.
    unawaited(sinkronkan(userId: userId));
  }

  /// Membaca riwayat lokal milik pengguna yang sedang login.
  static Future<List<Map<String, dynamic>>> ambilRiwayat(
    int userId,
  ) async {
    final db = await DbHelper.instance.database;

    final rows = await db.query(
      'blockchain_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );

    return List<Map<String, dynamic>>.from(rows);
  }

  /// Sinkronisasi dua arah:
  /// 1. Mengirim transaksi lokal yang belum tersinkron.
  /// 2. Mengambil transaksi lama milik pengguna dari Supabase.
  static Future<void> sinkronkan({int? userId}) async {
    if (_sedangSinkron) return;

    _sedangSinkron = true;

    try {
      final db = await DbHelper.instance.database;
      final supabase = Supabase.instance.client;

      // LANGKAH 1: Kirim transaksi lokal yang belum tersinkron.
      final lokalBelumTerkirim = await db.query(
        'blockchain_logs',
        where: userId == null
            ? 'synced = 0'
            : 'synced = 0 AND user_id = ?',
        whereArgs: userId == null ? null : [userId],
        orderBy: 'id ASC',
      );

      for (final row in lokalBelumTerkirim) {
        try {
          final hash = row['current_hash'];

          // Hindari mengirim ulang jika hash sudah ada di server.
          if (hash != null) {
            final sudahAda = await supabase
                .from('blockchain_logs')
                .select('id')
                .eq('current_hash', hash)
                .limit(1);

            if (sudahAda.isNotEmpty) {
              await db.update(
                'blockchain_logs',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [row['id']],
              );
              continue;
            }
          }

          await supabase.from('blockchain_logs').insert({
            'user_id': row['user_id'],
            'action_type': row['action_type'],
            'points_amount': row['points_amount'],
            'timestamp': row['timestamp'],
            'previous_hash': row['previous_hash'],
            'current_hash': row['current_hash'],
            'synced': 1,
          });

          await db.update(
            'blockchain_logs',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        } catch (e) {
          debugPrint(
            'Gagal mengirim transaksi ${row['id']}: $e',
          );
          // Transaksi tetap synced = 0 untuk dicoba lagi nanti.
        }
      }

      // LANGKAH 2: Ambil transaksi lama milik pengguna dari Supabase.
      if (userId != null) {
        final dataServer = await supabase
            .from('blockchain_logs')
            .select(
              'user_id, action_type, points_amount, timestamp, '
              'previous_hash, current_hash',
            )
            .eq('user_id', userId);

        final transaksi = List<Map<String, dynamic>>.from(dataServer);

        // Urutkan dari paling lama supaya ID lokal mengikuti urutan waktu.
        transaksi.sort((a, b) {
          return _parseWaktu(a['timestamp']?.toString())
              .compareTo(_parseWaktu(b['timestamp']?.toString()));
        });

        for (final row in transaksi) {
          final hash = row['current_hash'];

          if (hash == null) continue;

          // Cek hash agar transaksi lama tidak diduplikasi.
          final sudahAda = await db.query(
            'blockchain_logs',
            columns: ['id'],
            where: 'current_hash = ? AND user_id = ?',
            whereArgs: [hash, userId],
            limit: 1,
          );

          if (sudahAda.isNotEmpty) {
            continue;
          }

          await db.insert('blockchain_logs', {
            'user_id': userId,
            'action_type': row['action_type'],
            'points_amount': row['points_amount'],
            'timestamp': row['timestamp'],
            'previous_hash': row['previous_hash'],
            'current_hash': hash,
            'synced': 1,
          });
        }
      }
    } catch (e) {
      // Jika offline atau server gagal, riwayat lokal tetap dapat dibaca.
      debugPrint('Sinkronisasi blockchain tertunda: $e');
    } finally {
      _sedangSinkron = false;
    }
  }

  static DateTime _parseWaktu(String? waktu) {
    if (waktu == null || waktu.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    // Format yang digunakan aplikasi: dd/MM/yyyy HH:mm
    try {
      final bagian = waktu.split(' ');
      final tanggal = bagian[0].split('/');
      final jam = bagian.length > 1 ? bagian[1].split(':') : ['0', '0'];

      return DateTime(
        int.parse(tanggal[2]),
        int.parse(tanggal[1]),
        int.parse(tanggal[0]),
        int.parse(jam[0]),
        int.parse(jam[1]),
      );
    } catch (_) {
      return DateTime.tryParse(waktu) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static String _formatWaktu(DateTime t) {
    String dua(int n) => n.toString().padLeft(2, '0');

    return '${dua(t.day)}/${dua(t.month)}/${t.year} '
        '${dua(t.hour)}:${dua(t.minute)}';
  }
}
