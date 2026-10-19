import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

class LogBlockItem {
  final int blockNumber;
  final String category; // 'Tanam', 'Pupuk', 'Panen'
  final String title;
  final String date;
  final String hash;
  final String prevHash;

  const LogBlockItem({
    required this.blockNumber,
    required this.category,
    required this.title,
    required this.date,
    required this.hash,
    required this.prevHash,
  });
}

class LogPemeliharaanScreen extends StatefulWidget {
  const LogPemeliharaanScreen({super.key});

  @override
  State<LogPemeliharaanScreen> createState() => _LogPemeliharaanScreenState();
}

class _LogPemeliharaanScreenState extends State<LogPemeliharaanScreen> {
  String _selectedFilter = 'Semua';

  final List<LogBlockItem> _logs = const [
    LogBlockItem(
      blockNumber: 12,
      category: 'Panen',
      title: 'Panen cabai rawit Petak A, 18 kg',
      date: '17 Okt 2026, 07.40',
      hash: '9c4e7a...b13f',
      prevHash: '51d8a2...e87c',
    ),
    LogBlockItem(
      blockNumber: 11,
      category: 'Pupuk',
      title: 'Pupuk NPK 16–16–16, 2 kg, Petak A',
      date: '02 Okt 2026, 06.15',
      hash: '51d8a2...e87c',
      prevHash: 'a3f9d1...c21e',
    ),
    LogBlockItem(
      blockNumber: 10,
      category: 'Tanam',
      title: 'Tanam bibit cabai rawit, 120 batang',
      date: '12 Agu 2026, 16.05',
      hash: 'a3f9d1...c21e',
      prevHash: '7be204...90aa',
    ),
  ];

  List<LogBlockItem> get _filteredLogs {
    if (_selectedFilter == 'Semua') return _logs;
    if (_selectedFilter == 'Log Tanam')
      return _logs.where((e) => e.category == 'Tanam').toList();
    if (_selectedFilter == 'Log Pupuk')
      return _logs.where((e) => e.category == 'Pupuk').toList();
    if (_selectedFilter == 'Log Panen')
      return _logs.where((e) => e.category == 'Panen').toList();
    return _logs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Log Pemeliharaan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: const AppBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form Tambah Log Tanam / Blockchain')),
          );
        },
        backgroundColor: const Color(0xFF1E5B3E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Catat log',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Search Bar & Filter Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari log atau hash',
                      hintStyle:
                          const TextStyle(fontSize: 13, color: AppColors.muted),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: AppColors.muted),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.green),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5B3E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.tune, color: Colors.white),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),

            // Chips Filter Category
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Log Tanam', 'Log Pupuk', 'Log Panen']
                    .map((label) {
                  final selected = _selectedFilter == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              color: selected ? Colors.white : Colors.black)),
                      selected: selected,
                      selectedColor: const Color(0xFF1E5B3E),
                      backgroundColor: Colors.white,
                      onSelected: (_) =>
                          setState(() => _selectedFilter = label),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Banner Blockchain Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5EFE6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.greenSoft),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Color(0xFF1E5B3E), shape: BoxShape.circle),
                    child:
                        const Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rantai valid, 12 blok terverifikasi',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E5B3E))),
                        SizedBox(height: 2),
                        Text('Setiap blok memuat hash blok sebelumnya',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Timeline Blocks
            ..._filteredLogs.map((item) => _buildBlockCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCard(LogBlockItem item) {
    Color badgeColor = Colors.green;
    if (item.category == 'Panen') badgeColor = Colors.orange;
    if (item.category == 'Pupuk') badgeColor = Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Blok #${item.blockNumber}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.category,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor),
                    ),
                  ),
                ],
              ),
              Text(item.date,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          // Hash Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'hash: ${item.hash}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
