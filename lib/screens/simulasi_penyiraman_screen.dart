import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/notification_service.dart'; // TAMBAH
import '../services/penyiraman_repository.dart';
import '../services/sesi_user.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

/// Data alat penyiram. id 0 = teko bawaan (gratis, sudah dimiliki).
class Penyiram {
  final int id;
  final String nama;
  final int harga;
  final Color warna;
  bool dimiliki;

  Penyiram({
    required this.id,
    required this.nama,
    required this.harga,
    required this.warna,
    this.dimiliki = false,
  });
}

class SimulasiPenyiramanScreen extends StatefulWidget {
  const SimulasiPenyiramanScreen({super.key});

  @override
  State<SimulasiPenyiramanScreen> createState() =>
      _SimulasiPenyiramanScreenState();
}

class _SimulasiPenyiramanScreenState extends State<SimulasiPenyiramanScreen> {
  // Logic Sensor
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  double _x = 0.0, _y = 0.0, _z = 0.0;

  // Game Logic State
  int _secondsLeft = 24;
  int _score = 120;
  double _waterProgress = 0.55; // 55%
  final double _targetProgress = 0.80; // 80%
  bool _isWatering = false;
  Timer? _gameTimer;

  // Data tersimpan (SQLite + Supabase) lewat repository
  final _repo = PenyiramanRepository();
  bool _memuat = true;

  // Poin & Toko Penyiram
  int _poinUser = 0;
  bool _sudahDisiramHariIni = false;

  // TAMBAH: status pengingat harian setiap 1jam
  bool _pengingatAktif = false;
  bool _pengingatMemproses = false;

  final List<Penyiram> _daftarPenyiram = [
    Penyiram(
        id: 0,
        nama: 'Teko Hijau',
        harga: 0,
        warna: const Color(0xFF1E5B3E),
        dimiliki: true),
    Penyiram(id: 1, nama: 'Teko Biru', harga: 10, warna: const Color(0xFF3B82C4)),
    Penyiram(id: 2, nama: 'Teko Oranye', harga: 90, warna: const Color(0xFFE08A2E)),
    Penyiram(id: 3, nama: 'Teko Ungu', harga: 250, warna: const Color(0xFF8A5CC2)),
    Penyiram(id: 4, nama: 'Teko Merah', harga: 580, warna: const Color(0xFFD9534F)),
  ];

  int _aktifId = 0; // teko yang sedang dipakai di arena
  int? _tokoTerpilihId; // teko di toko yang dipilih untuk dibeli
  int _pilihMilikId = 0; // teko milik user yang dipilih (sebelum "Gunakan")

  Penyiram _cari(int id) => _daftarPenyiram.firstWhere((p) => p.id == id);
  List<Penyiram> get _daftarToko =>
      _daftarPenyiram.where((p) => p.id != 0).toList();
  List<Penyiram> get _daftarMilik =>
      _daftarPenyiram.where((p) => p.dimiliki).toList();

  @override
  void initState() {
    super.initState();
    _muatData();
    _muatStatusPengingat(); // TAMBAH
    _startListeningSensors();
    _startTimer();
  }

  // TAMBAH: cek apakah pengingat harian sudah terjadwal di sistem
  Future<void> _muatStatusPengingat() async {
    try {
      final aktif = await NotificationService.instance.isWateringScheduled();
      if (!mounted) return;
      setState(() => _pengingatAktif = aktif);
    } catch (e) {
      debugPrint('Gagal cek status pengingat: $e');
    }
  }

