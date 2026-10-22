
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diagnosa_result.dart';
import '../services/diagnosa_service.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

class DiagnosaScreen extends StatefulWidget {
  const DiagnosaScreen({super.key});

  @override
  State<DiagnosaScreen> createState() => _DiagnosaScreenState();
}

class _DiagnosaScreenState extends State<DiagnosaScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final _service = DiagnosaService();

  File? _foto;
  bool _loading = false;
  DiagnosaResult? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 75,
      );

      if (x == null || !mounted) return;

      setState(() {
        _foto = File(x.path);
        _result = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        showSoon(context, 'Tidak bisa mengakses kamera/galeri');
      }
    }
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyze() async {
    final keluhan = _controller.text.trim();

    if (keluhan.isEmpty && _foto == null) {
      showSoon(context, 'Tulis gejala atau unggah foto dulu ya');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final r = await _service.analisis(
        tanaman: '',
        keluhan: keluhan,
        foto: _foto,
      );

      if (!mounted) return;

      setState(() {
        _result = r;
      });
    } on SocketException {
      if (mounted) {
        setState(() {
          _error = 'Tidak ada koneksi internet.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _photoSection() {
    if (_foto == null) {
      return InkWell(
        onTap: _showPhotoSheet,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 90,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.green.withOpacity(0.5),
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                color: AppColors.green,
              ),
              SizedBox(height: 6),
              Text(
                'Tambah foto tanaman (opsional)',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            _foto!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            children: [
              _MiniBtn(
                icon: Icons.edit,
                onTap: _showPhotoSheet,
              ),
              const SizedBox(width: 6),
              _MiniBtn(
                icon: Icons.close,
                onTap: () {
                  setState(() {
                    _foto = null;
                    _result = null;
                    _error = null;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'FlorAI',
      actions: [
        IconButton(
          icon: const Icon(Icons.history, size: 22),
          onPressed: () {
            showSoon(context, 'Riwayat diagnosa segera hadir');
          },
        ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Foto tanaman',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              _photoSection(),
              const SizedBox(height: 12),
              const Text(
                'Keluhan gejala',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                maxLines: 4,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Ceritakan gejala tanaman, misalnya daun menguning sejak 3 hari lalu (opsional jika sudah menambahkan foto).',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.green,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.green,
                      width: 1.8,
                    ),
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
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome,
                    size: 18,
                  ),
            label: Text(
              _loading ? 'Menganalisis...' : 'Analisis dengan AI',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          AppCard(
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _analyze,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        if (_result != null && !_loading)
          _ResultCard(result: _result!),
      ],
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniBtn({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final DiagnosaResult result;

  const _ResultCard({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final steps = result.langkah;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dugaan penyakit',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.upSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
              
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            result.penyakit,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.penjelasan,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Rekomendasi penanganan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < steps.length; i++)
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
                      child: Text(
                        steps[i],
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
                 
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Hasil AI bersifat panduan awal. Konsultasikan dengan penyuluh pertanian untuk kasus berat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
