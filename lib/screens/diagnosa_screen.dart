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

  static const _contohGejala = <String>[
    'Daun menguning',
    'Bercak coklat di daun',
    'Tanaman layu',
    'Buah busuk',
  ];

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

  // ───────────────────────── UI ─────────────────────────

  static const double _maxWidth = 520;
  static const _dark = Color(0xFF1E4D3A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const Text(
          'FlorAI',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 22),
            onPressed: () {
              showSoon(context, 'Riwayat diagnosa segera hadir');
            },
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _maxWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  // Saat belum ada hasil, tinggi layar dibagi rata antar
                  // bagian; saat hasil muncul halaman tinggal di-scroll.
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildGreeting(),
                        const SizedBox(height: 16),
                        _buildFormCard(),
                        const SizedBox(height: 16),
                        _buildAnalyzeButton(),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _buildError(),
                        ],
                        if (_result != null && !_loading) ...[
                          const SizedBox(height: 16),
                          _ResultCard(result: _result!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_dark, AppColors.green],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withAlpha(100),
            blurRadius: 26,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              top: -16,
              child: Transform.rotate(
                angle: 0.5,
                child: Icon(
                  Icons.eco_rounded,
                  size: 130,
                  color: Colors.white.withAlpha(24),
                ),
              ),
            ),
            Positioned(
              right: 70,
              bottom: -22,
              child: Transform.rotate(
                angle: -0.6,
                child: Icon(
                  Icons.eco_rounded,
                  size: 70,
                  color: Colors.white.withAlpha(18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(36),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(120),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, Agrivers! 🌱👋',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ada yang bisa Flora bantu hari ini?',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Color(0xFFD7E8DD),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Foto tanaman',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          _photoSection(),
          const SizedBox(height: 16),
          const Text(
            'Ceritakan keluhan atau gejala tanamanmu pada Flora',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 4,
            style: const TextStyle(fontSize: 13, height: 1.4),
            decoration: InputDecoration(
              hintText:
                  'misalnya daun menguning sejak 3 hari lalu atau foto bagian tanaman yang bermasalah.',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.green,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.green,
                  width: 1.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in _contohGejala)
                ActionChip(
                  label: Text(c, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.greenSoft,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () {
                    _controller.text = c;
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _loading ? null : _analyze,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          elevation: 4,
          shadowColor: AppColors.green.withAlpha(120),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(
          _loading ? 'Menganalisis...' : 'Analisis dengan AI',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildError() {
    return AppCard(
      radius: 16,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: _loading ? null : _analyze,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _photoSection() {
    if (_foto == null) {
      return InkWell(
        onTap: _showPhotoSheet,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.green.withAlpha(128)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                color: AppColors.green,
                size: 28,
              ),
              SizedBox(height: 8),
              Text(
                'Tambah foto tanaman',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            _foto!,
            height: 170,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _MiniBtn(icon: Icons.edit, onTap: _showPhotoSheet),
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
          child: Icon(icon, size: 16, color: Colors.white),
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
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dugaan penyakit',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            result.penyakit,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.penjelasan,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Rekomendasi penanganan',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.greenSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: const TextStyle(fontSize: 12.5, height: 1.4),
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
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}