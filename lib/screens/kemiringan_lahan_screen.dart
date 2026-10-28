import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../utils/constants.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common.dart';

class KemiringanLahanScreen extends StatefulWidget {
  const KemiringanLahanScreen({super.key});

  @override
  State<KemiringanLahanScreen> createState() => _KemiringanLahanScreenState();
}

class _KemiringanLahanScreenState extends State<KemiringanLahanScreen> {
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  double _pitch = 5.1; // Derajat Pitch (X-axis)
  double _roll = 6.7; // Derajat Roll (Y-axis)
  double _slopeDegree = 8.4;
  double _slopePercent = 14.8;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _startListeningSensors();
  }

  void _startListeningSensors() {
    _accelSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        if (_isLocked || !mounted) return;

        setState(() {
          // Menghitung Pitch & Roll dari accelerometer (dalam derajat).
          _pitch = (atan2(
                    event.x,
                    sqrt(event.y * event.y + event.z * event.z),
                  ) *
                  180 /
                  pi)
              .abs();

          _roll = (atan2(
                    event.y,
                    sqrt(event.x * event.x + event.z * event.z),
                  ) *
                  180 /
                  pi)
              .abs();

          // Menghitung besar kemiringan terukur dari Pitch dan Roll.
          _slopeDegree = sqrt(_pitch * _pitch + _roll * _roll);

          // Mengonversi derajat menjadi persentase kemiringan lahan.
          _slopePercent = tan(_slopeDegree * pi / 180) * 100;
        });
      },
    );
  }

  String get _topographyCategory {
    if (_slopePercent < 8) return 'Datar';
    if (_slopePercent <= 15) return 'Landai';
    if (_slopePercent <= 25) return 'Agak Curam';
    return 'Curam';
  }

  // Warna solid kategori mengikuti warna indikator di bawahnya.
  Color get _topographyColor {
    switch (_topographyCategory) {
      case 'Datar':
        return Colors.green.shade600;
      case 'Landai':
        return Colors.amber.shade700;
      case 'Agak Curam':
        return Colors.orange.shade700;
      case 'Curam':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  Color get _topographyTextColor {
    // Teks hitam pada badge kuning agar tetap terbaca.
    return _topographyCategory == 'Landai' ? Colors.black : Colors.white;
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Kemiringan Lahan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Target visualisasi waterpass.
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 24,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CustomPaint(
                      painter: _WaterpassTargetPainter(
                        pitch: _pitch,
                        roll: _roll,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kemiringan terukur',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_slopeDegree.toStringAsFixed(1)}° = '
                    '${_slopePercent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E5B3E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Kartu metrik Pitch, Roll, dan status sensor.
            Row(
              children: [
                _buildMetricCard('Pitch', '${_pitch.toStringAsFixed(1)}°'),
                const SizedBox(width: 8),
                _buildMetricCard('Roll', '${_roll.toStringAsFixed(1)}°'),
                const SizedBox(width: 8),
                _buildMetricCard('Gyroscope', 'Aktif', isBadge: true),
              ],
            ),
            const SizedBox(height: 14),

            // Kategori topografi lahan.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kategori topografi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _topographyColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _topographyCategory,
                          style: TextStyle(
                            fontSize: 11,
                            color: _topographyTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Indikator bar dengan warna solid yang sama dengan badge.
                  Row(
                    children: [
                      _buildRangeBar(
                        Colors.green.shade600,
                        'Datar <8%',
                        _topographyCategory == 'Datar',
                      ),
                      const SizedBox(width: 4),
                      _buildRangeBar(
                        Colors.amber.shade700,
                        'Landai 8–15%',
                        _topographyCategory == 'Landai',
                      ),
                      const SizedBox(width: 4),
                      _buildRangeBar(
                        Colors.orange.shade700,
                        'Agak curam',
                        _topographyCategory == 'Agak Curam',
                      ),
                      const SizedBox(width: 4),
                      _buildRangeBar(
                        Colors.red.shade600,
                        'Curam',
                        _topographyCategory == 'Curam',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lahan masih layak ditanami. Buat bedengan searah kontur '
                    'untuk mengurangi erosi.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tombol untuk mengunci atau membuka hasil sensor.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _isLocked = !_isLocked);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: Color(0xFF1E5B3E)),
                    ),
                    child: Text(
                      _isLocked ? 'Buka kunci' : 'Kunci hasil',
                      style: const TextStyle(
                        color: Color(0xFF1E5B3E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String val, {
    bool isBadge = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              val,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isBadge ? AppColors.green : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeBar(Color color, String label, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: isActive
                  ? Border.all(color: Colors.black, width: 1.5)
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.black : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter target waterpass (bullseye).
class _WaterpassTargetPainter extends CustomPainter {
  final double pitch;
  final double roll;

  _WaterpassTargetPainter({required this.pitch, required this.roll});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Latar belakang lingkaran hijau muda.
    final bgPaint = Paint()..color = const Color(0xFFE5EFE6);
    canvas.drawCircle(center, radius, bgPaint);

    // Garis target konsentris.
    final linePaint = Paint()
      ..color = const Color(0xFF1E5B3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, linePaint);
    canvas.drawCircle(center, radius * 0.65, linePaint);
    canvas.drawCircle(center, radius * 0.35, linePaint);
    canvas.drawCircle(center, radius * 0.12, linePaint);

    // Crosshair atau garis silang.
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );

    // Bola gelembung air merespons nilai pitch dan roll.
    final bubbleOffsetX = (pitch * 3.0).clamp(-radius * 0.7, radius * 0.7);
    final bubbleOffsetY = (roll * 3.0).clamp(-radius * 0.7, radius * 0.7);
    final bubbleCenter = Offset(
      center.dx + bubbleOffsetX,
      center.dy + bubbleOffsetY,
    );

    final bubblePaint = Paint()..color = const Color(0xFFD98E32);
    canvas.drawCircle(bubbleCenter, 14, bubblePaint);

    final bubbleBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(bubbleCenter, 14, bubbleBorder);
  }

  @override
  bool shouldRepaint(covariant _WaterpassTargetPainter oldDelegate) {
    return oldDelegate.pitch != pitch || oldDelegate.roll != roll;
  }
}
