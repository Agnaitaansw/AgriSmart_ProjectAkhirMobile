
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
  final String penjelasan;
  final List<String> langkah;
  final List<DiagnosaSource> sumber;

  const DiagnosaResult({
    required this.penyakit,
    required this.penjelasan,
    required this.langkah,
    this.sumber = const [],
  });

  factory DiagnosaResult.fromJson(Map<String, dynamic> json) {
    final rawLangkah = json['langkah'];
    final rawSumber = json['sumber'];

    return DiagnosaResult(
      penyakit: json['penyakit']?.toString() ??
          'Tidak dapat dipastikan',
      penjelasan: json['penjelasan']?.toString() ??
          'Informasi belum cukup untuk menjelaskan kondisi tanaman.',
      langkah: rawLangkah is List
          ? rawLangkah.map((e) => e.toString()).toList()
          : <String>[],
      sumber: rawSumber is List
          ? rawSumber
              .whereType<Map>()
              .map(
                (e) => DiagnosaSource(
                  title: e['title']?.toString() ?? '',
                  url: e['url']?.toString() ?? '',
                ),
              )
              .toList()
          : <DiagnosaSource>[],
    );
  }

  DiagnosaResult copyWith({
    String? penyakit,
    String? penjelasan,
    List<String>? langkah,
    List<DiagnosaSource>? sumber,
  }) {
    return DiagnosaResult(
      penyakit: penyakit ?? this.penyakit,
      penjelasan: penjelasan ?? this.penjelasan,
      langkah: langkah ?? this.langkah,
      sumber: sumber ?? this.sumber,
    );
  }
}
