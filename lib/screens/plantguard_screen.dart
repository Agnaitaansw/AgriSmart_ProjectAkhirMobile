import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/plantguard_result.dart';
import '../services/plantguard_service.dart';

class PlantGuardScreen extends StatefulWidget {
  const PlantGuardScreen({super.key});
  @override
  State<PlantGuardScreen> createState() => _PlantGuardScreenState();
}

class _PlantGuardScreenState extends State<PlantGuardScreen> {
  final _picker = ImagePicker();
  final _symptoms = TextEditingController();
  final _service = PlantGuardService();
  File? _photo;
  PlantGuardResult? _result;
  bool _loading = false;
  String? _error;

  static const _dark = Color(0xFF1E5A43);
  static const _green = Color(0xFF2F7957);
  static const _pale = Color(0xFFE7F3E9);
  static const _page = Color(0xFFF7FAF7);

  @override
  void dispose() {
    _symptoms.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 82);
      if (picked == null || !mounted) return;
      setState(() { _photo = File(picked.path); _result = null; _error = null; });
    } catch (_) {
      if (mounted) _message('Foto tidak dapat diakses. Periksa izin kamera/galeri.');
    }
  }

  void _photoOptions() {
    showModalBottomSheet<void>(
      context: context, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Ambil foto dengan kamera'),
          onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Pilih dari galeri'),
          onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery); }),
      ])),
    );
  }

  Future<void> _analyze() async {
    if (_photo == null) { _message('Pilih atau ambil foto tanaman terlebih dahulu.'); return; }
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final result = await _service.diagnose(photo: _photo!, additionalSymptoms: _symptoms.text);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() => setState(() { _photo = null; _result = null; _error = null; _symptoms.clear(); });
  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.chevron_left, color: _dark),
          onPressed: () => Navigator.of(context).maybePop()),
        title: const Row(children: [
          CircleAvatar(radius: 18, backgroundColor: _pale,
            child: Icon(Icons.health_and_safety_rounded, color: _green)),
          SizedBox(width: 9),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PlantGuard', style: TextStyle(color: _dark, fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Sahabat kesehatan tanaman kamu', style: TextStyle(fontSize: 10, color: Colors.black54)),
          ]),
        ]),
        actions: [IconButton(tooltip: 'Pemeriksaan baru', onPressed: _loading ? null : _reset,
          icon: const Icon(Icons.refresh_rounded, color: _dark))],
      ),
      body: SafeArea(top: false, child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_dark, _green]),
            borderRadius: BorderRadius.circular(18)),
            child: const Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kenali kondisi tanamanmu 🌿', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 7),
                Text('Unggah foto daun, batang, atau buah untuk memeriksa kemungkinan gangguan dan mendapatkan saran awal.',
                  style: TextStyle(color: Colors.white, fontSize: 11.5, height: 1.5)),
              ])),
              SizedBox(width: 10),
              Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 44),
            ])),
          const SizedBox(height: 20),
          const Text('1. Foto tanaman', style: TextStyle(color: _dark, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Ambil foto bagian yang terlihat bermasalah', style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 9),
          InkWell(onTap: _loading ? null : _photoOptions, borderRadius: BorderRadius.circular(16),
            child: Container(width: double.infinity, constraints: const BoxConstraints(minHeight: 180),
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(16), border: Border.all(color: _photo == null ? const Color(0xFFD7E8DA) : _green)),
              child: _photo == null
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircleAvatar(radius: 27, backgroundColor: _pale, child: Icon(Icons.add_a_photo_outlined, color: _green, size: 27)),
                    SizedBox(height: 10),
                    Text('Tambah foto tanaman', style: TextStyle(color: _dark, fontSize: 13, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Ketuk untuk membuka kamera atau galeri', style: TextStyle(fontSize: 11, color: Colors.black54)),
                  ])
                : Column(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(_photo!, height: 220, width: double.infinity, fit: BoxFit.cover)),
                    TextButton.icon(onPressed: _loading ? null : _photoOptions, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Ganti foto')),
                  ]))),
          const SizedBox(height: 18),
          const Text('2. Informasi tambahan', style: TextStyle(color: _dark, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Opsional, misalnya sejak kapan gejala muncul', style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 9),
          TextField(controller: _symptoms, minLines: 2, maxLines: 4, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Contoh: daun menguning sejak 3 hari lalu...',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.black45), filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E8E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E8E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _green)))),
          const SizedBox(height: 16),
          SizedBox(height: 50, child: ElevatedButton.icon(
            onPressed: _loading ? null : _analyze,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.biotech_rounded),
            label: Text(_loading ? 'Sedang menganalisis...' : 'Analisis Tanaman',
              style: const TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0))),
          if (_error != null) ...[const SizedBox(height: 14), _errorCard(_error!)],
          if (_result != null) ...[const SizedBox(height: 22), _resultView(_result!)],
          const SizedBox(height: 18),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: _green, size: 18), SizedBox(width: 8),
            Expanded(child: Text('Hasil PlantGuard adalah panduan awal dari foto, bukan diagnosis pasti. Untuk gejala berat atau menyebar cepat, konsultasikan dengan penyuluh pertanian.',
              style: TextStyle(fontSize: 11, color: Color(0xFF52665A), height: 1.45))),
          ]),
        ],
      )),
    );
  }

  Widget _errorCard(String text) => Container(padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(13)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline, color: Colors.red), const SizedBox(width: 9),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4))),
    ]));

  Widget _resultView(PlantGuardResult r) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Hasil Pemeriksaan', style: TextStyle(color: _dark, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDCE9DE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.health_and_safety_rounded, color: _green), SizedBox(width: 7),
          Text('Kemungkinan gangguan', style: TextStyle(color: _dark, fontSize: 12, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 9),
        Text(r.kemungkinanGangguan, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _dark)),
        const SizedBox(height: 7),
        Text(r.penjelasan, style: const TextStyle(fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _tag('Tanaman: ${r.namaTanaman}'), _tag('Keyakinan: ${r.tingkatKeyakinan}'),
          _tag('Keparahan: ${r.tingkatKeparahan}'),
        ]),
      ])),
    if (r.gejalaTerlihat.isNotEmpty) _listCard('Gejala yang terlihat', r.gejalaTerlihat, Icons.visibility_outlined),
    if (r.langkahPenanganan.isNotEmpty) _listCard('Langkah penanganan awal', r.langkahPenanganan, Icons.healing_outlined),
    if (r.pencegahan.isNotEmpty) _listCard('Saran pencegahan', r.pencegahan, Icons.shield_outlined),
    const SizedBox(height: 10),
    Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _pale, borderRadius: BorderRadius.circular(13)),
      child: Text(r.catatan, style: const TextStyle(color: _dark, fontSize: 11.5, height: 1.5))),
  ]);

  Widget _tag(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: _pale, borderRadius: BorderRadius.circular(30)),
    child: Text(text, style: const TextStyle(color: _dark, fontSize: 10, fontWeight: FontWeight.w600)));

  Widget _listCard(String title, List<String> items, IconData icon) => Container(
    width: double.infinity, margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE3EBE4))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: _green, size: 19), const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(color: _dark, fontSize: 12.5, fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 9),
      for (int i = 0; i < items.length; i++)
        Padding(padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 6, color: _green)),
            const SizedBox(width: 8),
            Expanded(child: Text(items[i], style: const TextStyle(fontSize: 12, height: 1.45))),
          ])),
    ]));
}
