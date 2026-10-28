
import 'package:flutter/material.dart';

import '../models/user_plant.dart';
import '../utils/constants.dart';
import '../utils/crop_recommendation.dart';
import '../widgets/common.dart';
import '../services/plant_manager.dart';

class TanamanDetailScreen extends StatefulWidget {
  final CropRecommendation crop;

  const TanamanDetailScreen({
    super.key,
    required this.crop,
  });

  @override
  State<TanamanDetailScreen> createState() =>
      _TanamanDetailScreenState();
}

class _TanamanDetailScreenState extends State<TanamanDetailScreen> {
  bool _alreadyAdded = false;
  bool _checking = true;
  bool _saving = false;

  late final _CropInfo _info;

  @override
  void initState() {
    super.initState();
    _info = _getInfo(widget.crop.name);
    _checkSaved();
  }


  Future<void> _checkSaved() async {
    try {
      final added = await PlantManager.instance.contains(
        widget.crop.name,
      );

      if (!mounted) return;

      setState(() {
        _alreadyAdded = added;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _checking = false;
      });
    }
  }

  // Informasi perawatan berdasarkan jenis tanaman.
  _CropInfo _getInfo(String name) {
    final n = name.toLowerCase();

    if (n.contains('cabai')) {
      return const _CropInfo(
        '75–100 hari',
        1,
        90,
        'Siram pagi atau sore ketika permukaan tanah mulai kering. Gunakan tanah gembur dengan drainase baik.',
        [
          'Berikan sinar matahari 6–8 jam per hari.',
          'Pasang ajir saat tanaman mulai tinggi.',
          'Periksa daun secara rutin untuk mendeteksi hama.',
          'Hindari genangan air di sekitar akar.',
        ],
        'Sekitar 75–100 hari setelah tanam, bergantung varietas dan kondisi.',
      );
    }

    if (n.contains('padi')) {
      return const _CropInfo(
        '100–120 hari',
        1,
        110,
        'Atur ketersediaan air sesuai fase pertumbuhan. Kebutuhan air padi sawah berbeda dari tanaman pot.',
        [
          'Gunakan benih sehat dan tanam pada lahan rata.',
          'Atur irigasi sesuai fase pertumbuhan.',
          'Lakukan pemupukan sesuai kebutuhan lahan.',
          'Pantau wereng dan penyakit secara berkala.',
        ],
        'Umumnya sekitar 100–120 hari untuk varietas padi tertentu.',
      );
    }

    if (n.contains('jagung')) {
      return const _CropInfo(
        '90–120 hari',
        2,
        100,
        'Siram teratur saat awal tumbuh dan pembentukan tongkol. Kurangi penyiraman bila hujan cukup.',
        [
          'Pilih lokasi dengan sinar matahari penuh.',
          'Pastikan tanah tidak tergenang.',
          'Beri jarak tanam sesuai varietas.',
          'Pantau ulat dan kondisi tongkol.',
        ],
        'Sekitar 90–120 hari, tergantung varietas.',
      );
    }

    if (n.contains('tomat')) {
      return const _CropInfo(
        '60–90 hari',
        1,
        75,
        'Jaga kelembapan tanah tetap stabil. Siram bagian tanah, bukan daun, untuk mengurangi risiko penyakit.',
        [
          'Gunakan media kaya bahan organik dan berdrainase baik.',
          'Pasang penyangga ketika tanaman membesar.',
          'Buang daun yang sakit.',
          'Panen bertahap saat buah matang.',
        ],
        'Mulai berbuah sekitar 60–90 hari setelah tanam.',
      );
    }

    if (n.contains('kacang tanah')) {
      return const _CropInfo(
        '90–110 hari',
        2,
        100,
        'Jaga tanah cukup lembap saat berbunga dan pembentukan polong. Hindari genangan.',
        [
          'Pilih tanah gembur agar polong berkembang.',
          'Lakukan penyiangan pada awal pertumbuhan.',
          'Hindari pemupukan nitrogen berlebihan.',
          'Kurangi penyiraman berlebih menjelang panen.',
        ],
        'Umumnya sekitar 90–110 hari.',
      );
    }

    if (n.contains('kelapa')) {
      return const _CropInfo(
        'Mulai berbuah 3–7 tahun',
        3,
        1095,
        'Bibit muda perlu disiram saat musim kering. Tanaman dewasa bergantung pada curah hujan dan kondisi tanah.',
        [
          'Pilih bibit sehat dan lokasi terbuka.',
          'Berikan ruang tumbuh yang cukup.',
          'Tambahkan bahan organik di sekitar tanaman.',
          'Jaga tanaman muda dari gulma.',
        ],
        'Kelapa bukan tanaman panen cepat. Waktu berbuah bergantung jenis dan perawatan.',
      );
    }

    if (n.contains('semangka')) {
      return const _CropInfo(
        '70–100 hari',
        1,
        80,
        'Siram konsisten saat tanaman tumbuh dan buah membesar. Kurangi air menjelang panen jika kondisi memungkinkan.',
        [
          'Tanam di tempat yang mendapat matahari penuh.',
          'Pastikan drainase baik.',
          'Berikan ruang untuk tanaman merambat.',
          'Hindari membasahi daun terlalu sering.',
        ],
        'Biasanya sekitar 70–100 hari.',
      );
    }

    if (n.contains('melon')) {
      return const _CropInfo(
        '70–100 hari',
        1,
        80,
        'Pertahankan kelembapan tanah yang stabil, terutama saat pembentukan buah.',
        [
          'Gunakan tanah subur dan tidak becek.',
          'Sediakan rambatan bila memakai sistem vertikal.',
          'Pantau kutu daun dan embun tepung.',
          'Sesuaikan penyiraman menjelang panen.',
        ],
        'Sekitar 70–100 hari, tergantung varietas.',
      );
    }

    if (n.contains('bawang')) {
      return const _CropInfo(
        '60–90 hari',
        1,
        75,
        'Siram sesuai kelembapan tanah. Hindari lahan terlalu basah, terutama mendekati panen.',
        [
          'Pilih tanah gembur dengan drainase baik.',
          'Pastikan sinar matahari cukup.',
          'Lakukan penyiangan.',
          'Kurangi air saat daun mulai menguning.',
        ],
        'Umumnya sekitar 60–90 hari.',
      );
    }

    if (n.contains('buah naga')) {
      return const _CropInfo(
        'Mulai berbuah 8–18 bulan',
        3,
        365,
        'Tanaman relatif tahan kering. Siram saat media mulai kering dan hindari genangan.',
        [
          'Gunakan tiang penyangga yang kuat.',
          'Tanam di lokasi terang.',
          'Pangkas cabang yang terlalu rapat.',
          'Jaga pangkal batang agar tidak terus basah.',
        ],
        'Waktu mulai berbuah bergantung bibit, varietas, dan kondisi tumbuh.',
      );
    }

    if (n.contains('kopi') || n.contains('teh')) {
      return const _CropInfo(
        'Mulai dipanen 2–4 tahun',
        3,
        730,
        'Jaga kelembapan tanah, khususnya pada bibit muda. Kebutuhan air menyesuaikan curah hujan dan jenis tanaman.',
        [
          'Pilih varietas sesuai ketinggian dan suhu.',
          'Gunakan mulsa untuk menjaga kelembapan.',
          'Lakukan pemangkasan sesuai jenis tanaman.',
          'Periksa hama dan penyakit secara rutin.',
        ],
        'Tanaman tahunan; waktu produksi pertama sangat bervariasi.',
      );
    }

    if (n.contains('kentang')) {
      return const _CropInfo(
        '90–120 hari',
        1,
        100,
        'Jaga tanah lembap tetapi tidak becek. Hindari perubahan kelembapan yang terlalu ekstrem.',
        [
          'Gunakan benih umbi sehat.',
          'Lakukan pembumbunan saat tanaman tumbuh.',
          'Pastikan drainase baik.',
          'Pantau penyakit daun dan umbi.',
        ],
        'Umumnya sekitar 90–120 hari.',
      );
    }

    if (n.contains('wortel')) {
      return const _CropInfo(
        '70–100 hari',
        2,
        85,
        'Siram lembut agar tanah lembap dan tidak mengeras. Hindari genangan yang dapat merusak akar.',
        [
          'Gunakan tanah dalam, gembur, dan bebas batu.',
          'Jangan terlalu banyak nitrogen.',
          'Lakukan penjarangan bibit.',
          'Panen sesuai ukuran akar.',
        ],
        'Sekitar 70–100 hari.',
      );
    }

    if (n.contains('stroberi')) {
      return const _CropInfo(
        '90–150 hari untuk panen awal',
        1,
        100,
        'Siram di sekitar akar dan jaga media tetap lembap, bukan basah. Frekuensi bergantung cuaca dan media.',
        [
          'Penuhi kebutuhan cahaya dan suhu varietas.',
          'Gunakan media kaya bahan organik dan berdrainase baik.',
          'Buang daun atau buah yang busuk.',
          'Gunakan mulsa agar buah tidak menyentuh tanah.',
        ],
        'Panen awal dapat dimulai sekitar 90–150 hari, bergantung varietas.',
      );
    }

    if (n.contains('kubis') || n.contains('kol')) {
      return const _CropInfo(
        '80–120 hari',
        1,
        100,
        'Siram teratur untuk menjaga kelembapan tanah, terutama ketika pembentukan krop.',
        [
          'Tanam pada suhu yang sesuai varietas.',
          'Pastikan tanah subur dan drainase baik.',
          'Pantau ulat daun.',
          'Jangan biarkan tanah terlalu kering saat krop terbentuk.',
        ],
        'Umumnya sekitar 80–120 hari.',
      );
    }

    return const _CropInfo(
      'Bervariasi menurut varietas',
      2,
      90,
      'Periksa kondisi tanah sebelum menyiram. Hindari tanah terlalu kering atau tergenang.',
      [
        'Sesuaikan lokasi dengan kebutuhan cahaya tanaman.',
        'Gunakan media subur dan berdrainase baik.',
        'Periksa daun dan batang secara rutin.',
        'Sesuaikan penyiraman dengan cuaca.',
      ],
      'Waktu panen perlu disesuaikan dengan varietas dan kondisi setempat.',
    );
  }