  // TAMBAH: nyalakan / matikan pengingat harian setiap 1 jam
  Future<void> _ubahPengingat(bool nyala) async {
    if (_pengingatMemproses) return;
    setState(() => _pengingatMemproses = true);

    try {
      if (nyala) {
        final izin = await NotificationService.instance.requestPermissions();
        if (!izin) {
          if (mounted) {
            _snack('Izin notifikasi ditolak. Aktifkan dulu di pengaturan HP.');
          }
          return;
        }
        // Notifikasi tiap 1 jam selama hari itu belum menyiram
        await NotificationService.instance
            .jadwalkanPerJam(sudahDisiramHariIni: _sudahDisiramHariIni);
        if (mounted) {
          setState(() => _pengingatAktif = true);
          _snack('Pengingat aktif: setiap 1 jam');
        }
      } else {
        await NotificationService.instance.cancelWatering();
        if (mounted) {
          setState(() => _pengingatAktif = false);
          _snack('Pengingat dimatikan');
        }
      }
    } catch (e) {
      debugPrint('Gagal mengubah pengingat: $e');
      if (mounted) _snack('Gagal mengatur pengingat');
    } finally {
      if (mounted) setState(() => _pengingatMemproses = false);
    }
  }

  // Kalau pengingat menyala, perbarui jadwalnya setiap layar ini dibuka:
  // hari ini sudah disiram -> lewati, dan jendela 3 hari ke depan diperpanjang.
  Future<void> _segarkanJadwal() async {
    try {
      final aktif = await NotificationService.instance.isWateringScheduled();
      if (aktif) {
        await NotificationService.instance
            .jadwalkanPerJam(sudahDisiramHariIni: _sudahDisiramHariIni);
      }
    } catch (e) {
      debugPrint('Gagal menyegarkan jadwal pengingat: $e');
    }
  }

  // Ambil poin, teko, dan status "sudah disiram hari ini" dari database
  Future<void> _muatData() async {
    // Tunggu frame pertama selesai supaya snackbar aman dipakai kalau gagal
    await Future<void>.delayed(Duration.zero);
    try {
      final s = await _repo.muat(await idUserLogin());
      if (!mounted) return;
      setState(() {
        _poinUser = s.koin;
        _sudahDisiramHariIni = s.sudahDisiramHariIni;
        for (final p in _daftarPenyiram) {
          p.dimiliki = p.id == 0 || s.tekoDimiliki.contains(p.id);
        }
        _aktifId = _daftarPenyiram.any((p) => p.id == s.tekoAktif && p.dimiliki)
            ? s.tekoAktif
            : 0;
        _pilihMilikId = _aktifId;
        _memuat = false;
      });
      _segarkanJadwal();
    } catch (e) {
      debugPrint('Gagal memuat data penyiraman: $e');
      if (!mounted) return;
      setState(() => _memuat = false);
      _snack('Gagal memuat data, coba buka ulang halaman ini');
    }
  }

  // Simpan hasil penyiraman: koin, last_watered_at, dan riwayat blockchain
  Future<void> _simpanPenyiraman() async {
    try {
      final koin = await _repo.catatPenyiraman(await idUserLogin());
      if (mounted) setState(() => _poinUser = koin);

      // Sudah menyiram: hentikan sisa notifikasi hari ini (besok mulai lagi)
      if (_pengingatAktif) {
        await NotificationService.instance
            .jadwalkanPerJam(sudahDisiramHariIni: true);
      }
    } catch (e) {
      debugPrint('Gagal menyimpan penyiraman: $e');
      if (mounted) _snack('Gagal menyimpan hasil penyiraman');
    }
  }

  void _startListeningSensors() {
    _accelSubscription =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!mounted || _memuat) return;

      bool targetTercapai = false;

      setState(() {
        _x = event.x;
        _y = event.y;
        _z = event.z;

        // HP dimiringkan ke kanan (X > 2.5) -> air mengucur
        if (_x > 2.5) {
          _isWatering = true;

          if (_sudahDisiramHariIni) return;

          if (_waterProgress < 1.0) {
            _waterProgress += 0.003;
            _score += 1;

            if (_waterProgress >= _targetProgress) {
              _sudahDisiramHariIni = true;
              _poinUser += 2; // reward 2 poin
              targetTercapai = true;
            }
          }
        } else {
          _isWatering = false;
        }
      });

