import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common.dart';

class _Commodity {
  const _Commodity(this.name, this.market, this.usdPerTon, this.changePct,
      this.series);

  final String name;
  final String market;
  final double usdPerTon;
  final double changePct;
  final List<double> series;
}

// Data contoh (dummy). Ganti dengan data API harga komoditas yang asli.
const _commodities = <_Commodity>[
  _Commodity('Kopi', 'Kopi Robusta, bursa London', 4120, 1.8,
      <double>[3900, 3950, 3920, 4010, 3990, 4060, 4120]),
  _Commodity('Kakao', 'Kakao, bursa London', 8450, -0.6,
      <double>[8620, 8580, 8610, 8540, 8500, 8490, 8450]),
  _Commodity('Gula', 'Gula putih, bursa London', 540, 0.4,
      <double>[532, 535, 531, 536, 538, 537, 540]),
  _Commodity('Lada', 'Lada hitam, pasar ekspor', 6900, 2.1,
      <double>[6620, 6680, 6700, 6760, 6810, 6850, 6900]),
];

const _eurPerUsd = 0.92;
const _idrPerUsd = 16240;

String _fmtInt(num v) {
  final s = v.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

DateTime _lastSunday(int year, int month) {
  var d = DateTime.utc(year, month + 1, 0);
  while (d.weekday != DateTime.sunday) {
    d = d.subtract(const Duration(days: 1));
  }
  return d;
}

bool _isBst(DateTime utc) {
  final start = _lastSunday(utc.year, 3).add(const Duration(hours: 1));
  final end = _lastSunday(utc.year, 10).add(const Duration(hours: 1));
  return !utc.isBefore(start) && utc.isBefore(end);
}

String _hm(int minutes) {
  final m = ((minutes % 1440) + 1440) % 1440;
  final hh = (m ~/ 60).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$hh.$mm';
}

class HargaEksporScreen extends StatefulWidget {
  const HargaEksporScreen({super.key});

  @override
  State<HargaEksporScreen> createState() => _HargaEksporScreenState();
}

class _HargaEksporScreenState extends State<HargaEksporScreen> {
  int _selected = 0;
  late Timer _timer;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _commodities[_selected];
    final up = c.changePct >= 0;
    final changeText =
        '${up ? '+' : '-'}${c.changePct.abs().toStringAsFixed(1).replaceAll('.', ',')}%';
    final eur = c.usdPerTon * _eurPerUsd;
    final idrJuta = c.usdPerTon * _idrPerUsd / 1e6;

    return SubPageScaffold(
      title: 'Harga Pasar Ekspor',
      children: [
        PillChips(
          labels: [for (final x in _commodities) x.name],
          onChanged: (i) => setState(() => _selected = i),
        ),
        const SizedBox(height: 12),

        // Grafik
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.market,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'US\$ ${_fmtInt(c.usdPerTon)}',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('per ton',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.muted)),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: up ? AppColors.upSoft : AppColors.downSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      changeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: up ? AppColors.up : AppColors.down,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LineChartPainter(
                    c.series,
                    up ? AppColors.green : AppColors.down,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('7 hari lalu',
                      style: TextStyle(fontSize: 9, color: AppColors.muted)),
                  Text('Hari ini',
                      style: TextStyle(fontSize: 9, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Konversi mata uang
        AppCard(
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text('Konversi mata uang',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  Text('Per ton',
                      style: TextStyle(fontSize: 10, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 10),
              _CurrencyRow('USD', 'Dolar AS', '\$ ${_fmtInt(c.usdPerTon)}'),
              const Divider(height: 16, color: AppColors.border),
              _CurrencyRow('EUR', 'Euro', '€ ${_fmtInt(eur)}'),
              const Divider(height: 16, color: AppColors.border),
              _CurrencyRow('IDR', 'Rupiah',
                  'Rp ${idrJuta.toStringAsFixed(1).replaceAll('.', ',')} juta'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _LondonClockCard(now: _now),
      ],
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow(this.code, this.name, this.value);

  final String code;
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(code,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
        ),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _LondonClockCard extends StatelessWidget {
  const _LondonClockCard({required this.now});

  /// Waktu sekarang dalam UTC.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bst = _isBst(now);
    final londonOffset = bst ? 1 : 0;
    final london = now.add(Duration(hours: londonOffset));
    final wib = now.add(const Duration(hours: 7));
    final wita = now.add(const Duration(hours: 8));
    final wit = now.add(const Duration(hours: 9));

    int mins(DateTime d) => d.hour * 60 + d.minute;

    const openLondon = 8 * 60; // 08.00
    const closeLondon = 16 * 60 + 30; // 16.30
    final isWeekday = london.weekday >= DateTime.monday &&
        london.weekday <= DateTime.friday;
    final isOpen =
        isWeekday && mins(london) >= openLondon && mins(london) < closeLondon;

    final shiftToWib = 7 - londonOffset;
    final openWib = openLondon + shiftToWib * 60;
    final closeWib = closeLondon + shiftToWib * 60;

    final badge = isOpen ? 'Buka sekarang' : 'Tutup, buka ${_hm(openWib)} WIB';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Jam bursa London',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOpen ? AppColors.up : AppColors.greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ClockTile('London', _hm(mins(london))),
              const SizedBox(width: 8),
              _ClockTile('WIB', _hm(mins(wib))),
              const SizedBox(width: 8),
              _ClockTile('WITA', _hm(mins(wita))),
              const SizedBox(width: 8),
              _ClockTile('WIT', _hm(mins(wit))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Perdagangan ${_hm(openLondon)} sampai ${_hm(closeLondon)} London, '
            'sama dengan ${_hm(openWib)} sampai ${_hm(closeWib)} WIB, '
            '${_hm(openWib + 60)} sampai ${_hm(closeWib + 60)} WITA, '
            'dan ${_hm(openWib + 120)} sampai ${_hm(closeWib + 120)} WIT.',
            style: const TextStyle(
                fontSize: 10, height: 1.4, color: Color(0xFFD5E4DA)),
          ),
        ],
      ),
    );
  }
}

class _ClockTile extends StatelessWidget {
  const _ClockTile(this.label, this.time);

  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: Color(0xFFC9DCCF))),
            const SizedBox(height: 2),
            Text(time,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.data, this.color);

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    // Garis bantu
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final minV = data.reduce((a, b) => a < b ? a : b);
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1 : (maxV - minV);
    const pad = 8.0;

    final points = <Offset>[
      for (var i = 0; i < data.length; i++)
        Offset(
          size.width * i / (data.length - 1),
          pad + (size.height - pad * 2) * (1 - (data[i] - minV) / range),
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha(60),
            color.withAlpha(0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(points.last, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(points.last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.data != data || old.color != color;
}
