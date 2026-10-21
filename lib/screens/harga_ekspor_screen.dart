import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/harga_ekspor_service.dart';

class HargaEksporScreen extends StatefulWidget {
  const HargaEksporScreen({super.key});

  @override
  State<HargaEksporScreen> createState() => _HargaEksporScreenState();
}

class _HargaEksporScreenState extends State<HargaEksporScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<CommodityPrice> _allCommodities = <CommodityPrice>[];
  CommodityPrice? _selectedCommodity;
  ExchangeRates? _rates;

  bool _loading = false;
  bool _ratesLoading = false;
  String? _errorMessage;
  String? _ratesError;
  String _query = '';

  late Timer _timer;
  DateTime _utcNow = DateTime.now().toUtc();

  List<CommodityPrice> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return <CommodityPrice>[];
    return _allCommodities
        .where((item) => item.name.toLowerCase().contains(query))
        .take(8)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPrices();
    _loadRates();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _utcNow = DateTime.now().toUtc());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPrices() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final prices = await HargaEksporService.fetchPrices();
      if (!mounted) return;
      setState(() {
        _allCommodities = prices;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadRates() async {
    setState(() {
      _ratesLoading = true;
      _ratesError = null;
    });

    try {
      final rates = await HargaEksporService.fetchRates();
      if (!mounted) return;
      setState(() {
        _rates = rates;
        _ratesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ratesError = _friendlyError(error);
        _ratesLoading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _selectCommodity(CommodityPrice item) {
    setState(() {
      _selectedCommodity = item;
      _query = item.name;
      _searchController.text = item.name;
    });
    _searchFocus.unfocus();
  }

  void _submitSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _selectedCommodity = null;
      });
      return;
    }

    final matches = _allCommodities
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();

    setState(() {
      _query = _searchController.text.trim();
      _selectedCommodity = matches.isEmpty ? null : matches.first;
    });

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Komoditas tidak ditemukan di data Kemendag. '
            'Coba kata kunci yang lebih singkat.',
          ),
        ),
      );
    } else {
      _searchFocus.unfocus();
    }
  }

  String _formatNumber(num value, {int decimals = 2}) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final integer = parts.first;
    final out = StringBuffer();

    for (var i = 0; i < integer.length; i++) {
      if (i > 0 && (integer.length - i) % 3 == 0) out.write('.');
      out.write(integer[i]);
    }

    if (decimals > 0) {
      out.write(',');
      out.write(parts.length > 1 ? parts[1] : ''.padRight(decimals, '0'));
    }
    return out.toString();
  }

  String _formatUsd(num value) => '\$ ${_formatNumber(value)}';
  String _formatEur(num value) => '€ ${_formatNumber(value)}';
  String _formatIdr(num value) => 'Rp ${_formatNumber(value, decimals: 0)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commodity = _selectedCommodity;
    final rates = _rates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Harga Pasar Ekspor'),
        actions: [
          IconButton(
            tooltip: 'Perbarui data',
            onPressed: _loading || _ratesLoading
                ? null
                : () {
                    _loadPrices();
                    _loadRates();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait<void>([
              _loadPrices(),
              _loadRates(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Cari komoditas pangan',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (_) => _submitSearch(),
                decoration: InputDecoration(
                  hintText: 'Contoh: kopi, cocoa, sugar...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Cari',
                    onPressed: _submitSearch,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              if (_query.trim().isNotEmpty && _searchFocus.hasFocus)
                _buildSuggestions(),
              const SizedBox(height: 16),
              if (_loading && _allCommodities.isEmpty)
                const _InfoCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: Text('Mengambil data harga dari Kemendag...')),
                    ],
                  ),
                ),
              if (_errorMessage != null && _allCommodities.isEmpty)
                _ErrorCard(
                  message: _errorMessage!,
                  onRetry: _loadPrices,
                ),
              if (!_loading && _errorMessage == null && _allCommodities.isNotEmpty)
                _InfoCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data harga berkala dari Kemendag. '
                          'Pilih komoditas dari hasil pencarian untuk melihat '
                          'periode terbaru yang tersedia. Harga ditampilkan per kg.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              if (commodity != null) ...[
                const SizedBox(height: 12),
                _buildPriceCard(commodity, theme),
                const SizedBox(height: 12),
                _buildCurrencyCard(commodity, rates, theme),
              ] else if (_query.trim().isNotEmpty &&
                  !_loading &&
                  _errorMessage == null) ...[
                const SizedBox(height: 8),
                const _InfoCard(
                  child: Text(
                    'Pilih komoditas dari saran pencarian, atau tekan tombol '
                    'cari. Harga hanya ditampilkan jika tersedia di sumber.',
                  ),
                ),
              ] else if (_selectedCommodity == null) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  child: Text(
                    _allCommodities.isEmpty
                        ? 'Data komoditas belum tersedia.'
                        : 'Ketik nama komoditas di atas untuk memulai pencarian. '
                            '${_allCommodities.length} nama komoditas terbaca dari sumber.',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildLondonClock(theme),
              const SizedBox(height: 20),
              Text(
                'Sumber: Satu Data Kemendag untuk harga komoditas; '
                'Frankfurter API untuk kurs.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    final matches = _matches;

    if (_query.trim().isEmpty) return const SizedBox.shrink();

    if (_loading && _allCommodities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Belum ada nama komoditas yang cocok.'),
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final item in matches)
            ListTile(
              dense: true,
              leading: const Icon(Icons.grass_outlined),
              title: Text(item.name),
              subtitle: Text('Periode terbaru: ${item.period}'),
              onTap: () => _selectCommodity(item),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(CommodityPrice item, ThemeData theme) {
    final values = item.historyUsdPerKg;
    final previous = values.length >= 2 ? values[values.length - 2] : null;
    final changePct = previous == null || previous == 0
        ? null
        : ((item.usdPerKg - previous) / previous) * 100;
    final isUp = changePct != null && changePct >= 0;
    final color = changePct == null
        ? theme.colorScheme.primary
        : isUp
            ? Colors.green.shade700
            : Colors.red.shade700;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Satuan harga: ${item.unit} · Periode: ${item.period}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${_formatUsd(item.usdPerKg)} / kg',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (changePct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${isUp ? '+' : ''}${changePct.toStringAsFixed(1).replaceAll('.', ',')}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _PriceChartPainter(
                  values,
                  color,
                  theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.historyPeriods.isNotEmpty
                      ? item.historyPeriods.first
                      : 'Awal data',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  item.period,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            if (values.length < 2) ...[
              const SizedBox(height: 8),
              Text(
                'Belum ada dua periode data untuk menghitung perubahan harga.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyCard(
    CommodityPrice item,
    ExchangeRates? rates,
    ThemeData theme,
  ) {
    final usd = item.usdPerKg;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Konversi mata uang per kg',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.currency_exchange),
              ],
            ),
            const SizedBox(height: 12),
            _CurrencyRow(code: 'USD', label: 'Dolar AS', value: _formatUsd(usd)),
            const Divider(height: 20),
            _CurrencyRow(
              code: 'EUR',
              label: 'Euro',
              value: rates == null
                  ? (_ratesLoading ? 'Memuat...' : 'Tidak tersedia')
                  : _formatEur(usd * rates.eurPerUsd),
            ),
            const Divider(height: 20),
            _CurrencyRow(
              code: 'IDR',
              label: 'Rupiah',
              value: rates == null
                  ? (_ratesLoading ? 'Memuat...' : 'Tidak tersedia')
                  : _formatIdr(usd * rates.idrPerUsd),
            ),
            const SizedBox(height: 8),
            if (rates != null)
              Text(
                'Tanggal kurs: ${rates.date}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (_ratesError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kurs gagal dimuat: $_ratesError',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadRates,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLondonClock(ThemeData theme) {
    final bst = _isBritishSummerTime(_utcNow);
    final london = _utcNow.add(Duration(hours: bst ? 1 : 0));
    final wib = _utcNow.add(const Duration(hours: 7));
    final wita = _utcNow.add(const Duration(hours: 8));
    final wit = _utcNow.add(const Duration(hours: 9));

    final londonMinutes = london.hour * 60 + london.minute;
    const openMinutes = 8 * 60;
    const closeMinutes = 16 * 60 + 30;
    final weekday = london.weekday >= DateTime.monday &&
        london.weekday <= DateTime.friday;
    final open = weekday &&
        londonMinutes >= openMinutes &&
        londonMinutes < closeMinutes;

    final timeZone = bst ? 'BST (UTC+1)' : 'GMT (UTC+0)';

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: TextStyle(color: theme.colorScheme.onPrimary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Jam bursa London',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: open ? Colors.green.shade700 : Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(timeZone, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ClockTile(label: 'London', time: _hm(london)),
                  const SizedBox(width: 7),
                  _ClockTile(label: 'WIB', time: _hm(wib)),
                  const SizedBox(width: 7),
                  _ClockTile(label: 'WITA', time: _hm(wita)),
                  const SizedBox(width: 7),
                  _ClockTile(label: 'WIT', time: _hm(wit)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '*Indikator jadwal umum 08.00–16.30 waktu London, '
                'Senin–Jumat. Ini bukan konfirmasi status bursa tertentu '
                'atau hari libur pasar.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hm(DateTime dateTime) =>
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';

  bool _isBritishSummerTime(DateTime utc) {
    // BST dimulai Minggu terakhir Maret pukul 01.00 UTC dan
    // berakhir Minggu terakhir Oktober pukul 01.00 UTC.
    final start = _lastSundayUtc(utc.year, 3).add(const Duration(hours: 1));
    final end = _lastSundayUtc(utc.year, 10).add(const Duration(hours: 1));
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  DateTime _lastSundayUtc(int year, int month) {
    var day = DateTime.utc(year, month + 1, 0);
    while (day.weekday != DateTime.sunday) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data harga gagal dimuat',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.code,
    required this.label,
    required this.value,
  });

  final String code;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            code,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ClockTile extends StatelessWidget {
  const _ClockTile({required this.label, required this.time});

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(28),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                time,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  _PriceChartPainter(this.values, this.lineColor, this.gridColor);

  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length < 2) return;

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue == 0 ? 1.0 : maxValue - minValue;
    const pad = 8.0;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          pad +
              (size.height - pad * 2) *
                  (1 - (values[i] - minValue) / range),
        ),
    ];

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withAlpha(55),
            lineColor.withAlpha(0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(points.last, 4, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter oldDelegate) {
    return !listEquals(oldDelegate.values, values) ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
