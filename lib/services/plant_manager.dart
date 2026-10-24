import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db_helper.dart';
import '../models/user_plant.dart';
import 'notification_service.dart';
import 'sesi_user.dart';

/// Tanaman milik user: disimpan di SQLite dulu, lalu dikirim ke Supabase.
/// Pengingat penyiraman tetap memakai notifikasi lokal.
class PlantManager {
  PlantManager._();

  static final PlantManager instance = PlantManager._();

  // Kunci lama (SharedPreferences), hanya dipakai untuk memindahkan data lama
  static const String _storageKeyLama = 'agri_smart_user_plants_v1';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Pengingat siram di "Tanaman Saya". DIMATIKAN: pengingat penyiraman
  /// sekarang hanya untuk mini game (lihat NotificationService).
  /// Ubah ke true kalau suatu saat ingin menyalakannya lagi.
  static const bool pengingatTanamanAktif = false;

  // user yang sudah disiapkan (migrasi + tarik data) selama aplikasi berjalan
  static final Set<int> _sudahDisiapkan = {};
  static bool _sedangSinkron = false;

  Future<Database> get _db => DbHelper.instance.database;
  SupabaseClient get _supabase => Supabase.instance.client;

  // Inisialisasi notifikasi
  Future<void> initializeNotifications() async {
    // Inisialisasi plugin hanya di NotificationService, supaya callback
    // ketukan notifikasi (buka mini game) tidak tertimpa.
    await NotificationService.instance.init();
  }

  // ───────────────────────── BACA ─────────────────────────

  // Mengambil daftar tanaman milik user yang login
  Future<List<UserPlant>> getPlants() async {
    final userId = await idUserLogin();
    await _siapkanUser(userId);

    final db = await _db;
    final rows = await db.query(
      'user_plants',
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );

    unawaited(sinkronkan(userId)); // kirim yang tertunda (kalau ada koneksi)
    return rows.map(UserPlant.fromMap).toList();
  }

