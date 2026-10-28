import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../screens/simulasi_penyiraman_screen.dart';
import 'penyiraman_repository.dart';
import 'session_manager.dart';
import 'sesi_user.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  static const _dailyId = 900; 
  static const _hourlyBaseId = 1000; 
  static const _hourlyMaxId = 1100;
  static const _payloadMinigame = 'minigame';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _launchDitangani = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'watering_reminder',
      'Pengingat Penyiraman',
      channelDescription: 'Pengingat harian untuk menyiram tanaman',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _detailsPerJam = NotificationDetails(
    android: AndroidNotificationDetails(
      'watering_hourly',
      'Pengingat Siram Tiap Jam',
      channelDescription:
          'Pengingat tiap jam selama tanaman di mini game belum disiram',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;

    tz.initializeTimeZones();
    try {
      final dynamic info = await FlutterTimezone.getLocalTimezone();
      final String zone = info is String ? info : info.identifier as String;
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (e) {
      debugPrint('Gagal ambil zona waktu, pakai Asia/Jakarta: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payloadMinigame) _bukaMinigame();
      },
    );
    _ready = true;
  }

  Future<bool> requestPermissions() async {
    await init();
    final notif = await _android?.requestNotificationsPermission() ?? false;
    await _android?.requestExactAlarmsPermission();
    return notif;
  }

  Future<void> perbaruiPengingat() async {
    try {
      await init();
      await _plugin.cancel(id: _dailyId); 

      final userId = await idUserLogin();
      final prefs = await SharedPreferences.getInstance();
      final aktif = prefs.getBool('plant_notifications_$userId') ?? true;
      if (!aktif) {
        await _batalkanPerJam();
        return;
      }

      final status = await PenyiramanRepository().muat(userId);
      await jadwalkanPerJam(sudahDisiramHariIni: status.sudahDisiramHariIni);
    } catch (e) {
      debugPrint('Gagal memperbarui pengingat: $e');
    }
  }

  /// Menjadwalkan pengingat tiap jam (tepat di awal jam) antara [jamMulai]
  /// dan [jamSelesai], untuk [hariKeDepan] hari ke depan.
  ///
  /// Kalau aplikasi tidak dibuka selama [hariKeDepan] hari, pengingat berhenti
  /// sendiri (tidak mengirim notifikasi tanpa akhir).
  /// Ingin 24 jam penuh? Isi jamMulai: 0, jamSelesai: 23.
  Future<void> jadwalkanPerJam({
    required bool sudahDisiramHariIni,
    int jamMulai = 9,
    int jamSelesai = 21,
    int hariKeDepan = 3,
  }) async {
    await init();
    await _batalkanPerJam();
    await _plugin.cancel(id: _dailyId); 

    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    final now = tz.TZDateTime.now(tz.local);
    var id = _hourlyBaseId;

    for (var d = 0; d < hariKeDepan; d++) {
      if (d == 0 && sudahDisiramHariIni) continue; 

      final hari = now.add(Duration(days: d));
      for (var h = jamMulai; h <= jamSelesai; h++) {
        final waktu =
            tz.TZDateTime(tz.local, hari.year, hari.month, hari.day, h);
        if (!waktu.isAfter(now.add(const Duration(minutes: 1)))) continue;
        if (id >= _hourlyMaxId) return;

        await _plugin.zonedSchedule(
          id: id++,
          title: 'Tanamanmu Haus 🌱',
          body: 'Belum disiram hari ini. Ketuk untuk mulai menyiram!',
          scheduledDate: waktu,
          notificationDetails: _detailsPerJam,
          payload: _payloadMinigame,
          androidScheduleMode: canExact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> _batalkanPerJam() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final n in pending) {
      if (n.id >= _hourlyBaseId && n.id < _hourlyMaxId) {
        await _plugin.cancel(id: n.id);
      }
    }
  }

  Future<void> bukaMinigameJikaDariNotifikasi() async {
    await init();
    if (_launchDitangani) return;

    final detail = await _plugin.getNotificationAppLaunchDetails();
    if (detail?.didNotificationLaunchApp == true &&
        detail?.notificationResponse?.payload == _payloadMinigame) {
      _launchDitangani = true;
      await _bukaMinigame();
    }
  }

  Future<void> _bukaMinigame() async {
    if (!await SessionManager.instance.isValid()) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const SimulasiPenyiramanScreen()),
    );
  }

  Future<void> scheduleDailyWatering({int hour = 21, int minute = 52}) async {
    await init();
    await _plugin.cancel(id: _dailyId); 

    final canExact = await _android?.canScheduleExactNotifications() ?? false;

    await _plugin.zonedSchedule(
      id: _dailyId,
      title: 'Tanamanmu Haus 🌱',
      body: 'Yuk buka game dan siram tanamanmu hari ini!',
      scheduledDate: _nextInstance(hour, minute),
      notificationDetails: _details,
      payload: _payloadMinigame,
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // ulang tiap hari
    );
  }

  Future<void> cancelWatering() async {
    await init();
    await _plugin.cancel(id: _dailyId);
    await _batalkanPerJam();
  }


  Future<bool> isWateringScheduled() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) =>
        n.id == _dailyId ||
        (n.id >= _hourlyBaseId && n.id < _hourlyMaxId));
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  Future<void> showTest() async {
    await init();
    await _plugin.show(
      id: 999,
      title: 'Tes notifikasi',
      body: 'Kalau ini muncul, notifikasi sudah berfungsi.',
      notificationDetails: _detailsPerJam,
      payload: _payloadMinigame,
    );
  }
}