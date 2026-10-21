import 'package:flutter/material.dart';
import 'constants.dart';

class CropRecommendation {
  final String name;
  final int percent;
  final String note;
  final Color color;
  final bool highlighted;

  const CropRecommendation({
    required this.name,
    required this.percent,
    required this.note,
    required this.color,
    this.highlighted = false,
  });
}

class CropAnalysisResult {
  final double latitude;
  final double longitude;
  final double altitude;
  final String zoneName;
  final List<CropRecommendation> recommendations;

  const CropAnalysisResult({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.zoneName,
    required this.recommendations,
  });
}

/// Menyimpan hasil analisis terakhir agar halaman Tanaman menggunakan
/// hasil yang sama, bukan membuat analisis atau daftar rekomendasi baru.
class CropAnalysisStore {
  CropAnalysisStore._();
  static CropAnalysisResult? latest;
}

CropAnalysisResult analyzeCropRecommendations({
  required double latitude,
  required double longitude,
  required double altitude,
}) {
  late final String zoneName;
  late final List<CropRecommendation> recommendations;

  if (altitude < 25) {
    zoneName = 'Pesisir / Pantai (< 25 mdpl)';
    recommendations = const [
      CropRecommendation(name: 'Kelapa Dalam / Genjah', percent: 95,
        note: 'Toleran terhadap kadar garam tinggi dan angin kencang', color: AppColors.green, highlighted: true),
      CropRecommendation(name: 'Semangka', percent: 88,
        note: 'Suhu hangat pesisir sangat mendukung pembentukan gula', color: AppColors.up),
      CropRecommendation(name: 'Melon', percent: 79,
        note: 'Butuh intensitas cahaya matahari penuh sepanjang hari', color: AppColors.amber),
      CropRecommendation(name: 'Bawang Merah', percent: 93,
        note: 'Angin pantai dan sinar matahari penuh sangat efektif menekan pertumbuhan jamur pada daun', color: AppColors.green, highlighted: true),
      CropRecommendation(name: 'Buah Naga', percent: 86,
        note: 'Kaktus tropis yang menyukai iklim panas terik dan tanah pasir agar akar tidak mudah busuk', color: AppColors.up),
    ];
  } else if (altitude <= 400) {
    zoneName = 'Dataran Rendah (25 - 400 mdpl)';
    recommendations = const [
      CropRecommendation(name: 'Cabai rawit', percent: 92,
        note: 'Suhu ideal 25-30°C, tanah lempung berpasir gembur', color: AppColors.green, highlighted: true),
      CropRecommendation(name: 'Padi sawah', percent: 85,
        note: 'Pasokan air irigasi mencukupi, tanah aluvial/grumosol', color: AppColors.up),
      CropRecommendation(name: 'Jagung hibrida', percent: 74,
        note: 'Kelembapan tanah sedang, aerasi tanah berjalan baik', color: AppColors.amber),
      CropRecommendation(name: 'Tomat Sayur', percent: 90,
        note: 'Suhu hangat 24-28°C mempercepat proses pembungaan dan pematangan buah varietas hibrida', color: AppColors.green, highlighted: true),
      CropRecommendation(name: 'Kacang Tanah', percent: 84,
        note: 'Tanah lempung berpasir sangat memudahkan ginofor (calon buah) menembus tanah', color: AppColors.up),
    ];
  } else {
    zoneName = 'Dataran Tinggi (> 400 mdpl)';
    recommendations = const [
      CropRecommendation(name: 'Kopi Arabika / Teh', percent: 96,
        note: 'Suhu sejuk 15-22°C sangat cocok untuk cita rasa optimal', color: AppColors.green, highlighted: true),
      CropRecommendation(name: 'Kentang', percent: 89,
        note: 'Ketinggian ideal memperkecil risiko hama penyakit dataran rendah', color: AppColors.up),
      CropRecommendation(name: 'Wortel & Kubis', percent: 81,
        note: 'Suhu dingin mendukung pembesaran umbi dan pembentukan krop', color: AppColors.amber),
      CropRecommendation(name: 'Stroberi', percent: 95,
        note: 'Penurunan suhu drastis di malam hari (suhu dingin) sangat wajib untuk merangsang pembungaan', color: AppColors.green, highlighted: true),
      CropRecommendation(name: 'Kubis (Kol)', percent: 88,
        note: 'Udara sejuk dataran tinggi membuat krop (bulatan daun) terbentuk sangat padat dan tidak mudah pecah', color: AppColors.up),
    ];
  }

  return CropAnalysisResult(
    latitude: latitude,
    longitude: longitude,
    altitude: altitude,
    zoneName: zoneName,
    recommendations: recommendations,
  );
}
