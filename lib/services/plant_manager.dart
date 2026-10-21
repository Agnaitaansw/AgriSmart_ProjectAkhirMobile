
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_plant.dart';

class PlantManager {
  PlantManager._();

  static final PlantManager instance = PlantManager._();

  static const String _storageKey = 'agri_smart_user_plants_v1';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _notificationsReady = false;

  // Inisialisasi notifikasi
  Future<void> initializeNotifications() async {
    if (_notificationsReady) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(settings);

    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    _notificationsReady = true;
  }

  // Mengambil daftar tanaman yang tersimpan
  Future<List<UserPlant>> getPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;

      return decoded.map((item) {
        return UserPlant.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Memeriksa apakah tanaman sudah ditambahkan
  Future<bool> contains(String name) async {
    final plants = await getPlants();

    return plants.any(
      (plant) => plant.name.toLowerCase() == name.toLowerCase(),
    );
  }

  // Menambahkan tanaman dan mengaktifkan pengingat
  Future<void> addPlant(UserPlant plant) async {
    final plants = await getPlants();

    final alreadyExists = plants.any(
      (item) => item.name.toLowerCase() == plant.name.toLowerCase(),
    );

    if (alreadyExists) return;

    plants.add(plant);

    await _save(plants);
    await _scheduleWateringReminder(plant);
  }

  // Menghapus tanaman dan pengingatnya
  Future<void> removePlant(UserPlant plant) async {
    final plants = await getPlants();

    plants.removeWhere((item) => item.id == plant.id);

    await _save(plants);
    await initializeNotifications();

    final id = _notificationId(plant);

    await _notifications.cancel(id);
  }

  // Menyimpan daftar tanaman
  Future<void> _save(List<UserPlant> plants) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _storageKey,
      jsonEncode(
        plants.map((plant) => plant.toJson()).toList(),
      ),
    );
  }

  // Membuat ID notifikasi
  int _notificationId(UserPlant plant) {
    return plant.id.hashCode & 0x7fffffff;
  }

  // Menjadwalkan pengingat penyiraman setiap hari
  Future<void> _scheduleWateringReminder(UserPlant plant) async {
    await initializeNotifications();

    final id = _notificationId(plant);

    await _notifications.periodicallyShow(
      id,
      'Jangan lupa menyiram ${plant.name} 🌱',
      'Saatnya menyiram tanaman ${plant.name}.',
      RepeatInterval.daily,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'agri_smart_watering',
          'Pengingat Penyiraman Tanaman',
          channelDescription:
              'Pengingat rutin untuk menyiram tanaman.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // Mengaktifkan kembali pengingat tanaman yang tersimpan
  Future<void> rescheduleAllReminders() async {
    await initializeNotifications();

    final plants = await getPlants();

    for (final plant in plants) {
      await _scheduleWateringReminder(plant);
    }
  }
}
