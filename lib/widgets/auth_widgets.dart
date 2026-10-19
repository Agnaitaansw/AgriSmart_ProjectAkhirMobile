import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/constants.dart';

/// Header melengkung (desain 2) + logo daun (desain 1).
class AuthHeader extends StatelessWidget {
  final double height;
  const AuthHeader({super.key, this.height = 220});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF123D29), AppColors.primary, Color(0xFF5C8F5A)],
              ),
            ),
            child: Align(
              alignment: const Alignment(0, -0.2),
              child: Icon(Icons.eco_rounded,
                  size: 96, color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ),
        Positioned(
          right: -18,
          top: height - 70,
          child: Transform.rotate(
            angle: 0.6,
            child: Icon(Icons.eco_rounded,
                size: 64, color: AppColors.primaryLight.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..lineTo(0, size.height - 40);
    p.quadraticBezierTo(
        size.width * 0.25, size.height + 20, size.width * 0.55, size.height - 25);
    p.quadraticBezierTo(
        size.width * 0.85, size.height - 70, size.width, size.height - 35);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Logo kotak hijau + judul "AgriSmart" (desain 1).
class AuthTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.eco_outlined, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 10),
        Text('AgriSmart',
            style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Field dengan label di atas & ikon (gabungan desain 1 + 2).
class AuthTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.field,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: border(AppColors.fieldBorder),
            focusedBorder: border(AppColors.primary, 1.6),
            errorBorder: border(Colors.red.shade400),
            focusedErrorBorder: border(Colors.red.shade400, 1.6),
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton(
      {super.key, required this.text, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white))
            : Text(text,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Colors.red.shade700 : AppColors.primary,
    ));
}
