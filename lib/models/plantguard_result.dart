class PlantGuardResult {
  final String namaTanaman, kemungkinanGangguan, tingkatKeyakinan;
  final String tingkatKeparahan, penjelasan, catatan;
  final List<String> gejalaTerlihat, langkahPenanganan, pencegahan;

  const PlantGuardResult({
    required this.namaTanaman,
    required this.kemungkinanGangguan,
    required this.tingkatKeyakinan,
    required this.tingkatKeparahan,
    required this.penjelasan,
    required this.gejalaTerlihat,
    required this.langkahPenanganan,
    required this.pencegahan,
    required this.catatan,
  });

  factory PlantGuardResult.fromJson(Map<String, dynamic> json) {
    String str(String key, String fallback) {
      final value = json[key]?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }
    List<String> list(String key) {
      final value = json[key];
      return value is List
          ? value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
    }
    return PlantGuardResult(
      namaTanaman: str('namaTanaman', 'Belum dapat dikenali'),
      kemungkinanGangguan: str('kemungkinanGangguan', 'Belum dapat dipastikan'),
      tingkatKeyakinan: str('tingkatKeyakinan', 'Rendah'),
      tingkatKeparahan: str('tingkatKeparahan', 'Belum dapat dinilai'),
      penjelasan: str('penjelasan', 'Informasi belum cukup untuk menjelaskan kondisi tanaman.'),
      gejalaTerlihat: list('gejalaTerlihat'),
      langkahPenanganan: list('langkahPenanganan'),
      pencegahan: list('pencegahan'),
      catatan: str('catatan', 'Hasil ini merupakan panduan awal, bukan diagnosis pasti.'),
    );
  }
}
