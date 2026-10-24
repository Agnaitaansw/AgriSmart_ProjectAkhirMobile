import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client What's My Zone API. Key dipasok lewat --dart-define.
class PlantApiService {
  PlantApiService._();
  static const String _apiKey = String.fromEnvironment('WHATS_MY_ZONE_API_KEY');
  static const String _baseUrl = 'https://www.whatsmy.zone/api';
  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  static Map<String, String> get _headers => {
    'x-api-key': _apiKey,
    'Accept': 'application/json',
  };

  static Future<Map<String, dynamic>> getPlantProfile(String name) async {
    _ensureConfigured();
    final uri = Uri.parse('$_baseUrl/plant-profile.php')
        .replace(queryParameters: {'name': name});
    final response = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    final data = _decode(response);
    if (data['match_status'] != null && data['match_status'] != 'matched') {
      throw PlantApiException((data['reason'] ??
          'Nama tanaman tidak cocok dengan katalog API.').toString());
    }
    final plant = data['plant'];
    if (plant is! Map) {
      throw const PlantApiException('Profil tanaman tidak tersedia dari API.');
    }
    return Map<String, dynamic>.from(plant);
  }

  static Future<List<Map<String, dynamic>>> findPlantsForLocation({
    required double latitude,
    required double longitude,
    String growingPosition = 'outdoor_full_sun',
  }) async {
    _ensureConfigured();
    final uri = Uri.parse('$_baseUrl/plant-search.php').replace(
      queryParameters: {
        'action': 'space',
        'lat': '$latitude',
        'lon': '$longitude',
        'growing_position': growingPosition,
        'sort': 'best',
        'per_page': '12',
      },
    );
    final response = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    final data = _decode(response);
    final items = data['items'];
    if (items is! List) return [];
    return items.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const PlantApiException('Respons API tidak dapat dibaca.');
    }
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        throw const PlantApiException('API key tidak valid.');
      }
      if (response.statusCode == 429) {
        throw const PlantApiException('Kuota API habis atau permintaan terlalu cepat.');
      }
      throw PlantApiException((data['error'] ?? 'HTTP ${response.statusCode}').toString());
    }
    return data;
  }

  static void _ensureConfigured() {
    if (!isConfigured) {
      throw const PlantApiException(
        'API belum dikonfigurasi. Gunakan --dart-define=WHATS_MY_ZONE_API_KEY=KUNCI_API.',
      );
    }
  }
}

class PlantApiException implements Exception {
  final String message;
  const PlantApiException(this.message);
  @override
  String toString() => message;
}
