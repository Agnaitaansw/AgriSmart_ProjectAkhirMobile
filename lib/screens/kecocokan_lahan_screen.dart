import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

// Model untuk menampung data rekomendasi tanaman
class CropRecommendation {
  final String name;
  final int percent;
  final String note;
  final Color color;
  final bool highlighted;

  const CropRecommendation({
    required this.name,
    required this.percent,
    required this.note,
    required this.color,
    this.highlighted = false,
  });
}

class KecocokanLahanScreen extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const KecocokanLahanScreen({
    super.key,
    this.latitude,
    this.longitude,
  });

  @override
  State<KecocokanLahanScreen> createState() => _KecocokanLahanScreenState();
}

class _KecocokanLahanScreenState extends State<KecocokanLahanScreen> {
  double _lat = -7.7956;
  double _lng = 110.3695;
  double _alt = 118.0; // Altitude dalam mdpl
  bool _isLoading = true;
  String _zoneName = 'Dataran Rendah';

  List<CropRecommendation> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _initLocationAndAnalysis();
  }

  Future<void> _initLocationAndAnalysis() async {
    // 1. Jika koordinat dikirim dari Beranda
    if (widget.latitude != null && widget.longitude != null) {
      _lat = widget.latitude!;
      _lng = widget.longitude!;
    }

    try {
      // 2. Ambil data posisi lengkap (termasuk altitude/ketinggian)
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          // Menggunakan altitude dari sensor GPS perangkat
          _alt = pos.altitude > 0 ? pos.altitude : 118.0;
        });
      }
    } catch (_) {
      // Menggunakan nilai fallback jika GPS timeout / off
    }

    _analyzeLandMatch();
  }

  // LOGIC INTI: Analisis Kategori Lahan Berdasarkan Ketinggian (mdpl)
  void _analyzeLandMatch() {
    List<CropRecommendation> list = [];

    if (_alt < 25) {
      // ZONA PESISIR
      _zoneName = 'Pesisir / Pantai (< 25 mdpl)';
      list = const [
        CropRecommendation(
          name: 'Kelapa Dalam / Genjah',
          percent: 95,
          note: 'Toleran terhadap kadar garam tinggi dan angin kencang',
          color: AppColors.green,
          highlighted: true,
        ),
        CropRecommendation(
          name: 'Semangka',
          percent: 88,
          note: 'Suhu hangat pesisir sangat mendukung pembentukan gula',
          color: AppColors.up,
        ),
        CropRecommendation(
          name: 'Melon',
          percent: 79,
          note: 'Butuh intensitas cahaya matahari penuh sepanjang hari',
          color: AppColors.amber,
        ),
        CropRecommendation(
          name: 'Bawang Merah',
          percent: 93,
          note:
              'Angin pantai dan sinar matahari penuh sangat efektif menekan pertumbuhan jamur pada daun',
          color: AppColors.green,
          highlighted: true,
        ),
        CropRecommendation(
          name: 'Buah Naga',
          percent: 86,
          note:
              'Kaktus tropis yang menyukai iklim panas terik dan tanah pasir agar akar tidak mudah busuk',
          color: AppColors.up,
        ),
      ];
    } else if (_alt <= 400) {
      // ZONA DATARAN RENDAH
      _zoneName = 'Dataran Rendah (25 - 400 mdpl)';
      list = const [
        CropRecommendation(
          name: 'Cabai rawit',
          percent: 92,
          note: 'Suhu ideal 25-30°C, tanah lempung berpasir gembur',
          color: AppColors.green,
          highlighted: true,
        ),
        CropRecommendation(
          name: 'Padi sawah',
          percent: 85,
          note: 'Pasokan air irigasi mencukupi, tanah aluvial/grumosol',
          color: AppColors.up,
        ),
        CropRecommendation(
          name: 'Jagung hibrida',
          percent: 74,
          note: 'Kelembapan tanah sedang, aerasi tanah berjalan baik',
          color: AppColors.amber,
        ),
        CropRecommendation(
          name: 'Tomat Sayur',
          percent: 90,
          note:
              'Suhu hangat 24-28°C mempercepat proses pembungaan dan pematangan buah varietas hibrida',
          color: AppColors.green,
          highlighted: true,
        ),
        CropRecommendation(
          name: 'Kacang Tanah',
          percent: 84,
          note:
              'Tanah lempung berpasir sangat memudahkan ginofor (calon buah) menembus tanah',
          color: AppColors.up,
        ),
      ];
    } else {
      // ZONA DATARAN TINGGI
      _zoneName = 'Dataran Tinggi (> 400 mdpl)';
      list = const [
        CropRecommendation(
          name: 'Kopi Arabika / Teh',
          percent: 96,
          note: 'Suhu sejuk 15-22°C sangat cocok untuk cita rasa optimal',
          color: AppColors.green,
          highlighted: true,
        ),
        CropRecommendation(
          name: 'Kentang',
          percent: 89,
          note:
              'Ketinggian ideal memperkecil risiko hama penyakit dataran rendah',
          color: AppColors.up,
        ),
        CropRecommendation(
          name: 'Wortel & Kubis',
          percent: 81,
          note: 'Suhu dingin mendukung pembesaran umbi dan pembentukan krop',
          color: AppColors.amber,
        ),
        CropRecommendation(
          name: 'Stroberi',
          percent: 95,
          note:
              'Penurunan suhu drastis di malam hari (suhu dingin) sangat wajib untuk merangsang pembungaan',
          color: AppColors.green,
          highlighted: true,
        ),
        CropRecommendation(
          name: 'Kubis (Kol)',
          percent: 88,
          note:
              'Udara sejuk dataran tinggi membuat krop (bulatan daun) terbentuk sangat padat dan tidak mudah pecah',
          color: AppColors.up,
        ),
      ];
    }

    if (mounted) {
      setState(() {
        _recommendations = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Kecocokan Lahan',
      children: [
        // Visualisasi Peta LBS
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 210,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MapPainter())),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Radius analisis 2 km',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Widget Informasi Koordinat & Ketinggian
        AppCard(
          child: Row(
            children: [
              _Stat('Latitude', _lat.toStringAsFixed(4)),
              _Stat('Longitude', _lng.toStringAsFixed(4)),
              _Stat('Ketinggian', '${_alt.toStringAsFixed(0)} mdpl'),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() => _isLoading = true);
                  _initLocationAndAnalysis();
                },
                child: const IconBox(
                  icon: Icons.my_location,
                  size: 36,
                  radius: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tag Kategori Zona Lahan
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.terrain, size: 18, color: AppColors.green),
              const SizedBox(width: 8),
              Text(
                'Zona Terdeteksi: $_zoneName',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'Rekomendasi tanaman untuk lahan ini',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),

        // Indikator Loading / Daftar Rekomendasi
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ..._recommendations.map(
            (crop) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CropMatchCard(
                name: crop.name,
                percent: crop.percent,
                note: crop.note,
                color: crop.color,
                highlighted: crop.highlighted,
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CropMatchCard extends StatelessWidget {
  const _CropMatchCard({
    required this.name,
    required this.percent,
    required this.note,
    required this.color,
    this.highlighted = false,
  });

  final String name;
  final int percent;
  final String note;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: highlighted ? AppColors.green : AppColors.border,
      borderWidth: highlighted ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text(
                '$percent% cocok',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: AppColors.greenSoft,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(note,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFE9ECDF));

    final block = Paint()..color = const Color(0xFFD7E2C6);
    void rect(double l, double t, double r, double b) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * l, h * t, w * r, h * b),
          const Radius.circular(8),
        ),
        block,
      );
    }

    rect(0.04, 0.10, 0.30, 0.42);
    rect(0.70, 0.08, 0.96, 0.36);
    rect(0.06, 0.62, 0.34, 0.92);
    rect(0.66, 0.60, 0.94, 0.90);

    final river = Path()
      ..moveTo(0, h * 0.78)
      ..cubicTo(w * 0.25, h * 0.55, w * 0.55, h * 0.95, w, h * 0.62);
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFFCBE1EA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * 0.50), Offset(w, h * 0.46), road);
    canvas.drawLine(Offset(w * 0.38, 0), Offset(w * 0.46, h), road);
    canvas.drawLine(Offset(w * 0.64, 0), Offset(w * 0.60, h), road);

    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.36;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0x401E5B3E),
    );
    drawDashedPath(
      canvas,
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Paint()
        ..color = AppColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(center, 4.5, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
