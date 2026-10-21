import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/crop_recommendation.dart';
import '../widgets/common.dart';
import 'kecocokan_lahan_screen.dart';

class TanamanScreen extends StatefulWidget {
  const TanamanScreen({super.key});

  @override
  State<TanamanScreen> createState() => _TanamanScreenState();
}

class _TanamanScreenState extends State<TanamanScreen> {
  @override
  Widget build(BuildContext context) {
    final result = CropAnalysisStore.latest;

    return SubPageScaffold(
      title: 'Tanaman',
      children: [
        const Text(
          'Rekomendasi tanaman berdasarkan hasil analisis lahan',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        if (result == null)
          AppCard(
            child: Column(
              children: [
                const Icon(Icons.grass, size: 42, color: AppColors.green),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada hasil analisis lahan',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Buka fitur Lahan terlebih dahulu untuk mendapatkan rekomendasi tanaman sesuai lokasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const KecocokanLahanScreen(),
                      ),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  icon: const Icon(Icons.location_searching),
                  label: const Text('Analisis Lahan'),
                ),
              ],
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.terrain, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zona hasil analisis',
                          style: TextStyle(fontSize: 10, color: Colors.white70)),
                      const SizedBox(height: 3),
                      Text(result.zoneName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 3),
                      Text(
                        '${result.altitude.toStringAsFixed(0)} mdpl  •  ${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Lihat analisis lahan',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const KecocokanLahanScreen(),
                      ),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tanaman yang direkomendasikan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.recommendations.length} rekomendasi dari hasil analisis lahan',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          ...result.recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final crop = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlantCard(rank: index + 1, crop: crop),
            );
          }),
        ],
      ],
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.rank, required this.crop});

  final int rank;
  final CropRecommendation crop;

  IconData get _icon {
    final name = crop.name.toLowerCase();
    if (name.contains('padi') || name.contains('jagung')) return Icons.grass;
    if (name.contains('kopi') || name.contains('teh') || name.contains('kelapa')) return Icons.park;
    if (name.contains('kentang') || name.contains('wortel')) return Icons.spa;
    if (name.contains('stroberi') || name.contains('buah') || name.contains('melon') || name.contains('semangka')) return Icons.eco;
    return Icons.local_florist;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: crop.highlighted ? AppColors.green : AppColors.border,
      borderWidth: crop.highlighted ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crop.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      crop.highlighted ? 'Rekomendasi unggulan' : 'Rekomendasi tanaman',
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('${crop.percent}% cocok',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crop.color)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: crop.percent / 100,
              minHeight: 6,
              backgroundColor: AppColors.greenSoft,
              valueColor: AlwaysStoppedAnimation<Color>(crop.color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 15, color: AppColors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(crop.note,
                    style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
