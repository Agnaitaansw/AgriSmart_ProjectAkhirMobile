import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web3dart/web3dart.dart';

import 'blockchain_config.dart';
import 'db_helper.dart';

/// Ringkasan data user yang dibaca langsung dari smart contract.
class StatusOnChain {
  final BigInt saldo;
  final BigInt jumlah;
  final bool valid;
  const StatusOnChain(this.saldo, this.jumlah, this.valid);
}

/// Riwayat poin di blockchain Sepolia lewat smart contract PoinLedger.
///
/// Alur (offline-first):
///  1. catat() -> simpan ke SQLite dulu (synced = 0), supaya aplikasi tetap cepat
///  2. sinkronkan() -> kirim transaksi ke kontrak, simpan tx_hash, tunggu
///     konfirmasi jaringan, lalu salin ke Supabase dan tandai synced = 1
///
/// Simpan di: lib/services/blockchain_service.dart
class BlockchainService {
  BlockchainService._();

  static const String tipePemasukan = 'pemasukan';
  static const String tipePengeluaran = 'pengeluaran';

  static final String _hashAwal = '0' * 64;
  static bool _sedangSinkron = false;
  static bool _perluUlang = false;

  /// Alasan kegagalan terakhir (ditampilkan di layar riwayat). null = tidak ada masalah.
  static String? errorTerakhir;

  static Web3Client? _klien;
  static Web3Client get _web3 =>
      _klien ??= Web3Client(BlockchainConfig.rpcUrl, http.Client());

  static final DeployedContract _kontrak = DeployedContract(
    ContractAbi.fromJson(BlockchainConfig.abi, 'PoinLedger'),
    EthereumAddress.fromHex(BlockchainConfig.contractAddress),
  );

  static EthPrivateKey get _dompet =>
      EthPrivateKey.fromHex(BlockchainConfig.privateKey);

  // ───────────────────────── CATAT ─────────────────────────