  // Memeriksa apakah tanaman sudah ditambahkan
  Future<bool> contains(String name) async {
    final userId = await idUserLogin();
    await _siapkanUser(userId);

    final db = await _db;
    final rows = await db.query(
      'user_plants',
      columns: ['id'],
      where: 'user_id = ? AND deleted = 0 AND LOWER(plant_name) = ?',
      whereArgs: [userId, name.toLowerCase()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ───────────────────────── TULIS ─────────────────────────

  // Menambahkan tanaman dan mengaktifkan pengingat
  Future<void> addPlant(UserPlant plant) async {
    final userId = await idUserLogin();
    await _siapkanUser(userId);

    final db = await _db;
    final ada = await db.query(
      'user_plants',
      where: 'user_id = ? AND LOWER(plant_name) = ?',
      whereArgs: [userId, plant.name.toLowerCase()],
      limit: 1,
    );

    final int id;
    if (ada.isEmpty) {
      id = await db.insert('user_plants', {
        ...plant.toMap(userId),
        'deleted': 0,
        'synced': 0,
      });
    } else if (ada.first['deleted'] == 1) {
      // tanaman yang sebelumnya dihapus dipilih lagi
      id = ada.first['id'] as int;
      await db.update(
        'user_plants',
        {...plant.toMap(userId), 'deleted': 0, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      return; // sudah ada
    }

    await _scheduleWateringReminder(id, plant.name);
    unawaited(sinkronkan(userId));
  }

  // Menghapus tanaman dan pengingatnya
  Future<void> removePlant(UserPlant plant) async {
    final id = plant.id;
    if (id == null) return;

    final userId = await idUserLogin();
    final db = await _db;

    // Ditandai dihapus dulu; baris benar-benar dibuang setelah Supabase ikut terhapus
    await db.update(
      'user_plants',
      {'deleted': 1, 'synced': 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );

    await initializeNotifications();
    await _notifications.cancel(id: _notificationId(id)); // UBAH

    unawaited(sinkronkan(userId));
  }

  // ───────────────────────── SINKRONISASI ─────────────────────────

  /// Kirim perubahan yang belum terkirim (synced = 0) ke Supabase.
  /// Kalau offline, perubahan menunggu dan dicoba lagi nanti.
  Future<void> sinkronkan(int userId) async {
    if (_sedangSinkron) return;
    _sedangSinkron = true;
    try {
      final db = await _db;
      final rows = await db.query(
        'user_plants',
        where: 'user_id = ? AND synced = 0',
        whereArgs: [userId],
      );

      for (final r in rows) {
        if (r['deleted'] == 1) {
          await _supabase
              .from('user_plants')
              .delete()
              .eq('user_id', userId)
              .eq('plant_name', r['plant_name'] as String);
          await db.delete('user_plants',
              where: 'id = ? AND deleted = 1', whereArgs: [r['id']]);
        } else {
          await _supabase.from('user_plants').upsert({
            'user_id': userId,
            'plant_name': r['plant_name'],
            'planted_at': r['planted_at'],
            'watering_every_days': r['watering_every_days'],
            'harvest_days': r['harvest_days'],
            'synced': 1,
          }, onConflict: 'user_id,plant_name');
          await db.update('user_plants', {'synced': 1},
              where: 'id = ?', whereArgs: [r['id']]);
        }
      }
    } catch (e) {
      debugPrint('Sinkronisasi tanaman tertunda: $e');
    } finally {
      _sedangSinkron = false;
    }
  }

  // Sekali per sesi aplikasi untuk setiap user
  Future<void> _siapkanUser(int userId) async {
    if (_sudahDisiapkan.contains(userId)) return;
    // Pengingat tanaman dimatikan: buang yang sudah terlanjur terjadwal
    if (!pengingatTanamanAktif) await _batalkanSemuaPengingatTanaman();
    await _migrasiDariPrefs(userId);
    await _tarikDariServerJikaKosong(userId);
    _sudahDisiapkan.add(userId);
  }

  // Pindahkan tanaman lama dari SharedPreferences ke SQLite (sekali saja)
  Future<void> _migrasiDariPrefs(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKeyLama);
      if (raw == null || raw.isEmpty) return;

      final db = await _db;
      await initializeNotifications();

      final daftar = jsonDecode(raw) as List<dynamic>;
      for (final item in daftar) {
        final m = Map<String, dynamic>.from(item as Map);
        await db.insert(
          'user_plants',
          {
            'user_id': userId,
            'plant_name': m['name'] as String,
            'planted_at': m['plantedAt'] as String,
            'watering_every_days': m['wateringEveryDays'] as int,
            'harvest_days': m['harvestDays'] as int,
            'deleted': 0,
            'synced': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // pengingat lama memakai id dari teks; batalkan, lalu dijadwalkan ulang
        final idLama = m['id'];
        if (idLama is String) {
          await _notifications.cancel(id: idLama.hashCode & 0x7fffffff); // UBAH
        }
      }

      await prefs.remove(_storageKeyLama);
      await _jadwalkanUlangSemua(userId);
    } catch (e) {
      debugPrint('Migrasi tanaman lama dilewati: $e');
    }
  }

  // Kalau data lokal user kosong (misalnya login di HP baru), ambil dari Supabase
  Future<void> _tarikDariServerJikaKosong(int userId) async {
    try {
      final db = await _db;
      final n = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM user_plants WHERE user_id = ?', [userId])) ??
          0;
      if (n > 0) return;

      final rows =
          await _supabase.from('user_plants').select().eq('user_id', userId);
      if (rows.isEmpty) return;

      for (final r in rows) {
        await db.insert(
          'user_plants',
          {
            'user_id': userId,
            'plant_name': r['plant_name'],
            'planted_at': r['planted_at'],
            'watering_every_days': r['watering_every_days'] ?? 1,
            'harvest_days': r['harvest_days'] ?? 90,
            'deleted': 0,
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await _jadwalkanUlangSemua(userId);
    } catch (e) {
      debugPrint('Tarik tanaman dari server dilewati: $e');
    }
  }

  // ───────────────────────── PENGINGAT ─────────────────────────

  // ID notifikasi = id tanaman di database
  int _notificationId(int plantId) => plantId & 0x7fffffff;

  // ID milik mini game (NotificationService): 900, 999, 1000-1099
  bool _milikMiniGame(int id) =>
      id == 900 || id == 999 || (id >= 1000 && id < 1100);

  /// Batalkan semua pengingat tanaman yang masih terjadwal di sistem,
  /// tanpa menyentuh pengingat mini game.
  Future<void> _batalkanSemuaPengingatTanaman() async {
    try {
      await initializeNotifications();

      // 1. Semua jadwal yang bukan milik mini game
      final pending = await _notifications.pendingNotificationRequests();
      for (final n in pending) {
        if (!_milikMiniGame(n.id)) {
          await _notifications.cancel(id: n.id);
        }
      }

      // 2. Jaga-jaga: id dari tiap tanaman di database
      final db = await _db;
      final rows = await db.query('user_plants', columns: ['id']);
      for (final r in rows) {
        final nid = _notificationId(r['id'] as int);
        if (!_milikMiniGame(nid)) await _notifications.cancel(id: nid);
      }
    } catch (e) {
      debugPrint('Gagal membatalkan pengingat tanaman: $e');
    }
  }

  // Menjadwalkan pengingat penyiraman setiap hari
  Future<void> _scheduleWateringReminder(int plantId, String name) async {
    if (!pengingatTanamanAktif) return; // pengingat tanaman dimatikan
    await initializeNotifications();

    // UBAH: semua parameter sekarang bernama
    await _notifications.periodicallyShow(
      id: _notificationId(plantId),
      title: 'Jangan lupa menyiram $name 🌱',
      body: 'Saatnya menyiram tanaman $name.',
      repeatInterval: RepeatInterval.daily,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'agri_smart_watering',
          'Pengingat Penyiraman Tanaman',
          channelDescription: 'Pengingat rutin untuk menyiram tanaman.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _jadwalkanUlangSemua(int userId) async {
    if (!pengingatTanamanAktif) {
      await _batalkanSemuaPengingatTanaman();
      return;
    }
    await initializeNotifications();

    final db = await _db;
    final rows = await db.query(
      'user_plants',
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [userId],
    );
    for (final r in rows) {
      await _scheduleWateringReminder(r['id'] as int, r['plant_name'] as String);
    }
  }

  // Mengaktifkan kembali pengingat tanaman yang tersimpan.
  // Aman dipanggil sebelum login: kalau belum ada sesi, dilewati.
  Future<void> rescheduleAllReminders() async {
    final int userId;
    try {
      userId = await idUserLogin();
    } catch (_) {
      return;
    }
    await _siapkanUser(userId);
    await _jadwalkanUlangSemua(userId);
  }
}