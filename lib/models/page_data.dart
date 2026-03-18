import 'word_model.dart';

class LineData {
  final int lineNumber;
  final List<WordModel> words;

  const LineData({required this.lineNumber, required this.words});

  String get fallbackText => words.map((word) => word.text).join(' ');

  String get glyphText => words.map((word) => word.glyphText).join();
}

class PageData {
  final int pageNumber;
  final List<LineData> lines;

  const PageData({required this.pageNumber, required this.lines});

  factory PageData.fromWords(int pageNumber, List<WordModel> words) {
    final Map<int, List<WordModel>> byLine = {};
    for (final word in words) {
      byLine.putIfAbsent(word.lineNumber, () => []).add(word);
    }
    final lines =
        byLine.entries
            .map((e) => LineData(lineNumber: e.key, words: e.value))
            .toList()
          ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
    return PageData(pageNumber: pageNumber, lines: lines);
  }

  int get minLine => lines.isEmpty ? 1 : lines.first.lineNumber;
  int get maxLine => lines.isEmpty ? 15 : lines.last.lineNumber;
}
