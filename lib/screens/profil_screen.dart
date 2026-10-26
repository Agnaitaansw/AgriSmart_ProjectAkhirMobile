import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';
import 'logout_dialog.dart';
import 'tanaman_saya_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final ImagePicker _imagePicker = ImagePicker();

  bool _bioEnabled = false;
  bool _notiEnabled = true;
  bool _loading = true;
  bool _uploadingPhoto = false;

  String? _photoUrl;
  UserModel? _user;

  String get _userKey => _user?.id?.toString() ?? 'guest';

  String get _displayName {
    final name = _user?.name;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Pengguna AgriSmart';
  }

  String get _email {
    final email = _user?.email;
    if (email != null && email.trim().isNotEmpty) {
      return email.trim();
    }
    return 'Email belum tersedia';
  }

  String get _bioPreferenceKey => 'biometric_enabled_$_userKey';
  String get _notificationPreferenceKey =>
      'plant_notifications_$_userKey';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final appUser = await AuthService.instance.currentUser();

      if (!mounted) return;

      if (appUser == null) {
        setState(() => _loading = false);
        return;
      }

      _user = appUser;

      String? photoUrl;

      // Ambil URL foto berdasarkan email akun lokal yang sedang login.
      try {
        final row = await Supabase.instance.client
            .from('users')
            .select('profile_picture_url')
            .eq('email', appUser.email)
            .maybeSingle();

        photoUrl = row?['profile_picture_url'] as String?;
      } catch (_) {
        // Jika internet/database belum tersedia, lanjutkan tanpa foto online.
      }

      if (!mounted) return;

      // Sinkronkan foto profil dengan Home Page.
      profilePhotoNotifier.value = photoUrl;

      setState(() {
        _photoUrl = photoUrl;
        _bioEnabled = prefs.getBool(_bioPreferenceKey) ?? false;
        _notiEnabled =
            prefs.getBool(_notificationPreferenceKey) ?? true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Gagal memuat profil: $e');
    }
  }

  Future<void> _changePhoto() async {
    // Mengambil user dari sesi login AgriSmart, bukan Supabase Auth.
    final currentUser = await AuthService.instance.currentUser();

    if (!mounted) return;

    if (currentUser == null || currentUser.id == null) {
      _showMessage(
        'Sesi login tidak ditemukan. Silakan login kembali.',
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'Pilih foto profil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () =>
                  Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () =>
                  Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      setState(() => _uploadingPhoto = true);

      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      final extension = picked.name.contains('.')
          ? picked.name
              .substring(picked.name.lastIndexOf('.') + 1)
              .toLowerCase()
          : 'jpg';

      final safeExtension =
          ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
              ? extension
              : 'jpg';

      final userId = currentUser.id!;

      // Foto disimpan berdasarkan ID user lokal AgriSmart.
      final storagePath =
          '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

      final storage =
          Supabase.instance.client.storage.from('profile-photos');

      await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: picked.mimeType ??
              (safeExtension == 'jpg'
                  ? 'image/jpeg'
                  : 'image/$safeExtension'),
        ),
      );

      final photoUrl = storage.getPublicUrl(storagePath);

      // Simpan URL ke database online, bukan hanya ke perangkat.
      await Supabase.instance.client
          .from('users')
          .update({'profile_picture_url': photoUrl})
          .eq('email', currentUser.email);

      if (!mounted) return;

      setState(() => _photoUrl = photoUrl);

      // Notifier lama dipertahankan untuk kompatibilitas.
      // Jika widget lain menganggap nilainya selalu berupa path file,
      // sesuaikan widget tersebut agar bisa membaca URL jaringan.
      profilePhotoNotifier.value = photoUrl;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan foto profil: $e');
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    if (enabled) {
      try {
        final supported = await _localAuth.isDeviceSupported();
        final canCheck = await _localAuth.canCheckBiometrics;
        final available = await _localAuth.getAvailableBiometrics();

        if (!supported || !canCheck || available.isEmpty) {
          _showMessage(
            'Perangkat belum memiliki biometrik yang siap digunakan. '
            'Atur sidik jari atau pengenalan wajah di pengaturan perangkat.',
          );
          return;
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason:
              'Verifikasi identitas untuk mengaktifkan login biometrik AgriSmart',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (!authenticated) return;
      } catch (e) {
        _showMessage('Biometrik tidak dapat diaktifkan: $e');
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bioPreferenceKey, enabled);

    if (!mounted) return;

    setState(() => _bioEnabled = enabled);

    _showMessage(
      enabled
          ? 'Login biometrik diaktifkan pada perangkat ini.'
          : 'Login biometrik dinonaktifkan.',
    );
  }

  Future<void> _setNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_notificationPreferenceKey, enabled);

    if (!mounted) return;

    setState(() => _notiEnabled = enabled);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  static const _ink = Color(0xFF1E5B3E);
  static const double _maxWidth = 520;

  @override
  Widget build(BuildContext context) {
    final photoUrl = _photoUrl;
    final photoExists = photoUrl != null && photoUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final avatar =
                      (constraints.maxWidth * 0.27).clamp(84.0, 116.0);
                  final totalH = constraints.maxHeight < 640
                      ? 640.0
                      : constraints.maxHeight;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _maxWidth),
                        child: SizedBox(
                          height: totalH,
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            // Sisa tinggi dibagi lewat Spacer supaya
                            // tata letak merata di semua ukuran layar.
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildProfileHeader(
                                  avatar,
                                  photoUrl,
                                  photoExists,
                                ),
                                const Spacer(flex: 2),
                                _sectionLabel('KEAMANAN & NOTIFIKASI'),
                                const SizedBox(height: 8),
                                _buildSecurityCard(),
                                const Spacer(flex: 2),
                                _sectionLabel('KELOLA DATA TANAMAN'),
                                const SizedBox(height: 8),
                                _buildDataCard(),
                                const Spacer(flex: 3),
                                _buildLogoutButton(),
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

  Widget _buildProfileHeader(
    double avatar,
    String? photoUrl,
    bool photoExists,
  ) {
    return Column(
      children: [
        InkWell(
          onTap: _uploadingPhoto ? null : _changePhoto,
          customBorder: const CircleBorder(),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: avatar,
                height: avatar,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.green, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withAlpha(50),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  image: photoExists
                      ? DecorationImage(
                          image: NetworkImage(photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoExists
                    ? null
                    : Center(
                        child: Text(
                          _displayName.isNotEmpty
                              ? _displayName[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            fontSize: avatar * 0.4,
                            fontWeight: FontWeight.bold,
                            color: AppColors.green,
                          ),
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _uploadingPhoto
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.white,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              _displayName,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Petani Aktif',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          _email,
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _uploadingPhoto ? null : _changePhoto,
          icon: const Icon(
            Icons.photo_camera_outlined,
            size: 16,
            color: AppColors.green,
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            side: const BorderSide(color: AppColors.green),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          label: const Text(
            'Ganti foto dari galeri atau kamera',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(const Divider(height: 1, indent: 68, endIndent: 14));
      }
      items.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            IconBox(icon: icon, size: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: _ink,
    );
  }

  Widget _buildSecurityCard() {
    return _card([
      _tile(
        icon: Icons.fingerprint,
        title: 'Login Biometrik',
        subtitle: 'Gunakan sidik jari atau pemindai wajah',
        trailing: _switch(_bioEnabled, _setBiometric),
        onTap: () => _setBiometric(!_bioEnabled),
      ),
      _tile(
        icon: Icons.notifications_none_rounded,
        title: 'Notifikasi Game & Kebun',
        subtitle: 'Siram tanamanmu dan kumpulkan poin panen',
        trailing: _switch(_notiEnabled, _setNotifications),
        onTap: () => _setNotifications(!_notiEnabled),
      ),
    ]);
  }

  Widget _buildDataCard() {
    return _card([
      _tile(
        icon: Icons.yard_outlined,
        title: 'Tanaman Saya',
        subtitle: 'Kelola informasi tanaman milikmu',
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TanamanSayaScreen()),
          );
        },
      ),
      _tile(
        icon: Icons.sync_rounded,
        title: 'Sinkronisasi Data',
        subtitle: 'Foto profil tersimpan di database online',
        trailing: const Icon(Icons.check_circle, color: AppColors.green),
      ),
    ]);
  }

  Widget _buildLogoutButton() {
    return ElevatedButton.icon(
      onPressed: () => showLogoutConfirmation(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC0392B),
        elevation: 4,
        shadowColor: const Color(0xFFC0392B).withAlpha(120),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.logout, color: Colors.white, size: 18),
      label: const Text(
        'Keluar dari akun',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
