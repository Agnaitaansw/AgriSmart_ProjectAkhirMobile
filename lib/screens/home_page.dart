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
  const _Feature(this.label, this.icon, [this.page]);

  final String label;
  final IconData icon;
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
    _Feature('Lahan', Icons.landscape_outlined, KecocokanLahanScreen()),
    _Feature('FlorAI', Icons.local_florist_outlined, DiagnosaScreen()),
    _Feature('Harga Ekspor', Icons.show_chart, HargaEksporScreen()),
    _Feature(
      'Mini Game',
      Icons.sports_esports_outlined,
      SimulasiPenyiramanScreen(),
    ),
    _Feature('Waterpass', Icons.straighten, KemiringanLahanScreen()),
    _Feature('Poin', Icons.menu_book_outlined, const BlockchainLogScreen()),
    _Feature('Tanaman', Icons.spa_outlined, const TanamanScreen()),
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

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: u == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Halo, ${u.name}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _open(context, const ProfilScreen()),
                        child: ValueListenableBuilder<String?>(
                          valueListenable: profilePhotoNotifier,
                          builder: (context, photoPath, _) {
                            final hasPhoto = photoPath != null &&
                                File(photoPath).existsSync();

                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.greenSoft,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.green,
                                  width: 1.2,
                                ),
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
                                      Icons.person_outline,
                                      color: AppColors.green,
                                      size: 20,
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Kartu Lokasi
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const IconBox(
                          icon: Icons.location_on_outlined,
                          size: 40,
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
                                  fontSize: 10,
                                  color: Color(0xFFC9DCCF),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _locationText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '3 jenis tanaman cocok di sekitar Anda',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFC9DCCF),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Lihat',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Fitur Utama
                  const Text(
                    'Fitur utama',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _features.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, i) {
                      final f = _features[i];

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (f.page != null) {
                            _open(context, f.page!);
                          } else {
                            showSoon(
                              context,
                              '${f.label} segera hadir',
                            );
                          }
                        },
                        child: Column(
                          children: [
                            IconBox(
                              icon: f.icon,
                              size: 54,
                              radius: 14,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              f.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
    );
  }
}