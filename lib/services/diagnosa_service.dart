import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Layanan chat FlorAI berbasis Gemini multimodal.
/// API key diberikan melalui --dart-define, bukan ditulis langsung di kode.
class DiagnosaService {
  static const String _apiKey =
      String.fromEnvironment('DIAGNOSA_API_KEY');

  static const String _model = 'gemini-3.5-flash-lite';

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';


  static const String _systemPrompt = '''
Kamu adalah FlorAI, asisten konsultasi tanaman untuk pengguna Indonesia.
Gunakan bahasa Indonesia yang ramah, jelas, praktis, dan tidak bertele-tele.
Kamu boleh menjawab pertanyaan lanjutan dan mempertahankan konteks percakapan.
Jika pengguna mengirim foto, periksa hanya ciri yang benar-benar terlihat.
Jangan mengarang gejala atau memastikan penyakit jika bukti belum cukup.
Jelaskan kemungkinan penyebab dengan tingkat kepastian yang wajar, lalu berikan
langkah perawatan awal yang aman. Jangan merekomendasikan dosis atau pestisida
spesifik tanpa informasi yang cukup. Jika perlu, tanyakan detail tambahan seperti
jenis tanaman, pola penyebaran gejala, kondisi tanah, penyiraman, atau cuaca.
Ingatkan pengguna bahwa analisis foto adalah panduan awal, bukan pengganti
pemeriksaan langsung oleh penyuluh pertanian untuk kasus berat.
Jawab sebagai percakapan biasa, bukan JSON dan bukan markdown table.
''';

  Future<String> chat({
    required List<Map<String, dynamic>> history,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception(
        'API key belum diisi. Jalankan aplikasi dengan '
        '--dart-define=DIAGNOSA_API_KEY=KUNCI_KAMU',
      );
    }

    if (history.isEmpty) {
      throw Exception('Tulis pertanyaan atau unggah foto terlebih dahulu.');
    }

    // Batasi riwayat agar permintaan tidak membesar tanpa batas.
    var recentHistory = history.length > 12
        ? history.sublist(history.length - 12)
        : List<Map<String, dynamic>>.from(history);

    // Gemini umumnya mengharapkan percakapan dimulai dari pesan pengguna.
    if (recentHistory.isNotEmpty && recentHistory.first['role'] == 'model') {
      recentHistory = recentHistory.sublist(1);
    }

    final contents = <Map<String, dynamic>>[];

    for (final message in recentHistory) {
      final role = message['role'] == 'model' ? 'model' : 'user';
      final text = (message['text'] as String? ?? '').trim();
      final photo = message['photo'];
      final parts = <Map<String, dynamic>>[];

      if (photo is File) {
        final bytes = await photo.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('Foto kosong atau tidak bisa dibaca. Pilih foto lain.');
        }
        parts.add({
          'inline_data': {
            'mime_type': _mediaType(photo.path),
            'data': base64Encode(bytes),
          },
        });
      }

      if (text.isNotEmpty) {
        parts.add({'text': text});
      } else if (parts.isEmpty) {
        continue;
      }

      contents.add({
        'role': role,
        'parts': parts,
      });
    }

    if (contents.isEmpty) {
      throw Exception('Pesan tidak dapat diproses. Coba kirim ulang.');
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': _systemPrompt}
                ],
              },
              'contents': contents,
              'generationConfig': {
                'temperature': 0.4,
                'maxOutputTokens': 1200,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on SocketException {
      throw Exception('Tidak ada koneksi internet. Periksa jaringanmu.');
    } on HttpException {
      throw Exception('Permintaan ke layanan AI gagal. Coba lagi.');
    } on FormatException {
      throw Exception('Alamat layanan AI tidak valid.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('FlorAI membutuhkan waktu terlalu lama. Coba lagi.');
      }
      rethrow;
    }

    if (response.statusCode != 200) {
      String? apiMessage;
      try {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        apiMessage = errorData['error']?['message']?.toString();
      } catch (_) {
        // Gunakan pesan umum jika respons error tidak berbentuk JSON.
      }

      if (response.statusCode == 400) {
        throw Exception(
          'Permintaan tidak dapat diproses. ${apiMessage ?? 'Periksa foto atau pesan.'}',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('API key tidak valid atau akses Gemini tidak diizinkan.');
      }
      if (response.statusCode == 404) {
        throw Exception(
          'Model Gemini tidak ditemukan. Periksa nama model dan akses API.',
        );
      }
      if (response.statusCode == 429) {
        throw Exception('Kuota AI sedang habis atau permintaan terlalu banyak. Coba lagi nanti.');
      }
      throw Exception(
        'Layanan AI mengalami kendala (${response.statusCode}). '
        '${apiMessage ?? ''}'.trim(),
      );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respons dari FlorAI tidak dapat dibaca.');
    }

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception(
        'FlorAI belum bisa menjawab pesan ini. Coba ubah pertanyaan atau foto.',
      );
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
      throw Exception(
        'FlorAI tidak menghasilkan jawaban teks. Coba pertanyaan lain.',
      );
    }

    return answer;
  }

  String _mediaType(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    if (lowerPath.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
