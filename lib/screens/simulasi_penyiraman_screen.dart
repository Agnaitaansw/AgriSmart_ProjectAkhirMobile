import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/constants.dart';
import '../widgets/auth_widgets.dart';

import '../widgets/common.dart';

class SimulasiPenyiramanScreen extends StatefulWidget {
  const SimulasiPenyiramanScreen({super.key});

  @override
  State<SimulasiPenyiramanScreen> createState() =>
      _SimulasiPenyiramanScreenState();
}

class _SimulasiPenyiramanScreenState extends State<SimulasiPenyiramanScreen> {
  // Logic Sensor
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  double _x = 0.0, _y = 0.0, _z = 0.0;

  // Game Logic State
  int _secondsLeft = 24;
  int _score = 120;
  double _waterProgress = 0.55; // 55%
  final double _targetProgress = 0.80; // 80%
  bool _isWatering = false;
  Timer? _gameTimer;

  @override
  void initState() {
    super.initState();
    _startListeningSensors();
    _startTimer();
  }

  void _startListeningSensors() {
    _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!mounted) return;
      setState(() {
        _x = event.x;
        _y = event.y;
        _z = event.z;

        // Jika HP dimiringkan ke kanan (nilai X > 2.5), air mengucur
        if (_x > 2.5) {
          _isWatering = true;
          if (_waterProgress < 1.0) {
            _waterProgress += 0.003;
            _score += 1;
          }
        } else {
          _isWatering = false;
        }
      });
    });
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _gameTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Simulasi Penyiraman',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Row Stats Card (Waktu, Skor, Target)
            Row(
              children: [
                _buildStatHeaderCard('Waktu', '00:${_secondsLeft.toString().padLeft(2, '0')}'),
                const SizedBox(width: 8),
                _buildStatHeaderCard('Skor', '$_score'),
                const SizedBox(width: 8),
                _buildStatHeaderCard('Target', '${(_targetProgress * 100).toInt()}%'),
              ],
            ),
            const SizedBox(height: 16),

            // Arena Game (Visualisasi Penyiraman)
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFFE5EFE6), // Green Soft
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Tag Petak
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Cabai rawit, Petak A',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Visualisasi Teko Penyiram & Tanaman
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Teko air (Miring saat disiram)
                        Transform.rotate(
                          angle: _isWatering ? -0.4 : 0.0,
                          child: Icon(
                            Icons.water_drop,
                            size: 80,
                            color: _isWatering ? Colors.blue : const Color(0xFF1E5B3E),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tanaman
                        const Icon(
                          Icons.local_florist,
                          size: 90,
                          color: Color(0xFF1E5B3E),
                        ),
                      ],
                    ),
                  ),

                  // Indikator Level Air (Samping Kanan)
                  Positioned(
                    right: 16,
                    top: 40,
                    bottom: 70,
                    child: Container(
                      width: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Batas Target Dashed
                          Positioned(
                            bottom: 220 * _targetProgress,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              color: Colors.black54,
                            ),
                          ),
                          // Progress Air
                          FractionallySizedBox(
                            heightFactor: _waterProgress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating Banner Bawah Game
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E5B3E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isWatering ? 'Sedang Menyiram... 💦' : 'Miringkan ponsel ke kanan untuk menyiram',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card Sensor Accelerometer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sensor accelerometer',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Aktif',
                          style: TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildSensorValueBox('X', _x.toStringAsFixed(1)),
                      const SizedBox(width: 8),
                      _buildSensorValueBox('Y', _y.toStringAsFixed(1)),
                      const SizedBox(width: 8),
                      _buildSensorValueBox('Z', _z.toStringAsFixed(1)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatHeaderCard(String label, String value) {
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
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorValueBox(String axis, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(axis, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}