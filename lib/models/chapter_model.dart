class ChapterModel {
  final int id;
  final String nameArabic;
  final bool bismillahPre;
  final int startPage;

  const ChapterModel({
    required this.id,
    required this.nameArabic,
    required this.bismillahPre,
    required this.startPage,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    final pages =
        (json['pages'] as List<dynamic>? ?? const <dynamic>[])
            .map((page) => page as int)
            .toList();

    return ChapterModel(
      id: json['id'] as int,
      nameArabic: json['name_arabic'] as String? ?? '',
      bismillahPre: json['bismillah_pre'] as bool? ?? true,
      startPage: pages.isEmpty ? 1 : pages.first,
    );
  }
}
