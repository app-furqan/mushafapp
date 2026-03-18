import 'word_model.dart';

enum PageLineType { ayah, surahName, basmallah }

class LayoutLineData {
  final int lineNumber;
  final PageLineType lineType;
  final bool isCentered;
  final int? surahNumber;
  final List<int> wordIds;

  const LayoutLineData({
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    this.surahNumber,
    this.wordIds = const [],
  });
}

class LineData {
  final int lineNumber;
  final PageLineType lineType;
  final bool isCentered;
  final int? surahNumber;
  final List<WordModel> words;

  const LineData({
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    required this.words,
    this.surahNumber,
  });

  String get fallbackText => words.map((word) => word.text).join(' ');

  String get glyphText => words.map((word) => word.glyphText).join();
}

class PageData {
  static const int totalLines = 15;

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
            .map(
              (e) => LineData(
                lineNumber: e.key,
                lineType: PageLineType.ayah,
                isCentered: false,
                words: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

    return PageData(pageNumber: pageNumber, lines: lines);
  }

  factory PageData.fromLayout(
    int pageNumber,
    List<WordModel> words,
    List<LayoutLineData> layoutLines,
  ) {
    if (layoutLines.isEmpty) {
      return PageData.fromWords(pageNumber, words);
    }

    final wordsById = {for (final word in words) word.id: word};
    final wordsByLine = <int, List<WordModel>>{};
    for (final word in words) {
      wordsByLine.putIfAbsent(word.lineNumber, () => []).add(word);
    }

    final lines =
        layoutLines.map((layoutLine) {
            final matchedWords = <WordModel>[
              for (final wordId in layoutLine.wordIds)
                if (wordsById[wordId] case final word?) word,
            ];

            return LineData(
              lineNumber: layoutLine.lineNumber,
              lineType: layoutLine.lineType,
              isCentered: layoutLine.isCentered,
              surahNumber: layoutLine.surahNumber,
              words:
                  matchedWords.isNotEmpty ||
                          layoutLine.lineType != PageLineType.ayah
                      ? matchedWords
                      : (wordsByLine[layoutLine.lineNumber] ?? const []),
            );
          }).toList()
          ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

    if (lines.isEmpty) {
      return PageData.fromWords(pageNumber, words);
    }

    return PageData(pageNumber: pageNumber, lines: lines);
  }

  LineData? lineFor(int lineNumber) {
    for (final line in lines) {
      if (line.lineNumber == lineNumber) {
        return line;
      }
    }
    return null;
  }
}
