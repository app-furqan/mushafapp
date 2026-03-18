class WordModel {
  final int id;
  final int position;
  final String text;
  final String codeV2;
  final int pageNumber;
  final int lineNumber;
  final String charTypeName; // "word" or "end"

  const WordModel({
    required this.id,
    required this.position,
    required this.text,
    required this.codeV2,
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
      pageNumber: json['page_number'] as int,
      lineNumber: json['line_number'] as int,
      charTypeName: json['char_type_name'] as String,
    );
  }

  bool get isEnd => charTypeName == 'end';

  String get glyphText => codeV2.isNotEmpty ? codeV2 : text;
}
