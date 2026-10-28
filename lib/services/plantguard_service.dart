import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/plantguard_result.dart';

/// Diagnosis awal berbasis foto menggunakan Gemini multimodal.
class PlantGuardService {
  static const String _apiKey = String.fromEnvironment('DIAGNOSA_API_KEY');
  static const String _model = 'gemini-3.5-flash-lite';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const String _systemPrompt = '''
Kamu adalah PlantGuard, asisten pemeriksaan awal kesehatan tanaman berbahasa Indonesia.
Analisis foto dan informasi tambahan secara hati-hati. Sebutkan hanya gejala yang benar-benar terlihat.
Jangan memastikan penyakit bila bukti tidak cukup. Pertimbangkan penyakit, hama, kekurangan hara,
stres air, atau faktor lingkungan bila relevan. Berikan langkah awal yang aman; jangan memberi dosis
atau merekomendasikan pestisida spesifik tanpa informasi cukup. Bila foto tidak jelas atau bukan tanaman,
jelaskan keterbatasannya. Jawab HANYA JSON valid dengan struktur:
{
 "namaTanaman":"jenis tanaman atau Belum dapat dikenali",
 "kemungkinanGangguan":"kemungkinan gangguan atau Belum dapat dipastikan",
 "tingkatKeyakinan":"Rendah, Sedang, atau Tinggi",
 "tingkatKeparahan":"Ringan, Sedang, Berat, atau Belum dapat dinilai",
 "penjelasan":"penjelasan berdasarkan foto",
 "gejalaTerlihat":["gejala yang terlihat"],
 "langkahPenanganan":["langkah awal yang aman"],
 "pencegahan":["saran pencegahan"],
 "catatan":"keterbatasan dan kapan perlu bantuan penyuluh"
}
Jangan sertakan markdown atau teks di luar JSON. Hasil adalah panduan awal, bukan diagnosis pasti.
''';

  Future<PlantGuardResult> diagnose({
    required File photo,
    String additionalSymptoms = '',
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('API key belum diisi. Jalankan dengan --dart-define=DIAGNOSA_API_KEY=KUNCI_KAMU');
    }
    if (!await photo.exists()) throw Exception('Foto tidak ditemukan. Pilih foto lain.');
    final bytes = await photo.readAsBytes();
    if (bytes.isEmpty) throw Exception('Foto kosong atau tidak bisa dibaca.');

    final prompt = additionalSymptoms.trim().isEmpty
        ? 'Analisis foto tanaman ini dan berikan diagnosis awal sesuai format JSON.'
        : 'Analisis foto ini. Informasi pengguna: ${additionalSymptoms.trim()}. Gunakan format JSON.';

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': _apiKey},
        body: jsonEncode({
          'system_instruction': {'parts': [{'text': _systemPrompt}]},
          'contents': [{
            'role': 'user',
            'parts': [
              {'inline_data': {'mime_type': _mediaType(photo.path), 'data': base64Encode(bytes)}},
              {'text': prompt},
            ],
          }],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 1400,
            'responseMimeType': 'application/json',
          },
        }),
      ).timeout(const Duration(seconds: 60));
    } on SocketException {
      throw Exception('Tidak ada koneksi internet. Periksa jaringanmu.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('PlantGuard membutuhkan waktu terlalu lama. Coba lagi.');
      }
      rethrow;
    }

    if (response.statusCode != 200) {
      String? apiMessage;
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        apiMessage = body['error']?['message']?.toString();
      } catch (_) {}
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('API key tidak valid atau akses Gemini tidak diizinkan.');
      }
      if (response.statusCode == 404) {
        throw Exception('Model Gemini tidak ditemukan. Periksa nama model dan akses API.');
      }
      if (response.statusCode == 429) throw Exception('Kuota AI sedang habis. Coba lagi nanti.');
      throw Exception('Layanan PlantGuard bermasalah (${response.statusCode}). ${apiMessage ?? ''}');
    }

    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('PlantGuard belum bisa menganalisis foto ini. Coba foto lain.');
      }
      final candidate = candidates.first as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      final answer = parts?.whereType<Map>()
          .where((p) => p['text'] is String)
          .map((p) => p['text'] as String).join('\n').trim() ?? '';
      final cleaned = answer
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '').trim();
      return PlantGuardResult.fromJson(jsonDecode(cleaned) as Map<String, dynamic>);
    } on FormatException {
      throw Exception('Hasil diagnosis tidak dapat dibaca. Coba foto yang lebih jelas.');
    }
  }

  String _mediaType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