  /// Catat satu transaksi poin milik [userId].
  /// [poin] selalu positif; tanda +/- ditentukan oleh [tipe].
  static Future<void> catat({
    required int userId,
    required int poin,
    required String deskripsi,
    required String tipe,
  }) async {
    final db = await DbHelper.instance.database;
    final jumlah = tipe == tipePemasukan ? poin : -poin;
    final waktu = _formatWaktu(DateTime.now());

    final terakhir = await db.query(
      'blockchain_logs',
      columns: ['current_hash'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: 1,
    );
    final previousHash =
        terakhir.isEmpty ? _hashAwal : terakhir.first['current_hash'] as String;

    // Hash lokal (cadangan saat offline); bukti utamanya ada di tx_hash on-chain
    final currentHash = sha256
        .convert(utf8.encode('$previousHash|$deskripsi|$jumlah|$waktu'))
        .toString();

    await db.insert('blockchain_logs', {
      'user_id': userId,
      'action_type': deskripsi,
      'points_amount': jumlah,
      'timestamp': waktu,
      'previous_hash': previousHash,
      'current_hash': currentHash,
      'tx_hash': null,
      'synced': 0,
    });

    unawaited(sinkronkan());
  }

  /// Riwayat milik [userId] dari SQLite, terbaru di atas.
  static Future<List<Map<String, dynamic>>> ambilRiwayat(int userId) async {
    final db = await DbHelper.instance.database;
    final rows = await db.query(
      'blockchain_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return List<Map<String, dynamic>>.from(rows);
  }

  // ───────────────────────── KIRIM KE BLOCKCHAIN ─────────────────────────

  /// Kirim catatan yang belum terkonfirmasi ke blockchain (berurutan).
  /// Aman dipanggil berkali-kali; kalau offline, baris tetap menunggu.
  static Future<void> sinkronkan() async {
    if (!BlockchainConfig.siap) {
      errorTerakhir =
          'blockchain_config.dart belum diisi benar: alamat kontrak harus diawali 0x dan private key tidak boleh masih ISI_... (setelah mengubah, stop lalu jalankan ulang aplikasi).';
      debugPrint(errorTerakhir);
      return;
    }
    if (_sedangSinkron) {
      _perluUlang = true; // ada catatan baru saat proses berjalan
      return;
    }
    _sedangSinkron = true;
    errorTerakhir = null;
    try {
      do {
        _perluUlang = false;
        await _prosesAntrean();
      } while (_perluUlang);
    } catch (e) {
      errorTerakhir = e.toString();
      debugPrint('Sinkronisasi blockchain tertunda: $e');
    } finally {
      _sedangSinkron = false;
    }
  }

  static Future<void> _prosesAntrean() async {
    final db = await DbHelper.instance.database;
    final rows =
        await db.query('blockchain_logs', where: 'synced = 0', orderBy: 'id ASC');

    for (final r in rows) {
      var txHash = r['tx_hash'] as String?;

      // 1. Kirim transaksi kalau belum pernah dikirim
      if (txHash == null || txHash.isEmpty) {
        txHash = await _web3.sendTransaction(
          _dompet,
          Transaction.callContract(
            contract: _kontrak,
            function: _kontrak.function('catat'),
            parameters: [
              BigInt.from(r['user_id'] as int),
              BigInt.from(r['points_amount'] as int),
              r['action_type'] as String,
            ],
          ),
          chainId: BlockchainConfig.chainId,
        );
        await db.update('blockchain_logs', {'tx_hash': txHash},
            where: 'id = ?', whereArgs: [r['id']]);
      }

      // 2. Tunggu konfirmasi (Sepolia ~12 detik per blok)
      final receipt = await _tungguReceipt(txHash);
      if (receipt == null) return; // belum terkonfirmasi, dicoba lagi nanti
      if (receipt.status != true) {
        // Transaksi gagal (revert): kosongkan tx_hash supaya dikirim ulang
        await db.update('blockchain_logs', {'tx_hash': null},
            where: 'id = ?', whereArgs: [r['id']]);
        return;
      }

      // 3. Salin ke Supabase sebagai cadangan, lalu tandai selesai
      await Supabase.instance.client.from('blockchain_logs').insert({
        'user_id': r['user_id'],
        'action_type': r['action_type'],
        'points_amount': r['points_amount'],
        'timestamp': r['timestamp'],
        'previous_hash': r['previous_hash'],
        'current_hash': r['current_hash'],
        'tx_hash': txHash,
        'synced': 1,
      });
      await db.update('blockchain_logs', {'synced': 1},
          where: 'id = ?', whereArgs: [r['id']]);
    }
  }

  static Future<TransactionReceipt?> _tungguReceipt(String txHash) async {
    for (var i = 0; i < 15; i++) {
      final receipt = await _web3.getTransactionReceipt(txHash);
      if (receipt != null) return receipt;
      await Future.delayed(const Duration(seconds: 4));
    }
    return null;
  }

  // ───────────────────────── BACA DARI KONTRAK ─────────────────────────

  /// Saldo, jumlah catatan, dan hasil verifikasi rantai langsung dari smart
  /// contract. Mengembalikan null kalau belum dikonfigurasi atau offline.
  static Future<StatusOnChain?> statusOnChain(int userId) async {
    if (!BlockchainConfig.siap) return null;
    try {
      final id = [BigInt.from(userId)];
      final saldo = await _web3.call(
          contract: _kontrak, function: _kontrak.function('saldo'), params: id);
      final jumlah = await _web3.call(
          contract: _kontrak,
          function: _kontrak.function('jumlahCatatan'),
          params: id);
      final valid = await _web3.call(
          contract: _kontrak,
          function: _kontrak.function('verifikasi'),
          params: id);
      return StatusOnChain(
          saldo.first as BigInt, jumlah.first as BigInt, valid.first as bool);
    } catch (e) {
      debugPrint('Gagal membaca kontrak: $e');
      return null;
    }
  }

  static String _formatWaktu(DateTime t) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(t.day)}/${dua(t.month)}/${t.year} ${dua(t.hour)}:${dua(t.minute)}';
  }
}