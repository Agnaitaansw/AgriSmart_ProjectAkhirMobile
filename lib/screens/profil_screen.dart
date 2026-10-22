import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
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
  String? _photoPath;
  UserModel? _user;

  String get _userKey {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return userId ?? 'guest';
  }

  String get _displayName {
    final appName = _user?.name;
    if (appName != null && appName.trim().isNotEmpty) {
      return appName.trim();
    }
    final user = Supabase.instance.client.auth.currentUser;
    final metadataName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }
    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Pengguna AgriSmart';
  }

  String get _email {
    final appEmail = _user?.email;
    if (appEmail != null && appEmail.trim().isNotEmpty) {
      return appEmail.trim();
    }
    return Supabase.instance.client.auth.currentUser?.email ??
        'Email belum tersedia';
  }

  String get _bioPreferenceKey => 'biometric_enabled_$_userKey';
  String get _photoPreferenceKey => 'profile_photo_$_userKey';
  String get _notificationPreferenceKey => 'plant_notifications_$_userKey';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final appUser = await AuthService.instance.currentUser();
    if (!mounted) return;
    setState(() {
      _user = appUser;
      _bioEnabled = prefs.getBool(_bioPreferenceKey) ?? false;
      _notiEnabled = prefs.getBool(_notificationPreferenceKey) ?? true;
      _photoPath = prefs.getString(_photoPreferenceKey);
      _loading = false;
    });
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'Pilih foto profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final extension = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      // Nama file unik tiap ganti foto, supaya cache gambar Flutter tidak
      // menampilkan foto lama dan notifier benar-benar terpicu.
      final savedFile = await File(picked.path).copy(
        '${directory.path}/profile_${_userKey}_'
        '${DateTime.now().millisecondsSinceEpoch}$extension',
      );

      final prefs = await SharedPreferences.getInstance();
      final oldPath = prefs.getString(_photoPreferenceKey);
      await prefs.setString(_photoPreferenceKey, savedFile.path);

      if (oldPath != null && oldPath != savedFile.path) {
        try {
          final oldFile = File(oldPath);
          if (await oldFile.exists()) await oldFile.delete();
        } catch (_) {}
      }

      profilePhotoNotifier.value = savedFile.path;

      if (!mounted) return;
      setState(() => _photoPath = savedFile.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e')),
      );
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
          localizedReason: 'Verifikasi identitas untuk mengaktifkan login biometrik AgriSmart',
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

  @override
  Widget build(BuildContext context) {
    final photoExists = _photoPath != null && File(_photoPath!).existsSync();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _changePhoto,
                          customBorder: const CircleBorder(),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: AppColors.greenSoft,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.green,
                                    width: 2,
                                  ),
                                  image: photoExists
                                      ? DecorationImage(
                                          image: FileImage(File(_photoPath!)),
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
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.green,
                                          ),
                                        ),
                                      ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E5B3E),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _changePhoto,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            side: const BorderSide(color: AppColors.green),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Ganti foto dari galeri atau kamera',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Login biometrik',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Sidik jari atau wajah',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          value: _bioEnabled,
                          activeColor: const Color(0xFF1E5B3E),
                          onChanged: _setBiometric,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text(
                            'Notifikasi game',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'siram tanamanmu dan dapatkan poin sebanyak-banyaknya',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          value: _notiEnabled,
                          activeColor: const Color(0xFF1E5B3E),
                          onChanged: _setNotifications,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.yard_outlined,
                            color: AppColors.green,
                          ),
                          title: const Text(
                            'Tanaman Saya',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text(
                            'Kelola informasi tanaman milikmu',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TanamanSayaScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          title: Text(
                            'Sinkronisasi data',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Data profil dan tanaman tersimpan di perangkat',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          trailing: Icon(
                            Icons.check_circle,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => showLogoutConfirmation(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC0392B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Keluar dari akun',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}