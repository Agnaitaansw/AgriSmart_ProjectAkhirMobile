
class DiagnosaSource {
  final String title;
  final String url;

  const DiagnosaSource({
    required this.title,
    required this.url,
  });
}

class DiagnosaResult {
  final String penyakit;
  final int keyakinan;
  final String penjelasan;
  final List<String> langkah;
  final List<DiagnosaSource> sumber;

  const DiagnosaResult({
    required this.penyakit,
    required this.keyakinan,
    required this.penjelasan,
    required this.langkah,
    this.sumber = const [],
  });

  factory DiagnosaResult.fromJson(Map<String, dynamic> json) {
    final rawKeyakinan = json['keyakinan'];

    final int keyakinan;
    if (rawKeyakinan is num) {
      keyakinan = rawKeyakinan.round().clamp(0, 100);
    } else {
      keyakinan =
          int.tryParse(rawKeyakinan?.toString() ?? '') ?? 0;
    }

    final rawLangkah = json['langkah'];

    return DiagnosaResult(
      penyakit: json['penyakit']?.toString() ??
          'Tidak dapat dipastikan',
      keyakinan: keyakinan.clamp(0, 100),
      penjelasan: json['penjelasan']?.toString() ??
          'Informasi belum cukup untuk menjelaskan kondisi tanaman.',
      langkah: rawLangkah is List
          ? rawLangkah.map((e) => e.toString()).toList()
          : <String>[],
    );
  }

  DiagnosaResult copyWith({
    String? penyakit,
    int? keyakinan,
    String? penjelasan,
    List<String>? langkah,
    List<DiagnosaSource>? sumber,
  }) {
    return DiagnosaResult(
      penyakit: penyakit ?? this.penyakit,
      keyakinan: keyakinan ?? this.keyakinan,
      penjelasan: penjelasan ?? this.penjelasan,
      langkah: langkah ?? this.langkah,
      sumber: sumber ?? this.sumber,
    );
  }
}
