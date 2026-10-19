import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1F5C3E);
  static const primaryLight = Color(0xFF4A7C59);
  static const background = Color(0xFFF3F7F1);
  static const field = Color(0xFFFFFFFF);
  static const fieldBorder = Color(0xFFDCE5DC);
  static const fieldFill = Color(0xFFBFDCC4);
  static const infoBox = Color(0xFFDDEBDD);
  static const textMuted = Color(0xFF6B7A70);
}

class AppConfig {
  /// Ganti dengan URL backend REST API kamu (wajib HTTPS di produksi).
  static const apiBaseUrl = 'https://api.example.com';
  static const apiTimeout = Duration(seconds: 10);

  /// Durasi session.
  static const sessionRemember = Duration(days: 7);
  static const sessionDefault = Duration(hours: 2);
}
