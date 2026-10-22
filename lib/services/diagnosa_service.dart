import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/diagnosa_result.dart';

class DiagnosaService {
  static const String _apiKey =
      String.fromEnvironment('DIAGNOSA_API_KEY');

  static const String _model = 'gemini-3.5-flash-lite';

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';

  static const String _prompt = '''
Kamu adalah asisten diagnosis tanaman untuk petani Indonesia.
Analisis foto dan/atau keluhan secara hati-hati. Jangan mengarang
gejala atau memastikan diagnosis jika buktinya belum cukup.
Gunakan bahasa Indonesia sederhana dan singkat. Berikan tindakan
awal yang aman; jangan menyarankan pestisida tertentu tanpa dasar.

Balas HANYA dalam JSON:
{
  "penyakit": "dugaan masalah, singkat",
  "keyakinan": 0,
  "penjelasan": "alasan utama, maksimal 2 kalimat",
  "langkah": ["langkah 1", "langkah 2", "langkah 3"]
}

Maksimal 3 langkah. Keyakinan adalah perkiraan model, bukan
hasil pengukuran akurasi. Jika bukti kurang, katakan belum pasti.
''';

  Future<DiagnosaResult> analisis({
    required String tanaman,
    required String keluhan,
    File? foto,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'API key belum diisi. Jalankan aplikasi dengan '
        '--dart-define=DIAGNOSA_API_KEY=KUNCI_KAMU',
      );
    }

    if (foto == null && keluhan.trim().isEmpty) {
      throw Exception('Unggah foto atau isi keluhan tanaman.');
    }

    final parts = <Map<String, dynamic>>[];

    if (foto != null) {
      final bytes = await foto.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Foto kosong. Silakan pilih foto lain.');
      }

      parts.add({
        'inline_data': {
          'mime_type': _mediaType(foto.path),
          'data': base64Encode(bytes),
        },
      });
    }

    parts.add({
      'text': '''
Jenis tanaman: ${tanaman.trim().isEmpty ? 'Belum diketahui' : tanaman.trim()}
Keluhan: ${keluhan.trim().isEmpty ? 'Tidak ada; analisis dari foto.' : keluhan.trim()}
''',
    });

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: jsonEncode({
            'system_instruction': {
              'parts': [{'text': _prompt}],
            },
            'contents': [
              {'role': 'user', 'parts': parts},
            ],
            'generationConfig': {
              'temperature': 0.2,
              'maxOutputTokens': 1024,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      if (response.statusCode == 429) {
        throw Exception('Kuota Gemini habis atau terlalu banyak permintaan.');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('API key tidak valid atau akses tidak diizinkan.');
      }
      if (response.statusCode == 404) {
        throw Exception('Model Gemini tidak ditemukan. Periksa nama model.');
      }
      throw Exception('Gemini mengalami kendala (${response.statusCode}).');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respons Gemini tidak valid.');
    }

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini tidak memberikan hasil. Coba lagi.');
    }

    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final responseParts = content?['parts'] as List?;

    final answer = responseParts
            ?.whereType<Map>()
            .where((part) => part['text'] is String)
            .map((part) => part['text'] as String)
            .join('\n')
            .trim() ??
        '';

    if (answer.isEmpty) {
      throw Exception('Hasil analisis kosong atau tidak dapat dibaca.');
    }

    final result = DiagnosaResult.fromJson(_extractJson(answer));
    return result;
  }

  Map<String, dynamic> _extractJson(String text) {
    final clean = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');

    if (start < 0 || end <= start) {
      throw Exception('Format hasil diagnosis tidak valid. Coba lagi.');
    }

    try {
      return jsonDecode(clean.substring(start, end + 1))
          as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Hasil diagnosis tidak bisa dibaca. Coba lagi.');
    }
  }

  String _mediaType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
