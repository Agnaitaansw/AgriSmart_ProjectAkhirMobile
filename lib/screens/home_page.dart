import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';
import 'diagnosa_screen.dart';
import 'harga_ekspor_screen.dart';
import 'kecocokan_lahan_screen.dart';
import 'login_page.dart';
import 'simulasi_penyiraman_screen.dart';
import 'kemiringan_lahan_screen.dart';
import 'blockchain_log_screen.dart';
import 'profil_screen.dart';
import 'tanaman_screen.dart';
import 'saran_pam_screen.dart';

class _Feature {
  const _Feature(this.label, this.icon, this.fg, this.bg, [this.page]);

  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final Widget? page;
}

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  final _auth = AuthService.instance;
  UserModel? _user;

  String _locationText = 'Mencari lokasi...';

  static const _features = <_Feature>[
    _Feature(
      'Lahan',
      Icons.landscape_outlined,
      Color(0xFF2E7D4F),
      Color(0xFFE3F3E8),
      KecocokanLahanScreen(),
    ),
    _Feature(
      'FlorAI',
      Icons.wb_sunny_outlined,
      Color(0xFF7B52C9),
      Color(0xFFEEE7FA),
      DiagnosaScreen(),
    ),
    _Feature(
      'Harga Ekspor',
      Icons.trending_up_rounded,
      Color(0xFFD9822B),
      Color(0xFFFCEFDD),
      HargaEksporScreen(),
    ),
    _Feature(
      'Mini Game',
      Icons.sports_esports_outlined,
      Color(0xFFD64B7A),
      Color(0xFFFBE4EC),
      SimulasiPenyiramanScreen(),
    ),
    _Feature(
      'Waterpass',
      Icons.straighten_outlined,
      Color(0xFF2B8BC9),
      Color(0xFFE1F1FB),
      KemiringanLahanScreen(),
    ),
    _Feature(
      'Poin',
      Icons.menu_book_outlined,
      Color(0xFFC9A017),
      Color(0xFFFBF3D5),
      BlockchainLogScreen(),
    ),
    _Feature(
      'Tanaman',
      Icons.spa_outlined,
      Color(0xFF3C9A3C),
      Color(0xFFE6F5DF),
      TanamanScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserSession();
    _loadProfilePhoto();
    _getCurrentLocation();
  }

  /// Ambil foto profil yang tersimpan (kunci sama dengan ProfilScreen).
  Future<void> _loadProfilePhoto() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    profilePhotoNotifier.value = prefs.getString('profile_photo_$userId');
  }

  Future<void> _loadUserSession() async {
    final u = await _auth.currentUser();

    if (!mounted) return;
    if (u == null) {
      return _logout();
    }

    setState(() {
      _user = u;
    });
  }

  Future<void> _logout() async {
    await _auth.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _locationText = 'GPS tidak aktif');
      }
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _locationText = 'Izin lokasi ditolak');
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(
          () => _locationText = 'Izin lokasi ditolak permanen',
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _locationText =
              '${position.latitude.toStringAsFixed(4)}, '
              '${position.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _locationText = 'Lokasi gagal didapatkan');
      }
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;

    if (h < 11) return 'Selamat pagi,';
    if (h < 15) return 'Selamat siang,';
    if (h < 18) return 'Selamat sore,';

    return 'Selamat malam,';
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  static const double _maxWidth = 520;
  static const double _hPad = 16;
  static const double _gridGap = 10;

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: u == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentW =
                      constraints.maxWidth.clamp(0.0, _maxWidth) - _hPad * 2;
                  final tileW = (contentW - _gridGap * 3) / 4 - 0.5;
                  final boxSize = (tileW * 0.82).clamp(54.0, 82.0);
                  final tileH = boxSize + 34;

                  // Tinggi minimal agar tidak overflow; kalau layar lebih
                  // pendek halaman bisa di-scroll.
                  final totalH = constraints.maxHeight < 620
                      ? 620.0
                      : constraints.maxHeight;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _maxWidth),
                        child: SizedBox(
                          height: totalH,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              _hPad,
                              36,
                              _hPad,
                              16,
                            ),
                            // Sisa tinggi layar dibagi rata lewat Spacer,
                            // jadi tidak numpuk di atas / kosong di bawah.
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(u),
                                const Spacer(flex: 1),
                                _buildLocationCard(totalH),
                                const Spacer(flex: 1),
                                _buildGrid(tileW, tileH, boxSize),
                                const Spacer(flex: 1),
                              ],
                            ),
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

  Widget _leaf(double size, double angle, int alpha) {
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.eco_rounded,
        size: size,
        color: AppColors.green.withAlpha(alpha),
      ),
    );
  }

  Widget _buildHeader(UserModel u) {
    return SizedBox(
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ikon daun sebagai background header
          Positioned(right: 36, top: -22, child: _leaf(92, 0.5, 26)),
          Positioned(left: 150, bottom: -26, child: _leaf(70, -0.6, 20)),
          Positioned(right: -14, bottom: -18, child: _leaf(58, 0.9, 30)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Halo, ${u.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _open(context, const ProfilScreen()),
                child: ValueListenableBuilder<String?>(
                  valueListenable: profilePhotoNotifier,
                  builder: (context, photoPath, _) {
                    final hasPhoto =
                        photoPath != null && File(photoPath).existsSync();

                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.green, width: 1.4),
                        image: hasPhoto
                            ? DecorationImage(
                                image: FileImage(File(photoPath)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: hasPhoto
                          ? null
                          : const Icon(
                              Icons.person_rounded,
                              color: AppColors.green,
                              size: 26,
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(double totalH) {
    final padV = (totalH * 0.045).clamp(26.0, 42.0);
    final gap = (totalH * 0.04).clamp(22.0, 38.0);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E4D3A), AppColors.green],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withAlpha(110),
            blurRadius: 28,
            spreadRadius: -2,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.green.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Ikon peta sebagai background kartu
            Positioned(
              right: -18,
              top: -14,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  Icons.map_rounded,
                  size: 190,
                  color: Colors.white.withAlpha(24),
                ),
              ),
            ),
            Positioned(
              left: -22,
              bottom: -26,
              child: Transform.rotate(
                angle: 0.25,
                child: Icon(
                  Icons.explore_rounded,
                  size: 130,
                  color: Colors.white.withAlpha(18),
                ),
              ),
            ),
            Positioned(
              right: 90,
              bottom: 10,
              child: Icon(
                Icons.location_on_rounded,
                size: 44,
                color: Colors.white.withAlpha(22),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: padV),
              child: _locationContent(gap),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationContent(double gap) {
    return Column(
        children: [
          Row(
            children: [
              const IconBox(
                icon: Icons.my_location_rounded,
                size: 62,
                bg: AppColors.greenLight,
                fg: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lokasi terdeteksi',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC9DCCF),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _locationText,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _open(
                  context,
                  const KecocokanLahanScreen(),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Lihat',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.eco_rounded, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '3 jenis tanaman cocok di sekitar Anda',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }

  Widget _buildGrid(double tileW, double tileH, double boxSize) {
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: _gridGap,
      runSpacing: _gridGap + 4,
      children: [
        for (final f in _features)
          SizedBox(
            width: tileW,
            height: tileH,
            child: _buildTile(f, boxSize),
          ),
      ],
    );
  }

  Widget _buildTile(_Feature f, double boxSize) {
    const ink = Color(0xFF1E4D3A);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (f.page != null) {
          _open(context, f.page!);
        } else {
          showSoon(context, '${f.label} segera hadir');
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(boxSize * 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E4D3A).withAlpha(28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(f.icon, size: boxSize * 0.38, color: ink),
              ),
              if (f.label == 'FlorAI')
                Positioned(
                  right: -4,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            f.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: f.label == 'FlorAI' ? AppColors.green : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
