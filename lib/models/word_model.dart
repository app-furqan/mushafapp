class WordModel {
  final int id;
  final int position;
  final String text;
  final String codeV2;
  final String verseKey;
  final int surahNumber;
  final int ayahNumber;
  final int pageNumber;
  final int lineNumber;
  final String charTypeName; // "word" or "end"

  const WordModel({
    required this.id,
    required this.position,
    required this.text,
    required this.codeV2,
    required this.verseKey,
    required this.surahNumber,
    required this.ayahNumber,
    required this.pageNumber,
    required this.lineNumber,
    required this.charTypeName,
  });

  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      id: json['id'] as int,
      position: json['position'] as int,
      text: (json['text_qpc_hafs'] as String? ?? json['text'] as String? ?? ''),
      codeV2: json['code_v2'] as String? ?? '',
      verseKey: json['verse_key'] as String? ?? '',
      surahNumber: json['surah_number'] as int? ?? 0,
      ayahNumber: json['ayah_number'] as int? ?? 0,
      pageNumber: json['page_number'] as int,
      lineNumber: json['line_number'] as int,
      charTypeName: json['char_type_name'] as String,
    );
  }

  bool get isEnd => charTypeName == 'end';

  String get glyphText => codeV2.isNotEmpty ? codeV2 : text;

  bool get isFirstWordOfSurah => position == 1 && ayahNumber == 1;
}
