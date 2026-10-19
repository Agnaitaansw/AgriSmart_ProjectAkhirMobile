import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common.dart';

class _Schedule {
  _Schedule(this.name, this.detail, this.on);

  final String name;
  final String detail;
  bool on;
}

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  int _tab = 0;

  final List<List<_Schedule>> _schedules = [
    [
      _Schedule('Cabai rawit, Petak A', 'Setiap hari, 06.00 WIB', true),
      _Schedule('Jagung, Petak B', 'Selasa dan Jumat, 15.30 WIB', true),
      _Schedule('Tomat, Petak C', 'Setiap 2 hari, 07.00 WIB', false),
    ],
    [
      _Schedule('Cabai rawit, Petak A', 'Setiap 2 minggu, 07.00 WIB', true),
      _Schedule('Jagung, Petak B', 'Setiap 3 minggu, 07.00 WIB', true),
      _Schedule('Tomat, Petak C', 'Setiap bulan, 07.00 WIB', false),
    ],
  ];

  static const _tabs = ['Penyiraman', 'Pemupukan'];

  void _addSchedule() {
    final list = _schedules[_tab];
    final petak = String.fromCharCode('A'.codeUnitAt(0) + list.length);
    setState(() {
      list.add(_Schedule('Tanaman baru, Petak $petak', 'Setiap hari, 06.00 WIB', true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _schedules[_tab];
    final icon =
        _tab == 0 ? Icons.water_drop_outlined : Icons.grass;

    return SubPageScaffold(
      title: 'Jadwal Perawatan',
      children: [
        const Text('Contoh notifikasi di perangkat',
            style: TextStyle(fontSize: 10, color: AppColors.muted)),
        const SizedBox(height: 6),

        // Banner notifikasi
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showSoon(context, 'Mini game penyiraman segera hadir'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                IconBox(
                  icon: Icons.eco,
                  size: 34,
                  bg: AppColors.greenLight,
                  fg: Colors.white,
                  radius: 10,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AgriSmart, sekarang',
                          style: TextStyle(
                              fontSize: 9, color: Color(0xFFC9DCCF))),
                      SizedBox(height: 2),
                      Text('Waktunya menyiram cabai',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      SizedBox(height: 2),
                      Text('Ketuk untuk membuka mini game penyiraman',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFFC9DCCF))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Tab
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tab == i ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _tab == i ? AppColors.border : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              _tab == i ? FontWeight.w700 : FontWeight.w500,
                          color: _tab == i ? AppColors.green : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Daftar jadwal
        for (final s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconBox(
                    icon: icon,
                    size: 34,
                    bg: AppColors.amberSoft,
                    fg: AppColors.amber,
                    radius: 10,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(s.detail,
                            style: const TextStyle(
                                fontSize: 10.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: s.on,
                    onChanged: (v) => setState(() => s.on = v),
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.green,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFC9CFC4),
                    trackOutlineColor:
                        WidgetStateProperty.all(Colors.transparent),
                  ),
                ],
              ),
            ),
          ),

        // Tambah jadwal
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _addSchedule,
          child: const DashedBorderBox(
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: AppColors.green),
                  SizedBox(width: 6),
                  Text('Tambah jadwal',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
