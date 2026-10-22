import 'package:flutter/material.dart';

import '../models/user_plant.dart';
import '../services/plant_manager.dart';
import '../utils/constants.dart';
import '../utils/crop_recommendation.dart';
import '../widgets/common.dart';
import 'kecocokan_lahan_screen.dart';
import 'tanaman_detail_screen.dart';

class TanamanScreen extends StatefulWidget {
  const TanamanScreen({super.key});

  @override
  State<TanamanScreen> createState() => _TanamanScreenState();
}

class _TanamanScreenState extends State<TanamanScreen> {
  late Future<List<UserPlant>> _plantsFuture;
  final _rekomendasiKey = GlobalKey(); // TAMBAH

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  void _loadPlants() {
    _plantsFuture = PlantManager.instance.getPlants();
  }

  Future<void> _refreshPlants() async {
    setState(_loadPlants);
    await _plantsFuture;
  }

  Future<void> _openDetail(CropRecommendation crop) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TanamanDetailScreen(crop: crop),
      ),
    );

    if (mounted) {
      await _refreshPlants();
    }
  }

  Future<void> _openLandAnalysis() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KecocokanLahanScreen(),
      ),
    );

    if (mounted) {
      setState(_loadPlants);
    }
  }

  // TAMBAH
  void _scrollToRekomendasi() {
    final ctx = _rekomendasiKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _deletePlant(UserPlant plant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus tanaman?'),
        content: Text(
          'Tanaman ${plant.name} akan dihapus dari daftar Tanaman Saya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await PlantManager.instance.removePlant(plant);

      if (!mounted) return;

      await _refreshPlants();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${plant.name} berhasil dihapus.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus tanaman.'),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final result = CropAnalysisStore.latest;
    final hasResult = result != null && result.recommendations.isNotEmpty;

    return SubPageScaffold(
      title: 'Tanaman',
      children: [
        // BAGIAN 1: TANAMAN MILIK PENGGUNA
        const Text(
          'Tanaman Saya',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Daftar tanaman yang sudah kamu pilih untuk ditanam.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),

        FutureBuilder<List<UserPlant>>(
          future: _plantsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AppCard(
                child: Column(
                  children: [
                    const Text('Gagal memuat daftar tanaman.'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(_loadPlants);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              );
            }

            final plants = snapshot.data ?? [];

            if (plants.isEmpty) {
              return AppCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.eco_outlined,
                      size: 42,
                      color: AppColors.green,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Belum ada tanaman',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pilih tanaman dari rekomendasi di bawah. '
                      'Tanaman yang kamu tambahkan akan muncul di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // UBAH: tombol tidak lagi membuka detail tanaman pertama
                    OutlinedButton.icon(
                      onPressed: () {
                        if (hasResult) {
                          _scrollToRekomendasi();
                        } else {
                          _openLandAnalysis();
                        }
                      },
                      icon: Icon(
                        hasResult
                            ? Icons.arrow_downward
                            : Icons.location_searching,
                      ),
                      label: Text(
                        hasResult ? 'Lihat Rekomendasi' : 'Analisis Lahan Dulu',
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: plants.map((plant) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.greenSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.eco,
                                color: AppColors.green,
                                size: 25,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plant.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mulai ditanam: '
                                    '${_formatDate(plant.plantedAt)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Hapus tanaman',
                              onPressed: () => _deletePlant(plant),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _PlantInfoRow(
                          icon: Icons.water_drop_outlined,
                          title: 'Interval penyiraman',
                          value: 'Setiap ${plant.wateringEveryDays} hari',
                        ),
                        const SizedBox(height: 12),
                        _PlantInfoRow(
                          icon: Icons.agriculture_outlined,
                          title: 'Perkiraan panen',
                          value: _formatDate(plant.estimatedHarvest),
                        ),
                        const SizedBox(height: 12),
                        _PlantInfoRow(
                          icon: Icons.notifications_active_outlined,
                          title: 'Penyiraman berikutnya',
                          value: _formatDate(plant.nextWatering),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 22),

        // BAGIAN 2: HASIL ANALISIS LAHAN
        Row(
          key: _rekomendasiKey, // TAMBAH
          children: [
            const Expanded(
              child: Text(
                'Rekomendasi Tanaman',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Analisis ulang lahan',
              onPressed: _openLandAnalysis,
              icon: const Icon(
                Icons.refresh,
                color: AppColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih tanaman yang sesuai dengan hasil analisis lahanmu.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),

        if (result == null)
          AppCard(
            child: Column(
              children: [
                const Icon(
                  Icons.landscape_outlined,
                  size: 42,
                  color: AppColors.green,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada hasil analisis lahan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Lakukan analisis lahan terlebih dahulu '
                  'untuk mendapatkan rekomendasi tanaman.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _openLandAnalysis,
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
                const Icon(
                  Icons.terrain,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zona hasil analisis',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        result.zoneName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${result.altitude.toStringAsFixed(0)} mdpl',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${result.recommendations.length} tanaman direkomendasikan',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),

          ...result.recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final crop = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                borderColor:
                    crop.highlighted ? AppColors.green : AppColors.border,
                borderWidth: crop.highlighted ? 1.5 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.eco_outlined,
                            color: crop.color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}. ${crop.name}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                crop.highlighted
                                    ? 'Rekomendasi unggulan'
                                    : 'Rekomendasi tanaman',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${crop.percent}% cocok',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: crop.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: crop.percent / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.greenSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          crop.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      crop.note,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openDetail(crop),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Lihat Detail & Pilih Tanaman'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _PlantInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _PlantInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.green,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}