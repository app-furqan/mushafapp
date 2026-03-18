import 'package:http/http.dart' as http;

import '../models/page_data.dart';

class QulLayoutService {
  static const _baseUrl = 'https://qul.tarteel.ai/resources/mushaf-layout/19';

  final _cache = <int, List<LayoutLineData>>{};
  final _inflight = <int, Future<List<LayoutLineData>>>{};

  Future<List<LayoutLineData>> getPageLayout(int pageNumber) async {
    if (_cache.containsKey(pageNumber)) {
      return _cache[pageNumber]!;
    }
    if (_inflight.containsKey(pageNumber)) {
      return _inflight[pageNumber]!;
    }

    final future = _fetchPageLayout(pageNumber);
    _inflight[pageNumber] = future;
    try {
      final result = await future;
      _cache[pageNumber] = result;
      return result;
    } finally {
      _inflight.remove(pageNumber);
    }
  }

  Future<List<LayoutLineData>> _fetchPageLayout(int pageNumber) async {
    final uri = Uri.parse('$_baseUrl?page=$pageNumber');
    final response = await http.get(
      uri,
      headers: const {'User-Agent': 'Mozilla/5.0'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'QUL layout error ${response.statusCode} for page $pageNumber',
      );
    }

    final lines = _parseHtml(response.body);
    if (lines.isEmpty) {
      throw const FormatException('No page layout lines found in QUL markup');
    }
    return lines;
  }

  List<LayoutLineData> _parseHtml(String html) {
    final containerPattern = RegExp(
      r'<div class="line-container" data-line="(\d+)">',
    );
    final containerMatches = containerPattern.allMatches(html).toList();
    if (containerMatches.isEmpty) {
      return const [];
    }

    final lines = <LayoutLineData>[];
    for (var index = 0; index < containerMatches.length; index++) {
      final match = containerMatches[index];
      final lineNumber = int.tryParse(match.group(1) ?? '');
      if (lineNumber == null) {
        continue;
      }

      final start = match.start;
      final end =
          index + 1 < containerMatches.length
              ? containerMatches[index + 1].start
              : html.length;
      final segment = html.substring(start, end);

      final classMatch = RegExp(
        r'<div class="line([^"]*)" id="line-\d+">',
      ).firstMatch(segment);
      final classes = classMatch?.group(1) ?? '';
      final lineType = _parseLineType(classes);
      final isCentered =
          lineType != PageLineType.ayah || classes.contains('line--center');
      final surahMatch = RegExp(r'surah(\d{3})').firstMatch(segment);
      final surahNumber =
          surahMatch == null ? null : int.tryParse(surahMatch.group(1)!);
      final wordIds = [
        for (final wordMatch in RegExp(
          r'data-word-id="(\d+)"',
        ).allMatches(segment))
          int.parse(wordMatch.group(1)!),
      ];

      lines.add(
        LayoutLineData(
          lineNumber: lineNumber,
          lineType: lineType,
          isCentered: isCentered,
          surahNumber: surahNumber,
          wordIds: wordIds,
        ),
      );
    }

    return lines;
  }

  PageLineType _parseLineType(String classes) {
    if (classes.contains('line--surah-name')) {
      return PageLineType.surahName;
    }
    if (classes.contains('line--bismillah')) {
      return PageLineType.basmallah;
    }
    return PageLineType.ayah;
  }
}
