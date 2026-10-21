import 'package:flutter/material.dart';
import '../models/user_plant.dart';
import '../services/plant_manager.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

class TanamanSayaScreen extends StatefulWidget {
  const TanamanSayaScreen({super.key});
  @override
  State<TanamanSayaScreen> createState() => _TanamanSayaScreenState();
}

class _TanamanSayaScreenState extends State<TanamanSayaScreen> {
  late Future<List<UserPlant>> _plantsFuture;
  @override
  void initState() {
    super.initState();
    PlantManager.instance.initializeNotifications();
    _reload();
  }
  void _reload() => _plantsFuture = PlantManager.instance.getPlants();

  String _date(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) => SubPageScaffold(
    title: 'Tanaman Saya',
    children: [
      const Text('Daftar tanaman yang sudah kamu pilih beserta pengingat perawatannya.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
      const SizedBox(height: 12),
      FutureBuilder<List<UserPlant>>(
        future: _plantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
          final plants = snapshot.data ?? [];
          if (plants.isEmpty) return const AppCard(child: Column(children: [Icon(Icons.spa_outlined, size: 42, color: AppColors.green), SizedBox(height: 8), Text('Belum ada tanaman pilihan', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Pilih salah satu tanaman dari halaman rekomendasi untuk menambahkannya di sini.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted))]));
          return Column(children: plants.map((plant) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.eco, color: AppColors.green, size: 25), const SizedBox(width: 9), Expanded(child: Text(plant.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))), IconButton(tooltip: 'Hapus tanaman', onPressed: () async { await PlantManager.instance.removePlant(plant); if (mounted) setState(_reload); }, icon: const Icon(Icons.delete_outline, color: Colors.redAccent))]),
              const Divider(),
              _line(Icons.calendar_month, 'Mulai ditanam', _date(plant.plantedAt)),
              _line(Icons.water_drop_outlined, 'Pengingat siram', 'Cek kelembapan tanah setiap hari'),
              _line(Icons.agriculture_outlined, 'Perkiraan panen', _date(plant.plantedAt.add(Duration(days: plant.harvestDays)))),
              const SizedBox(height: 5),
              const Text('Tips: siram jika tanah mulai kering; jangan menyiram berlebihan atau saat media masih basah.', style: TextStyle(fontSize: 10, height: 1.4, color: AppColors.muted)),
            ])),
          )).toList());
        },
      ),
    ],
  );

  Widget _line(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 16, color: AppColors.green), const SizedBox(width: 8), SizedBox(width: 112, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))), Expanded(child: Text(value, style: const TextStyle(fontSize: 11, color: AppColors.muted)))]));
}
