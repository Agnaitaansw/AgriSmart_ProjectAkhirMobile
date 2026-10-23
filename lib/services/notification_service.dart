import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _dailyId = 900;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'watering_reminder',
      'Pengingat Penyiraman',
      channelDescription: 'Pengingat harian untuk menyiram tanaman',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;

    tz.initializeTimeZones();
    try {
      // Aman untuk flutter_timezone versi lama (String) maupun baru (objek)
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
    );
    _ready = true;
  }

  /// Minta izin notifikasi (Android 13+) dan alarm exact (Android 12+).
  Future<bool> requestPermissions() async {
    await init();
    final notif = await _android?.requestNotificationsPermission() ?? false;
    await _android?.requestExactAlarmsPermission();
    return notif;
  }

  /// Jadwalkan notifikasi penyiraman setiap hari jam 09.00 //
  Future<void> scheduleDailyWatering({int hour = 21, int minute = 52}) async {
    await init();
    await _plugin.cancel(id: _dailyId); // hindari jadwal dobel

    final canExact = await _android?.canScheduleExactNotifications() ?? false;

    await _plugin.zonedSchedule(
      id: _dailyId,
      title: 'Tanamanmu Haus 🌱',
      body: 'Yuk buka game dan siram tanamanmu hari ini!',
      scheduledDate: _nextInstance(hour, minute),
      notificationDetails: _details,
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // ulang tiap hari
    );
  }

  Future<void> cancelWatering() async {
    await init();
    await _plugin.cancel(id: _dailyId);
  }

  /// Cek apakah pengingat harian sedang terjadwal di sistem.
  Future<bool> isWateringScheduled() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) => n.id == _dailyId);
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// Untuk tes cepat: muncul langsung.
  Future<void> showTest() async {
    await init();
    await _plugin.show(
      id: 999,
      title: 'Tes notifikasi',
      body: 'Kalau ini muncul, notifikasi sudah berfungsi.',
      notificationDetails: _details,
    );
  }
}