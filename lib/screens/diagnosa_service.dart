
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../models/diagnosa_result.dart';

/// Versi pengembangan menggunakan Google Gemini.
/// Jalankan dengan --dart-define=DIAGNOSA_API_KEY=KEY_BARU
/// Untuk produksi, gunakan backend agar API key tidak ditanam di aplikasi.
class DiagnosaService {
  static const _apiKey =
      String.fromEnvironment('DIAGNOSA_API_KEY');

  static const _model = 'gemini-flash-latest';

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const _system = '''
Kamu adalah ahli fitopatologi dan penyuluh pertanian di Indonesia.
Diagnosa penyakit/hama tanaman berdasarkan foto dan/atau keluhan petani.
Jawab HANYA dengan JSON valid dengan format:
{"penyakit": "nama penyakit/hama atau 'Tanaman tampak sehat' atau 'Tidak dapat dipastikan'",
 "keyakinan": angka 0-100,
 "penjelasan": "1-2 kalimat penyebab dalam bahasa Indonesia sederhana",
 "langkah": ["3-5 langkah penanganan singkat dan praktis"]}
Jika foto bukan tanaman atau terlalu buram, set keyakinan rendah dan minta foto yang lebih jelas pada "penjelasan".
''';

  Future<DiagnosaResult> analisis({
    required String tanaman,
    required String keluhan,
    File? foto,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'API key belum diisi. Jalankan aplikasi dengan '
        '--dart-define=DIAGNOSA_API_KEY=...',
      );
    }

    final parts = <Map<String, dynamic>>[];

    if (foto != null) {
      final bytes = await foto.readAsBytes();

      parts.add({
        'inline_data': {
          'mime_type': _mediaType(foto.path),
          'data': base64Encode(bytes),
        },
      });
    }

    parts.add({
      'text': 'Tanaman: $tanaman\n'
          'Keluhan: ${keluhan.trim().isEmpty ? "(tidak ada, analisis dari foto)" : keluhan.trim()}',
    });

    final res = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'content-type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': _system}
              ],
            },
            'contents': [
              {'role': 'user', 'parts': parts},
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.3,
            },
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (res.statusCode == 429) {
      throw Exception(
        'Batas penggunaan gratis tercapai. Tunggu sebentar lalu coba lagi.',
      );
    }

    if (res.statusCode == 400 || res.statusCode == 403) {
      throw Exception(
        'API key tidak valid atau permintaan ditolak (${res.statusCode}).',
      );
    }

    if (res.statusCode == 404) {
      throw Exception(
        'Nama model tidak ditemukan. Periksa nama model Gemini.',
      );
    }

    if (res.statusCode != 200) {
      throw Exception('Server error ${res.statusCode}');
    }

    final data =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    try {
      final text = (data['candidates'][0]['content']['parts'] as List)
          .map((p) => p['text'] ?? '')
          .join();

      final clean = text
          .replaceAll(RegExp(r'```json|```'), '')
          .trim();

      return DiagnosaResult.fromJson(
        jsonDecode(clean) as Map<String, dynamic>,
      );
    } catch (_) {
      throw Exception('AI tidak memberi jawaban yang valid, coba lagi.');
    }
  }

  String _mediaType(String path) {
    final p = path.toLowerCase();

    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';

    return 'image/jpeg';
  }
}