  Future<void> _addPlant() async {
    if (_checking || _saving || _alreadyAdded) return;

    setState(() {
      _saving = true;
    });

    try {
      final plant = UserPlant(
        
        name: widget.crop.name,
        plantedAt: DateTime.now(),
        wateringEveryDays: _info.wateringEveryDays,
        harvestDays: _info.harvestDays,
      );

      await PlantManager.instance.addPlant(plant);

      final added = await PlantManager.instance.contains(
        widget.crop.name,
      );

      if (!mounted) return;

      setState(() {
        _alreadyAdded = added;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added
                ? '${widget.crop.name} berhasil ditambahkan ke Tanaman Saya.'
                : 'Tanaman belum berhasil ditambahkan.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Terjadi kesalahan saat menambahkan tanaman.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: widget.crop.name,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.eco,
                    size: 34,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.crop.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.crop.percent}% cocok',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.crop.note,
                style: const TextStyle(
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              const Divider(height: 24),
              _InfoRow(
                icon: Icons.hourglass_bottom,
                title: 'Lama tanam / panen',
                value: _info.duration,
              ),
              _InfoRow(
                icon: Icons.water_drop_outlined,
                title: 'Panduan penyiraman',
                value: _info.watering,
              ),
              _InfoRow(
                icon: Icons.notifications_active_outlined,
                title: 'Pengingat penyiraman',
                value:
                    'Setiap ${_info.wateringEveryDays} hari. '
                    'Pastikan notifikasi aplikasi diizinkan.',
              ),
              _InfoRow(
                icon: Icons.agriculture_outlined,
                title: 'Perkiraan panen',
                value: _info.harvestText,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        const Text(
          'Tips perawatan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _info.tips.map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _checking ||
                    _saving ||
                    _alreadyAdded
                ? null
                : _addPlant,
            icon: Icon(
              _alreadyAdded
                  ? Icons.check
                  : Icons.add,
            ),
            label: Text(
              _checking
                  ? 'Memeriksa tanaman...'
                  : _saving
                      ? 'Menyimpan tanaman...'
                      : _alreadyAdded
                          ? 'Sudah ada di Tanaman Saya'
                          : 'Pilih Tanaman Ini',
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Catatan: durasi dan jadwal perawatan merupakan perkiraan. '
          'Sesuaikan dengan varietas, cuaca, media, dan kondisi lahan.',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _CropInfo {
  final String duration;
  final int wateringEveryDays;
  final int harvestDays;
  final String watering;
  final List<String> tips;
  final String harvestText;

  const _CropInfo(
    this.duration,
    this.wateringEveryDays,
    this.harvestDays,
    this.watering,
    this.tips,
    this.harvestText,
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: AppColors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
