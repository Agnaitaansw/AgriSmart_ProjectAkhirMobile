import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/auth_widgets.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService.instance;

  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prefill();
    _auth.syncPending(); // kirim akun offline ke server bila sudah online
  }

  Future<void> _prefill() async {
    final last = await _auth.lastIdentifier();
    if (last != null && mounted) _idCtrl.text = last;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()));
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await _auth.login(
      identifier: _idCtrl.text,
      password: _passCtrl.text,
      remember: _remember,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!res.ok) {
      showSnack(context, res.message, error: true);
      return;
    }

    // Tawarkan aktivasi biometrik setelah login password pertama.
    if (await _auth.isBiometricAvailable() && !await _auth.isBiometricEnabled()) {
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Aktifkan login biometrik?'),
          content: const Text(
              'Lain kali kamu bisa masuk cepat dengan sidik jari atau pengenalan wajah.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Nanti')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Aktifkan')),
          ],
        ),
      );
      if (yes == true) await _auth.enableBiometric(res.user!.id!);
    }
    if (mounted) _goHome();
  }

  Future<void> _biometric() async {
    setState(() => _loading = true);
    final res = await _auth.loginWithBiometric(remember: _remember);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.ok) {
      _goHome();
    } else {
      showSnack(context, res.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: AuthTitle(
                        title: 'Selamat Datang',
                        subtitle:
                            'Cocokkan lahan dan kenali penyakit tanaman dengan lokasi dan AI.',
                      ),
                    ),
                    const SizedBox(height: 22),
                    AuthTextField(
                      label: 'Email atau username',
                      hint: 'Username / email',
                      icon: Icons.person_outline,
                      controller: _idCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      label: 'Password',
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      controller: _passCtrl,
                      obscure: _obscure,
                      textInputAction: TextInputAction.done,
                      suffix: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Checkbox(
                            value: _remember,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => _remember = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Tetap masuk', style: TextStyle(fontSize: 12.5)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => showSnack(context,
                              'Fitur lupa password belum tersedia (butuh endpoint reset di server).'),
                          child: const Text('Lupa password?',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(text: 'Masuk', loading: _loading, onPressed: _login),
                    const SizedBox(height: 18),
                    Row(children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('atau masuk cepat',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: _BioButton(
                                icon: Icons.fingerprint,
                                label: 'Sidik jari',
                                onTap: _loading ? null : _biometric)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _BioButton(
                                icon: Icons.face_retouching_natural,
                                label: 'Pengenalan wajah',
                                onTap: _loading ? null : _biometric)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Belum punya akun? ',
                              style: TextStyle(fontSize: 12.5)),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const RegisterPage())),
                            child: const Text('Register',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.infoBox,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.lock_outline,
                              size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Password dienkripsi dengan hashing di server. '
                              'Sesi login tersimpan aman di penyimpanan lokal perangkat.',
                              style: TextStyle(fontSize: 11.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BioButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _BioButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
