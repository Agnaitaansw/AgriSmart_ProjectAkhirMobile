import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/blockchain_config.dart';
import '../services/blockchain_service.dart';
import '../services/sesi_user.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

class BlockchainLogScreen extends StatefulWidget {
  const BlockchainLogScreen({super.key});

  @override
  State<BlockchainLogScreen> createState() => _BlockchainLogScreenState();
}

class _BlockchainLogScreenState extends State<BlockchainLogScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  String? _errorMessage;
  StatusOnChain? _status;

  Future<void> _muatStatus() async {
    final s = await BlockchainService.statusOnChain(await idUserLogin());
    if (!mounted) return;
    setState(() => _status = s);
  }

  String _pendekkan(String h) =>
      h.length > 18 ? '${h.substring(0, 10)}...${h.substring(h.length - 6)}' : h;

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

      final response =
          await BlockchainService.ambilRiwayat(await idUserLogin());

      unawaited(BlockchainService.sinkronkan().whenComplete(() {
        if (mounted) setState(() {}); // tampilkan error kalau ada
      }));
      unawaited(_muatStatus());

      if (!mounted) return;
      setState(() {
        _logs = response;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR BLOCKCHAIN LOG: $e');
      if (!mounted) return;
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
            'Dicatat lewat smart contract di jaringan Ethereum Sepolia (testnet)',
            style: TextStyle(fontSize: 10, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
        if (BlockchainService.errorTerakhir != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: SelectableText(
                'Gagal kirim ke blockchain:\n${BlockchainService.errorTerakhir}',
                style: const TextStyle(fontSize: 10, color: Colors.red),
                maxLines: 8,
              ),
            ),
          ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Text(
                'Saldo di blockchain: ${_status!.saldo} poin  •  '
                '${_status!.jumlah} catatan  •  '
                '${_status!.valid ? 'Rantai valid ✓' : 'Rantai TIDAK valid ✗'}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
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
                          Builder(builder: (context) {
                            final tx = (log['tx_hash'] ?? '') as String;
                            final selesai = log['synced'] == 1;
                            final String teks;
                            if (tx.isNotEmpty && selesai) {
                              teks = '✓ Terkonfirmasi  Tx: ${_pendekkan(tx)}  (ketuk untuk salin link)';
                            } else if (tx.isNotEmpty) {
                              teks = '⏳ Menunggu konfirmasi jaringan  Tx: ${_pendekkan(tx)}';
                            } else if (selesai) {
                              teks = 'Catatan lama (sebelum blockchain sungguhan)';
                            } else {
                              teks = '⏳ Antre dikirim ke blockchain';
                            }
                            return GestureDetector(
                              onTap: tx.isEmpty
                                  ? null
                                  : () {
                                      Clipboard.setData(ClipboardData(
                                          text: '${BlockchainConfig.explorerTx}$tx'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text('Link Etherscan disalin')));
                                    },
                              child: Text(
                                teks,
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.grey, fontFamily: 'monospace'),
                              ),
                            );
                          }),
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