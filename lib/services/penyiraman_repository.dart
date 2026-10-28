import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_helper.dart';
import 'blockchain_service.dart';

class StatusPenyiraman {
  final int koin;
  final int totalPenyiraman;
  final DateTime? terakhirDisiram;
  final Set<int> tekoDimiliki; 
  final int tekoAktif; 

  const StatusPenyiraman({
    required this.koin,
    required this.totalPenyiraman,
    required this.terakhirDisiram,
    required this.tekoDimiliki,
    required this.tekoAktif,
  });

  bool get sudahDisiramHariIni {
    final t = terakhirDisiram;
    if (t == null) return false;
    final n = DateTime.now();
    return t.year == n.year && t.month == n.month && t.day == n.day;
  }
}

class PenyiramanRepository {
  static const int koinAwal = 10;
  static const int hadiahMenyiram = 2;

  static bool _sedangSinkron = false;

  Future<Database> get _db => DbHelper.instance.database;
  SupabaseClient get _supabase => Supabase.instance.client;


  Future<StatusPenyiraman> muat(int userId) async {
    final db = await _db;
    await _tarikDariServerJikaKosong(db, userId);
    await _pastikanReward(db, userId);

    final reward = (await db.query('user_rewards',
            where: 'user_id = ?', whereArgs: [userId], limit: 1))
        .first;
    final cans = await db
        .query('user_watering_cans', where: 'user_id = ?', whereArgs: [userId]);

    final dimiliki = <int>{for (final c in cans) c['can_id'] as int};
    final aktif = cans.where((c) => c['is_active'] == 1).toList();

    unawaited(sinkronkan(userId));
    unawaited(BlockchainService.sinkronkan());

    return StatusPenyiraman(
      koin: reward['total_coins'] as int,
      totalPenyiraman: reward['total_waterings'] as int,
      terakhirDisiram:
          DateTime.tryParse((reward['last_watered_at'] as String?) ?? ''),
      tekoDimiliki: dimiliki,
      tekoAktif: aktif.isEmpty ? 0 : aktif.first['can_id'] as int,
    );
  }

  Future<int> catatPenyiraman(int userId) async {
    final db = await _db;
    final sekarang = DateTime.now().toIso8601String();
    var koinBaru = 0;

    await db.transaction((txn) async {
      await _pastikanReward(txn, userId);
      await txn.rawUpdate(
        'UPDATE user_rewards SET total_coins = total_coins + ?, '
        'total_waterings = total_waterings + 1, last_watered_at = ?, '
        'synced = 0 WHERE user_id = ?',
        [hadiahMenyiram, sekarang, userId],
      );

      final r = await txn.query('user_rewards',
          columns: ['total_coins'],
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 1);
      koinBaru = r.first['total_coins'] as int;
    });

    await BlockchainService.catat(
      userId: userId,
      poin: hadiahMenyiram,
      deskripsi: 'Menyiram tanaman mini game',
      tipe: BlockchainService.tipePemasukan,
    );
    unawaited(sinkronkan(userId));
    return koinBaru;
  }

  Future<bool> beliTeko({
    required int userId,
    required int canId,
    required int harga,
    required String namaTeko,
  }) async {
    final db = await _db;
    var berhasil = false;

    await db.transaction((txn) async {
      await _pastikanReward(txn, userId);
      final r = await txn.query('user_rewards',
          columns: ['total_coins'],
          where: 'user_id = ?',
          whereArgs: [userId],
          limit: 1);
      final koin = r.first['total_coins'] as int;

      final sudah = await txn.query('user_watering_cans',
          where: 'user_id = ? AND can_id = ?', whereArgs: [userId, canId]);
      if (koin < harga || sudah.isNotEmpty) return;

      await txn.update('user_rewards', {'total_coins': koin - harga, 'synced': 0},
          where: 'user_id = ?', whereArgs: [userId]);
      await txn.insert('user_watering_cans',
          {'user_id': userId, 'can_id': canId, 'is_active': 0, 'synced': 0});
      berhasil = true;
    });

    if (!berhasil) return false;

    await BlockchainService.catat(
      userId: userId,
      poin: harga,
      deskripsi: 'Membeli penyiram tanaman ($namaTeko)',
      tipe: BlockchainService.tipePengeluaran,
    );
    unawaited(sinkronkan(userId));
    return true;
  }

  Future<void> gunakanTeko(int userId, int canId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('user_watering_cans', {'is_active': 0, 'synced': 0},
          where: 'user_id = ? AND is_active = 1', whereArgs: [userId]);
      if (canId != 0) {
        await txn.update('user_watering_cans', {'is_active': 1, 'synced': 0},
            where: 'user_id = ? AND can_id = ?', whereArgs: [userId, canId]);
      }
    });
    unawaited(sinkronkan(userId));
  }

  Future<void> sinkronkan(int userId) async {
    if (_sedangSinkron) return;
    _sedangSinkron = true;
    try {
      final db = await _db;

      final rewards = await db.query('user_rewards',
          where: 'user_id = ? AND synced = 0', whereArgs: [userId]);
      for (final r in rewards) {
        await _supabase.from('user_rewards').upsert({
          'user_id': r['user_id'],
          'total_coins': r['total_coins'],
          'total_waterings': r['total_waterings'],
          'last_watered_at': r['last_watered_at'],
          'synced': 1,
        }, onConflict: 'user_id');
        await db.update('user_rewards', {'synced': 1},
            where: 'id = ?', whereArgs: [r['id']]);
      }

      final cans = await db.query('user_watering_cans',
          where: 'user_id = ? AND synced = 0', whereArgs: [userId]);
      for (final c in cans) {
        await _supabase.from('user_watering_cans').upsert({
          'user_id': c['user_id'],
          'can_id': c['can_id'],
          'is_active': c['is_active'] == 1,
          'synced': 1,
        }, onConflict: 'user_id,can_id');
        await db.update('user_watering_cans', {'synced': 1},
            where: 'id = ?', whereArgs: [c['id']]);
      }
    } catch (e) {
      debugPrint('Sinkronisasi penyiraman tertunda: $e');
    } finally {
      _sedangSinkron = false;
    }
  }

  Future<void> _pastikanReward(DatabaseExecutor ex, int userId) async {
    final ada = await ex.query('user_rewards',
        columns: ['id'], where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (ada.isEmpty) {
      await ex.insert('user_rewards', {
        'user_id': userId,
        'total_coins': koinAwal,
        'total_waterings': 0,
        'synced': 0,
      });
    }
  }

  Future<void> _tarikDariServerJikaKosong(Database db, int userId) async {
    try {
      Future<bool> kosong(String tabel) async {
        final n = Sqflite.firstIntValue(await db.rawQuery(
                'SELECT COUNT(*) FROM $tabel WHERE user_id = ?', [userId])) ??
            0;
        return n == 0;
      }

      if (await kosong('user_rewards')) {
        final r = await _supabase
            .from('user_rewards')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (r != null) {
          await db.insert(
              'user_rewards',
              {
                'user_id': userId,
                'total_coins': r['total_coins'] ?? 0,
                'total_waterings': r['total_waterings'] ?? 0,
                'last_watered_at': r['last_watered_at'],
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (await kosong('user_watering_cans')) {
        final rows = await _supabase
            .from('user_watering_cans')
            .select()
            .eq('user_id', userId);
        for (final c in rows) {
          await db.insert(
              'user_watering_cans',
              {
                'user_id': userId,
                'can_id': c['can_id'],
                'is_active': (c['is_active'] == true) ? 1 : 0,
                'synced': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      debugPrint('Tarik data dari server dilewati: $e');
    }
  }
}