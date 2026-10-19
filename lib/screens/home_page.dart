import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';

/// Halaman contoh setelah login: menampilkan data session & toggle biometrik.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthService.instance;
  UserModel? _user;
  DateTime? _expiry;
  bool _bioEnabled = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await _auth.currentUser();
    final e = await _auth.sessionExpiry();
    final en = await _auth.isBiometricEnabled();
    final av = await _auth.isBiometricAvailable();
    if (!mounted) return;
    if (u == null) return _logout();
    setState(() {
      _user = u;
      _expiry = e;
      _bioEnabled = en;
      _bioAvailable = av;
    });
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      final ok = await _auth.enableBiometric(_user!.id!);
      if (!ok && mounted) {
        showSnack(context, 'Gagal mengaktifkan biometrik', error: true);
      }
    } else {
      await _auth.disableBiometric();
    }
    _load();
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AgriSmart'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: u == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Halo, ${u.name}!',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('@${u.username} • ${u.email}',
                    style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined,
                        color: AppColors.primary),
                    title: const Text('Session berlaku sampai'),
                    subtitle: Text(_expiry?.toLocal().toString().split('.').first ?? '-'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: Icon(
                        u.synced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                        color: AppColors.primary),
                    title: const Text('Sinkronisasi database online'),
                    subtitle: Text(u.synced
                        ? 'Akun sudah tersinkron'
                        : 'Menunggu koneksi untuk sinkronisasi'),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    secondary:
                        const Icon(Icons.fingerprint, color: AppColors.primary),
                    title: const Text('Login biometrik'),
                    subtitle: Text(_bioAvailable
                        ? 'Masuk dengan sidik jari / wajah'
                        : 'Tidak tersedia di perangkat ini'),
                    value: _bioEnabled,
                    activeColor: AppColors.primary,
                    onChanged: _bioAvailable ? _toggleBio : null,
                  ),
                ),
              ],
            ),
    );
  }
}