      // Efek samping (dialog & log) dijalankan di luar setState
      if (targetTercapai) {
        _simpanPenyiraman();
        _tampilkanPopupBerhasil();
      }
    });
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _gameTimer?.cancel();
      }
    });
  }

  void _snack(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(pesan), duration: const Duration(seconds: 2)),
      );
  }

  // Pop-up berhasil menyiram
  void _tampilkanPopupBerhasil() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1E5B3E)),
        ),
        content: const Text(
          'Berhasil Menyiram!\n+2 poin',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E5B3E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF1E5B3E))),
          ),
        ],
      ),
    );
  }

  // Beli teko: pilih di toko -> tekan "Beli" -> konfirmasi
  Future<void> _beliPenyiram() async {
    final id = _tokoTerpilihId;
    if (id == null) {
      _snack('Pilih penyiram yang ingin dibeli dulu');
      return;
    }
    final item = _cari(id);

    if (item.dimiliki) {
      _snack('Penyiram ini sudah kamu miliki');
      return;
    }
    if (_poinUser < item.harga) {
      _snack('Poin kamu tidak cukup!');
      return;
    }

    final ya = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF1E5B3E)),
        ),
        content: Text(
          'Beli dengan ${item.harga} poin?',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E5B3E)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5B3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E5B3E),
              side: const BorderSide(color: Color(0xFF1E5B3E)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (ya != true || !mounted) return;

    // Simpan pembelian dulu; layar baru berubah kalau berhasil tersimpan
    bool berhasil;
    try {
      berhasil = await _repo.beliTeko(
        userId: await idUserLogin(),
        canId: item.id,
        harga: item.harga,
        namaTeko: item.nama,
      );
    } catch (e) {
      debugPrint('Gagal menyimpan pembelian: $e');
      if (mounted) _snack('Gagal menyimpan pembelian');
      return;
    }
    if (!mounted) return;
    if (!berhasil) {
      _snack('Poin kamu tidak cukup!');
      return;
    }

    setState(() {
      _poinUser -= item.harga;
      item.dimiliki = true;
      _pilihMilikId = item.id; // langsung terpilih di daftar milik
      _tokoTerpilihId = null;
    });
    _snack('Berhasil membeli ${item.nama}! Tekan "Gunakan" untuk memakainya.');
  }

  // Pakai teko yang sudah dibeli
  Future<void> _gunakanPenyiram() async {
    final item = _cari(_pilihMilikId);
    if (!item.dimiliki) return;
    try {
      await _repo.gunakanTeko(await idUserLogin(), item.id);
    } catch (e) {
      debugPrint('Gagal menyimpan teko aktif: $e');
      if (mounted) _snack('Gagal menyimpan pilihan teko');
      return;
    }
    if (!mounted) return;
    setState(() => _aktifId = item.id);
    _snack('${item.nama} sekarang dipakai');
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aktif = _cari(_aktifId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Simulasi Penyiraman',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats (Waktu, Skor, Target)
            Row(
              children: [
                _buildStatHeaderCard(
                    'Waktu', '00:${_secondsLeft.toString().padLeft(2, '0')}'),
                const SizedBox(width: 8),
                _buildStatHeaderCard('Skor', '$_score'),
                const SizedBox(width: 8),
                _buildStatHeaderCard(
                    'Target', '${(_targetProgress * 100).toInt()}%'),
              ],
            ),
            const SizedBox(height: 16),

            // Arena game
            _buildArena(aktif),
            const SizedBox(height: 16),

            // Sensor accelerometer
            _buildSensorCard(),
            const SizedBox(height: 16),

            // TAMBAH: pengingat penyiraman harian
            _buildPengingatCard(),
            const SizedBox(height: 16),

            // Toko: Beli Penyiram Tanaman
            _buildTokoSection(),

            // Pilih Penyiram Tanaman (yang sudah dimiliki)
            const SizedBox(height: 16),
            _buildPilihSection(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── PENGINGAT ─────────────────────────
  // TAMBAH
  Widget _buildPengingatCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              size: 22, color: AppColors.green),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pengingat tiap 1 jam',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Muncul tiap jam (09.00-21.00) selama belum menyiram.',
                    style: TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(
            value: _pengingatAktif,
            onChanged: _pengingatMemproses ? null : _ubahPengingat,
            activeColor: AppColors.green,
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ARENA ─────────────────────────
  Widget _buildArena(Penyiram aktif) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFFE5EFE6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Tanah di bagian bawah
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 70,
              child: Container(color: const Color(0xFFD3E4D5)),
            ),

            // Tag nama tanaman
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            // Teko + tanaman
            Align(
              alignment: const Alignment(-0.15, -0.15),
              child: SizedBox(
                width: 230,
                height: 210,
                child: Stack(
                  children: [
                    // Tanaman cabai
                    Positioned(
                      right: 20,
                      bottom: 0,
                      child: SizedBox(
                        width: 90,
                        height: 150,
                        child: CustomPaint(painter: PlantPainter()),
                      ),
                    ),
                    // Teko (miring saat menyiram), warna sesuai teko aktif
                    Positioned(
                      left: 0,
                      top: 0,
                      child: AnimatedRotation(
                        turns: _isWatering ? 0.07 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: WateringCanIcon(
                            size: 100, color: aktif.warna),
                      ),
                    ),
                    // Tetesan air
                    if (_isWatering)
                      const Positioned(
                        left: 100,
                        top: 52,
                        child: Column(
                          children: [
                            Icon(Icons.water_drop,
                                size: 14, color: Color(0xFF3B82C4)),
                            Icon(Icons.water_drop,
                                size: 10, color: Color(0xFF3B82C4)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Indikator level air (kanan)
            Positioned(
              right: 16,
              top: 40,
              bottom: 70,
              child: Container(
                width: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    return Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        FractionallySizedBox(
                          heightFactor: _waterProgress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90D9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Garis batas target
                        Positioned(
                          bottom: c.maxHeight * _targetProgress,
                          left: -4,
                          right: -4,
                          child: Container(height: 2, color: Colors.black54),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Banner bawah
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E5B3E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _sudahDisiramHariIni
                      ? 'Tanamanmu sudah disiram hari ini!'
                      : (_isWatering
                          ? 'Sedang menyiram...'
                          : 'Miringkan ponsel ke kanan untuk menyiram'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── SENSOR ─────────────────────────
  Widget _buildSensorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sensor accelerometer',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Text('Aktif',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.green,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSensorValueBox('X', _x.toStringAsFixed(1)),
              const SizedBox(width: 8),
              _buildSensorValueBox('Y', _y.toStringAsFixed(1)),
              const SizedBox(width: 8),
              _buildSensorValueBox('Z', _z.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── TOKO ─────────────────────────
  Widget _buildTokoSection() {
    final toko = _daftarToko;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Beli Penyiram Tanaman',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text('Poin Anda : $_poinUser',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: toko.map((item) {
            final terpilih = _tokoTerpilihId == item.id;
            final mampu = _poinUser >= item.harga;
            return GestureDetector(
              onTap: () {
                if (item.dimiliki) {
                  _snack('${item.nama} sudah kamu miliki');
                  return;
                }
                setState(() => _tokoTerpilihId = item.id);
              },
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: terpilih
                                ? AppColors.green
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Opacity(
                          opacity: item.dimiliki || !mampu ? 0.45 : 1.0,
                          child: WateringCanIcon(size: 44, color: item.warna),
                        ),
                      ),
                      if (item.dimiliki)
                        const Positioned(
                          right: -4,
                          top: -4,
                          child: Icon(Icons.check_circle,
                              size: 18, color: AppColors.green),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${item.harga}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        _buildPillButton('Beli', _beliPenyiram),
      ],
    );
  }

  Widget _buildPilihSection() {
    final milik = _daftarMilik;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pilih Penyiram Tanaman',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: milik.map((item) {
            final terpilih = _pilihMilikId == item.id;
            final dipakai = _aktifId == item.id;
            return GestureDetector(
              onTap: () => setState(() => _pilihMilikId = item.id),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            terpilih ? AppColors.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: WateringCanIcon(size: 44, color: item.warna),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dipakai ? 'Dipakai' : '',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        _buildPillButton('Gunakan', _gunakanPenyiram),
      ],
    );
  }

  Widget _buildPillButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E5B3E),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatHeaderCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorValueBox(String axis, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(axis,
                style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(val,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════ GAMBAR TEKO & TANAMAN ═════════════════════

/// Ikon teko penyiram yang warnanya bisa diganti-ganti.
class WateringCanIcon extends StatelessWidget {
  final double size;
  final Color color;
  const WateringCanIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: CustomPaint(painter: WateringCanPainter(color)),
    );
  }
}

class WateringCanPainter extends CustomPainter {
  final Color color;
  WateringCanPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;

    // Badan teko
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.38, w * 0.50, h * 0.56),
        Radius.circular(w * 0.08),
      ),
      fill,
    );

    // Corong (mengarah ke kanan-atas)
    final spout = Path()
      ..moveTo(w * 0.66, h * 0.58)
      ..lineTo(w * 0.90, h * 0.30)
      ..lineTo(w * 0.97, h * 0.37)
      ..lineTo(w * 0.68, h * 0.84)
      ..close();
    canvas.drawPath(spout, fill);

    // Kepala corong (rose)
    canvas.drawCircle(Offset(w * 0.94, h * 0.32), w * 0.075, fill);

    // Pegangan atas
    canvas.drawArc(
      Rect.fromLTWH(w * 0.24, h * 0.08, w * 0.42, h * 0.62),
      math.pi,
      math.pi,
      false,
      stroke,
    );

    // Pegangan belakang (kiri)
    canvas.drawArc(
      Rect.fromLTWH(w * 0.04, h * 0.44, w * 0.34, h * 0.34),
      math.pi / 2,
      math.pi,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant WateringCanPainter old) => old.color != color;
}

/// Tanaman cabai dalam pot.
class PlantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final green = Paint()..color = const Color(0xFF2E8B57);
    final darkGreen = Paint()..color = const Color(0xFF1E5B3E);
    final pot = Paint()..color = const Color(0xFFC9722B);
    final chili = Paint()..color = const Color(0xFFE5483B);

    // Batang
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.47, h * 0.18, w * 0.06, h * 0.62),
        Radius.circular(3),
      ),
      darkGreen,
    );

    // Daun
    void daun(double cx, double cy, double angle, Paint p) {
      canvas.save();
      canvas.translate(w * cx, h * cy);
      canvas.rotate(angle);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: w * 0.42, height: h * 0.11),
          p);
      canvas.restore();
    }

    daun(0.68, 0.30, -0.5, green);
    daun(0.30, 0.42, 0.5, darkGreen);
    daun(0.70, 0.55, -0.4, darkGreen);
    daun(0.30, 0.64, 0.4, green);
    daun(0.52, 0.12, -1.2, green);

    // Cabai
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.85, h * 0.46),
            width: w * 0.08,
            height: h * 0.10),
        chili);

    // Pot
    final potPath = Path()
      ..moveTo(w * 0.22, h * 0.80)
      ..lineTo(w * 0.78, h * 0.80)
      ..lineTo(w * 0.70, h * 1.00)
      ..lineTo(w * 0.30, h * 1.00)
      ..close();
    canvas.drawPath(potPath, pot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.76, w * 0.64, h * 0.07),
        const Radius.circular(3),
      ),
      pot,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}