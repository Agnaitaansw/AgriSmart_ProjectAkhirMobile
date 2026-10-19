import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../widgets/common.dart';
import '../widgets/auth_widgets.dart';

class DiagnosaScreen extends StatefulWidget {
  const DiagnosaScreen({super.key});

  @override
  State<DiagnosaScreen> createState() => _DiagnosaScreenState();
}

class _DiagnosaScreenState extends State<DiagnosaScreen> {
  final _controller = TextEditingController(
    text:
        'Daun bagian bawah muncul bercak cokelat bulat dengan tepi kuning, lalu rontok sejak 3 hari lalu.',
  );

  bool _loading = false;
  bool _hasResult = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_controller.text.trim().isEmpty) {
      showSoon(context, 'Tulis gejalanya dulu ya');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    // Simulasi panggilan API AI.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasResult = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Diagnosa Penyakit AI',
      actions: [
        IconButton(
          icon: const Icon(Icons.history, size: 22),
          onPressed: () => showSoon(context, 'Riwayat diagnosa segera hadir'),
        ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Tanaman',
                      style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.green),
                    ),
                    child: const Text(
                      'Cabai rawit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Keluhan gejala',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                maxLines: 4,
                style: const TextStyle(fontSize: 12.5, height: 1.4),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.green, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.green, width: 1.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: _loading ? null : _analyze,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _loading ? 'Menganalisis...' : 'Analisis dengan AI',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_hasResult && !_loading) const _ResultCard(),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard();

  static const _steps = [
    'Buang dan musnahkan daun yang terinfeksi.',
    'Semprot fungisida berbahan aktif mankozeb sesuai dosis label.',
    'Siram pagi hari dan atur jarak tanam agar daun cepat kering.',
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Dugaan penyakit',
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.upSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Keyakinan 87%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.up,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Bercak daun Cercospora',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Disebabkan jamur yang menyebar saat kelembapan tinggi dan daun sering basah.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Text('Rekomendasi penanganan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.greenSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_steps[i],
                        style: const TextStyle(fontSize: 12, height: 1.4)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showSoon(context, 'Disimpan ke riwayat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Simpan ke riwayat',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => showSoon(context, 'Dicatat ke log tanam'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Catat ke log',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Hasil AI bersifat panduan awal. Konsultasikan dengan penyuluh pertanian untuk kasus berat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
