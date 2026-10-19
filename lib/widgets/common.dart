import 'package:flutter/material.dart';
import '../utils/constants.dart';

void showSoon(BuildContext context, [String msg = 'Fitur ini segera hadir']) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
}

/// Menggambar path putus-putus (dipakai peta dan tombol "Tambah jadwal").
void drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 6,
  double gap = 5,
}) {
  for (final metric in path.computeMetrics()) {
    double d = 0;
    while (d < metric.length) {
      final end = (d + dash).clamp(0, metric.length).toDouble();
      canvas.drawPath(metric.extractPath(d, end), paint);
      d += dash + gap;
    }
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = Colors.white,
    this.borderColor = AppColors.border,
    this.borderWidth = 1,
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: child,
    );
  }
}

class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    this.size = 44,
    this.bg = AppColors.greenSoft,
    this.fg = AppColors.green,
    this.radius = 12,
  });

  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: fg, size: size * 0.5),
    );
  }
}

/// Deretan chip (Semua / Tanaman / ...) yang bisa dipilih satu.
class PillChips extends StatefulWidget {
  const PillChips({
    super.key,
    required this.labels,
    this.initial = 0,
    this.onChanged,
  });

  final List<String> labels;
  final int initial;
  final ValueChanged<int>? onChanged;

  @override
  State<PillChips> createState() => _PillChipsState();
}

class _PillChipsState extends State<PillChips> {
  late int _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < widget.labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selected = i);
                  widget.onChanged?.call(i);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _selected == i ? AppColors.green : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selected == i
                          ? AppColors.green
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    widget.labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selected == i ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    super.key,
    required this.child,
    this.color = AppColors.green,
    this.radius = 12,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color, radius),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.6),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    drawDashedPath(canvas, Path()..addRRect(rrect), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Beranda',
                selected: true,
                onTap: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Profil',
                onTap: () => showSoon(context),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                label: 'Saran P&M',
                onTap: () => showSoon(context),
              ),
              _NavItem(
                icon: Icons.logout,
                label: 'Logout',
                onTap: () => showSoon(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? AppColors.greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kerangka layar dalam: app bar dengan tombol kembali + bottom nav.
class SubPageScaffold extends StatelessWidget {
  const SubPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: actions,
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: children,
      ),
    );
  }
}
