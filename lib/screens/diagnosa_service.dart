import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../widgets/auth_widgets.dart';
import '../utils/constants.dart';
import '../models/diagnosa_result.dart';

/// Jalankan dengan:
/// flutter run --dart-define=DIAGNOSA_ENDPOINT=https://api.anthropic.com/v1/messages \
///             --dart-define=DIAGNOSA_API_KEY=sk-ant-xxxx
///
/// PENTING: untuk produksi, arahkan DIAGNOSA_ENDPOINT ke backend/proxy milikmu
/// sendiri (yang menyimpan API key). Jangan menaruh API key di dalam APK.
class DiagnosaService {
  static const _endpoint = String.fromEnvironment(
    'DIAGNOSA_ENDPOINT',
    defaultValue: 'https://api.anthropic.com/v1/messages',
  );
  static const _apiKey = String.fromEnvironment('DIAGNOSA_API_KEY');
  static const _model = 'claude-sonnet-5-5';

  static const _system = '''
Kamu adalah ahli fitopatologi dan penyuluh pertanian di Indonesia.
Diagnosa penyakit/hama tanaman berdasarkan foto dan/atau keluhan petani.
Jawab HANYA dengan JSON valid tanpa teks lain, tanpa markdown, format:
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
    final content = <Map<String, dynamic>>[];

    if (foto != null) {
      final bytes = await foto.readAsBytes();
      content.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': _mediaType(foto.path),
          'data': base64Encode(bytes),
        },
      });
    }

    content.add({
      'type': 'text',
      'text': 'Tanaman: $tanaman\n'
          'Keluhan: ${keluhan.trim().isEmpty ? "(tidak ada, analisis dari foto)" : keluhan.trim()}',
    });

    final res = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'content-type': 'application/json',
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': 1000,
            'system': _system,
            'messages': [
              {'role': 'user', 'content': content},
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (res.statusCode != 200) {
      throw Exception('Server error ${res.statusCode}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final text = (data['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'])
        .join();

    final clean = text.replaceAll(RegExp(r'```json|```'), '').trim();
    try {
      return DiagnosaResult.fromJson(jsonDecode(clean) as Map<String, dynamic>);
    } catch (_) {
      throw Exception('Format jawaban AI tidak valid, coba lagi.');
    }
  }

  String _mediaType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}