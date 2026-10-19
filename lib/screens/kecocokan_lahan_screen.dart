import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common.dart';

class KecocokanLahanScreen extends StatelessWidget {
  const KecocokanLahanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Kecocokan Lahan',
      children: [
        // Peta
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

        // Koordinat
        AppCard(
          child: Row(
            children: [
              const _Stat('Latitude', '-7.7956'),
              const _Stat('Longitude', '110.3695'),
              const _Stat('Ketinggian', '118 mdpl'),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showSoon(context, 'Memperbarui lokasi...'),
                child: const IconBox(
                  icon: Icons.my_location,
                  size: 36,
                  radius: 10,
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
        const _CropMatchCard(
          name: 'Cabai rawit',
          percent: 92,
          note: 'Suhu 27°C, curah hujan sedang, tanah lempung berpasir',
          color: AppColors.green,
          highlighted: true,
        ),
        const SizedBox(height: 10),
        const _CropMatchCard(
          name: 'Padi sawah',
          percent: 81,
          note: 'Pasokan air tinggi, dekat sumber air',
          color: AppColors.up,
        ),
        const SizedBox(height: 10),
        const _CropMatchCard(
          name: 'Jagung',
          percent: 68,
          note: 'Kelembapan lahan cukup tinggi, pilih varietas tahan',
          color: AppColors.amber,
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

/// Peta sederhana (placeholder) + lingkaran radius analisis.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9ECDF));

    // Blok lahan
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

    // Sungai
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

    // Jalan
    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * 0.50), Offset(w, h * 0.46), road);
    canvas.drawLine(Offset(w * 0.38, 0), Offset(w * 0.46, h), road);
    canvas.drawLine(Offset(w * 0.64, 0), Offset(w * 0.60, h), road);

    // Lingkaran radius
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

    // Titik pusat
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(center, 4.5, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
