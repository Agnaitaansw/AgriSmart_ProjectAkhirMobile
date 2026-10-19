import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _userCtrl, _emailCtrl, _passCtrl, _confirmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final res = await AuthService.instance.register(
      name: _nameCtrl.text,
      username: _userCtrl.text,
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    showSnack(context, res.message, error: !res.ok);
    if (res.ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20),
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(children: [
              const AuthHeader(height: 190),
              SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const AuthTitle(
                      title: 'Buat Akun',
                      subtitle: 'Daftar untuk mulai menggunakan AgriSmart.',
                    ),
                    const SizedBox(height: 20),
                    AuthTextField(
                      label: 'Nama lengkap',
                      hint: 'Nama lengkap',
                      icon: Icons.badge_outlined,
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Minimal 3 karakter'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    AuthTextField(
                      label: 'Username',
                      hint: 'Username',
                      icon: Icons.person_outline,
                      controller: _userCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.length < 4) return 'Minimal 4 karakter';
                        if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(s)) {
                          return 'Hanya huruf, angka, _ dan .';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AuthTextField(
                      label: 'Email',
                      hint: 'nama@email.com',
                      icon: Icons.mail_outline,
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Email tidak valid',
                    ),
                    const SizedBox(height: 12),
                    AuthTextField(
                      label: 'Password',
                      hint: 'Minimal 8 karakter',
                      icon: Icons.lock_outline,
                      controller: _passCtrl,
                      obscure: _obscure,
                      suffix: eye,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final s = v ?? '';
                        if (s.length < 8) return 'Minimal 8 karakter';
                        if (!RegExp(r'[A-Za-z]').hasMatch(s) ||
                            !RegExp(r'\d').hasMatch(s)) {
                          return 'Harus mengandung huruf dan angka';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AuthTextField(
                      label: 'Konfirmasi password',
                      hint: 'Ulangi password',
                      icon: Icons.lock_reset_outlined,
                      controller: _confirmCtrl,
                      obscure: _obscure,
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          v != _passCtrl.text ? 'Password tidak sama' : null,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                        text: 'Daftar', loading: _loading, onPressed: _register),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Sudah punya akun? ',
                            style: TextStyle(fontSize: 12.5)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text('Login',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ),
                      ],
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
