
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/diagnosa_result.dart';

class DiagnosaService {
  static const String _apiKey =
      String.fromEnvironment('DIAGNOSA_API_KEY');

  // Pastikan model ini tersedia untuk API key dan proyek Gemini kamu.
  static const String _model = 'gemini-2.5-flash';

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';

  static const String _system = '''
Kamu adalah asisten diagnosis tanaman dan penyuluh pertanian
yang membantu petani Indonesia memahami kondisi tanaman.

Tugas:
1. Analisis foto dan gejala tanaman jika tersedia.
2. Dukung analisis dengan Google Search untuk mencari
   informasi penyakit, hama, nutrisi, dan masalah lingkungan.
3. Jangan menganggap semua daun kering sebagai penyakit.
   Pertimbangkan kekurangan air, kelebihan air, akar,
   cuaca, nutrisi, hama, dan penyakit.
4. Jangan mengarang hasil pengamatan atau sumber referensi.
5. Jika foto buram, bukan tanaman, atau bukti tidak cukup,
   jelaskan keterbatasannya dan turunkan keyakinan.
6. Jangan menyatakan diagnosis sebagai kepastian tanpa bukti.
7. Gunakan bahasa Indonesia sederhana dan praktis.
8. Jangan merekomendasikan pestisida tertentu tanpa dasar
   yang memadai. Utamakan pemeriksaan dan tindakan aman.

Balas dengan satu objek JSON tanpa Markdown:
{
  "penyakit": "dugaan masalah tanaman",
  "keyakinan": 0,
  "penjelasan": "penjelasan dan alasan dugaan",
  "langkah": [
    "langkah pemeriksaan atau penanganan"
  ]
}

Keyakinan adalah perkiraan tingkat keyakinan model,
BUKAN hasil pengukuran akurasi diagnosis.
Berikan 3 sampai 5 langkah yang relevan.
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
Keluhan petani: ${keluhan.trim().isEmpty ? 'Tidak ada keluhan tertulis; analisis dari foto.' : keluhan.trim()}

Analisis kondisi tanaman tersebut.
Gunakan Google Search untuk mencari referensi yang relevan.
Jangan memaksakan satu diagnosis jika bukti belum cukup.
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
              'parts': [
                {'text': _system}
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': parts,
              }
            ],
            'tools': [
              {
                'google_search': {},
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
              'maxOutputTokens': 4096,
            },
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode == 429) {
      throw Exception(
        'Batas penggunaan API tercapai. Tunggu sebentar '
        'atau periksa kuota dan tagihan Gemini.',
      );
    }

    if (response.statusCode == 400) {
      throw Exception(
        'Permintaan ditolak oleh Gemini. Periksa dukungan '
        'model, Google Search, dan format permintaan.',
      );
    }

    if (response.statusCode == 401 ||
        response.statusCode == 403) {
      throw Exception(
        'API key tidak valid atau akses API tidak diizinkan.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        'Model Gemini tidak ditemukan. Periksa nama model '
        'yang tersedia di proyek kamu.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini mengalami kendala (${response.statusCode}). '
        'Silakan coba lagi.',
      );
    }

    final Map<String, dynamic> data;

    try {
      data = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respons dari Gemini tidak valid.');
    }

    final candidates = data['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception(
        'Gemini tidak memberikan hasil. Coba foto lain '
        'atau tuliskan gejala tanaman lebih jelas.',
      );
    }

    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final responseParts = content?['parts'] as List?;

    if (responseParts == null) {
      throw Exception('Hasil analisis tidak dapat dibaca.');
    }

    final text = responseParts
        .whereType<Map>()
        .where((part) => part['text'] is String)
        .map((part) => part['text'] as String)
        .join('\n')
        .trim();

    if (text.isEmpty) {
      throw Exception('Gemini memberikan jawaban kosong.');
    }

    final resultJson = _extractJson(text);

    final sources = <DiagnosaSource>[];
    final seenUrls = <String>{};

    // Mengambil sumber web yang dikembalikan Google Search grounding.
    final metadata =
        candidate['groundingMetadata'] as Map<String, dynamic>?;

    final chunks = metadata?['groundingChunks'] as List? ?? [];

    for (final item in chunks) {
      if (item is! Map) continue;

      final web = item['web'];
      if (web is! Map) continue;

      final url = web['uri']?.toString() ?? '';
      final title = web['title']?.toString() ?? 'Referensi web';

      final uri = Uri.tryParse(url);

      if (uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          !seenUrls.add(url)) {
        continue;
      }

      sources.add(
        DiagnosaSource(
          title: title,
          url: url,
        ),
      );
    }

    final result = DiagnosaResult.fromJson(resultJson);

    return result.copyWith(sumber: sources);
  }

  Map<String, dynamic> _extractJson(String text) {
    var clean = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');

    if (start < 0 || end <= start) {
      throw Exception('Format jawaban AI tidak valid. Coba lagi.');
    }

    clean = clean.substring(start, end + 1);

    try {
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Jawaban AI tidak bisa dibaca. Silakan coba lagi.',
      );
    }
  }

  String _mediaType(String path) {
    final p = path.toLowerCase();

    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';

    return 'image/jpeg';
  }
}
