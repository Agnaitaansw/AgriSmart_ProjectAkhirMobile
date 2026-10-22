import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

class BlockchainLogScreen extends StatefulWidget {
  const BlockchainLogScreen({super.key});

  @override
  State<BlockchainLogScreen> createState() => _BlockchainLogScreenState();
}

class _BlockchainLogScreenState extends State<BlockchainLogScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBlockchainLogs();
  }

  Future<void> _fetchBlockchainLogs() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Mengambil data dari tabel blockchain_logs sesuai kolom di database
      final response = await _supabase
          .from('blockchain_logs')
          .select()
          .order('id', ascending: false);

      setState(() {
        _logs = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR SUPABASE BLOCKCHAIN: $e');
      setState(() {
        _errorMessage = 'Gagal memuat log: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Riwayat Perolehan Poin (Blockchain)',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: _fetchBlockchainLogs,
        ),
      ],
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Terverifikasi aman menggunakan SHA-256 Distributed Ledger',
            style: TextStyle(fontSize: 10, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: AppColors.green),
            ),
          )
        else if (_errorMessage != null)
          AppCard(
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _fetchBlockchainLogs,
                  child: const Text('Coba Lagi', style: TextStyle(color: AppColors.green)),
                ),
              ],
            ),
          )
        else if (_logs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Belum ada riwayat transaksi blockchain.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          )
        else
          for (var log in _logs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (log['points_amount'] ?? 0) >= 0 ? AppColors.greenSoft : Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        (log['points_amount'] ?? 0) >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                        color: (log['points_amount'] ?? 0) >= 0 ? AppColors.green : Colors.red,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(log['points_amount'] ?? 0) >= 0 ? '+' : ''}${log['points_amount']} poin',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: (log['points_amount'] ?? 0) >= 0 ? AppColors.green : Colors.red,
                                ),
                              ),
                              Text(log['timestamp'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(log['action_type'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Hash: ${log['current_hash'] ?? '0x0000...0000'}',
                            style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}