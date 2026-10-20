import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// Satu harga komoditas per kilogram, berdasarkan periode terbaru
/// yang tersedia pada tabel sumber.
class CommodityPrice {
  const CommodityPrice({
    required this.name,
    required this.unit,
    required this.usdPerKg,
    required this.period,
    required this.historyUsdPerKg,
    required this.historyPeriods,
  });

  final String name;
  final String unit;
  final double usdPerKg;
  final String period;
  final List<double> historyUsdPerKg;
  final List<String> historyPeriods;
}

class ExchangeRates {
  const ExchangeRates({
    required this.eurPerUsd,
    required this.idrPerUsd,
    required this.date,
  });

  /// Jumlah EUR untuk 1 USD.
  final double eurPerUsd;

  /// Jumlah IDR untuk 1 USD.
  final double idrPerUsd;

  final String date;
}

class HargaEksporService {
  HargaEksporService._();

  static const String _kemendagUrl =
      'https://satudata.kemendag.go.id/data-informasi/'
      'perdagangan-luar-negeri/harga-internasional';

  static const String _ratesUrl =
      'https://api.frankfurter.dev/v1/latest?base=USD&symbols=EUR,IDR';

  static const List<String> _months = <String>[
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static Future<List<CommodityPrice>> fetchPrices() async {
    final response = await http
        .get(
          Uri.parse(_kemendagUrl),
          headers: const {
            'Accept': 'text/html,application/xhtml+xml',
            'User-Agent': 'Mozilla/5.0 FlutterApp',
          },
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception(
        'Situs Kemendag mengembalikan HTTP ${response.statusCode}.',
      );
    }

    final document = html_parser.parse(response.body);
    final rows = document.querySelectorAll('table tr');
    final results = <CommodityPrice>[];

    for (final row in rows) {
      final cells = row.querySelectorAll('th, td');
      if (cells.length < 4) continue;

      final name = cells[0].text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final unit = cells[1].text
          .replaceAll('\u00A0', '')
          .replaceAll(' ', '')
          .trim()
          .toLowerCase();

      // Harga dikembalikan dalam USD/kg. Data $/mt dibagi 1000.
      final isUsdPerKg = unit == r'$/kg' || unit == r'us$/kg';
      final isUsdPerMetricTon =
          unit == r'$/mt' || unit == r'us$/mt' ||
          unit == r'$/ton' || unit == r'us$/ton';

      if (name.isEmpty || (!isUsdPerKg && !isUsdPerMetricTon)) {
        continue;
      }

      final values = <double>[];
      final periods = <String>[];

      // Kolom setelah nama dan satuan dianggap sebagai Jan–Des.
      // Jika struktur tabel berubah, pengecekan hasil kosong akan
      // memunculkan pesan error alih-alih menampilkan angka dummy.
      for (var i = 2; i < cells.length && i < 14; i++) {
        final raw = cells[i].text
            .replaceAll('\u00A0', '')
            .replaceAll(',', '')
            .trim();

        final parsed = double.tryParse(raw);
        if (parsed == null || !parsed.isFinite || parsed <= 0) continue;

        final usdPerKg = isUsdPerMetricTon ? parsed / 1000.0 : parsed;
        values.add(usdPerKg);
        periods.add(_months[i - 2]);
      }

      if (values.isEmpty) continue;

      results.add(
        CommodityPrice(
          name: name,
          unit: 'USD/kg',
          usdPerKg: values.last,
          period: periods.last,
          historyUsdPerKg: List<double>.unmodifiable(values),
          historyPeriods: List<String>.unmodifiable(periods),
        ),
      );
    }

    if (results.isEmpty) {
      throw Exception(
        'Data harga tidak berhasil dibaca dari tabel Kemendag. '
        'Struktur situs mungkin berubah atau tabel dimuat dengan JavaScript.',
      );
    }

    // Hilangkan duplikat nama komoditas jika tabel memuat lebih dari satu
    // baris dengan nama sama; pertahankan baris pertama yang ditemukan.
    final unique = <String, CommodityPrice>{};
    for (final item in results) {
      unique.putIfAbsent(item.name.toLowerCase(), () => item);
    }

    return List<CommodityPrice>.unmodifiable(unique.values);
  }

  static Future<ExchangeRates> fetchRates() async {
    final response = await http
        .get(
          Uri.parse(_ratesUrl),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Sumber kurs mengembalikan HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['rates'] is! Map<String, dynamic>) {
      throw Exception('Format data kurs tidak sesuai.');
    }

    final rates = decoded['rates'] as Map<String, dynamic>;
    final eur = rates['EUR'];
    final idr = rates['IDR'];
    final date = decoded['date'];

    if (eur is! num || idr is! num || date is! String) {
      throw Exception('Data EUR/IDR tidak lengkap dari sumber kurs.');
    }

    return ExchangeRates(
      eurPerUsd: eur.toDouble(),
      idrPerUsd: idr.toDouble(),
      date: date,
    );
  }

  static Future<({List<CommodityPrice> prices, ExchangeRates rates})>
      fetchAll() async {
    final results = await Future.wait<Object>([
      fetchPrices(),
      fetchRates(),
    ]);

    return (
      prices: results[0] as List<CommodityPrice>,
      rates: results[1] as ExchangeRates,
    );
  }
}
