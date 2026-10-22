import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pencatatan riwayat poin ke tabel `blockchain_logs` di Supabase.
/// Simpan di: lib/services/blockchain_service.dart
class BlockchainService {
  BlockchainService._();

  static const String tipePemasukan = 'pemasukan';
  static const String tipePengeluaran = 'pengeluaran';

  static const String _tabel = 'blockchain_logs';
  static final String _hashAwal = '0' * 64;

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Catat satu transaksi poin. Mengembalikan true kalau berhasil tersimpan.
  ///
  /// [poin] selalu angka positif; tanda +/- ditentukan oleh [tipe]
  /// (pemasukan = positif, pengeluaran = negatif).
  static Future<bool> catat({
    required int poin,
    required String deskripsi,
    required String tipe,
  }) async {
    try {
      final jumlah = tipe == tipePemasukan ? poin : -poin;
      final waktu = _formatWaktu(DateTime.now());

      // previous_hash = current_hash dari baris terakhir
      final terakhir = await _supabase
          .from(_tabel)
          .select('current_hash')
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();
      final previousHash = (terakhir?['current_hash'] as String?) ?? _hashAwal;

      // current_hash = SHA-256 dari isi blok + hash sebelumnya
      final currentHash = sha256
          .convert(utf8.encode('$previousHash|$deskripsi|$jumlah|$waktu'))
          .toString();

      await _supabase.from(_tabel).insert({
        // 'user_id': ...,  // nullable; isi dengan id user yang login (int8) kalau ada
        'action_type': deskripsi,
        'points_amount': jumlah,
        'timestamp': waktu,
        'previous_hash': previousHash,
        'current_hash': currentHash,
        'synced': 1,
      });
      return true;
    } catch (e) {
      debugPrint('Gagal catat blockchain: $e');
      return false;
    }
  }

  static String _formatWaktu(DateTime t) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(t.day)}/${dua(t.month)}/${t.year} ${dua(t.hour)}:${dua(t.minute)}';
  }
}