import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../utils/constants.dart';
import 'logout_dialog.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  bool _bioEnabled = true;
  bool _notiEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar & Info
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.green, width: 2),
                        ),
                        child: const Center(
                          child: Text(
                            'J',
                            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.green),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E5B3E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Jenoganteng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('jenoganteng@gmail.com', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: const BorderSide(color: AppColors.green),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Ganti foto dari galeri atau kamera',
                        style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

    

            // Setelan Akun & Fitur
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Login biometrik', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Sidik jari atau wajah', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    value: _bioEnabled,
                    activeColor: const Color(0xFF1E5B3E),
                    onChanged: (v) => setState(() => _bioEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Notifikasi perawatan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Penyiraman dan pemupukan', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    value: _notiEnabled,
                    activeColor: const Color(0xFF1E5B3E),
                    onChanged: (v) => setState(() => _notiEnabled = v),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Sinkronisasi data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Terakhir 03.20 WIB, via REST API', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Sinkron',
                          style: TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol Logout
            ElevatedButton.icon(
              onPressed: () => showLogoutConfirmation(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0392B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout, color: Colors.white, size: 18),
              label: const Text('Keluar dari akun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E5B3E))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}