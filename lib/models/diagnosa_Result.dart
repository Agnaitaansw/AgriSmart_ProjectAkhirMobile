class DiagnosaResult {
  final String penyakit;
  final int keyakinan; // 0-100
  final String penjelasan;
  final List<String> langkah;

  const DiagnosaResult({
    required this.penyakit,
    required this.keyakinan,
    required this.penjelasan,
    required this.langkah,
  });

  factory DiagnosaResult.fromJson(Map<String, dynamic> j) => DiagnosaResult(
        penyakit: (j['penyakit'] ?? 'Tidak teridentifikasi').toString(),
        keyakinan: ((j['keyakinan'] ?? 0) as num).round().clamp(0, 100),
        penjelasan: (j['penjelasan'] ?? '').toString(),
        langkah: ((j['langkah'] ?? []) as List).map((e) => e.toString()).toList(),
      );
}