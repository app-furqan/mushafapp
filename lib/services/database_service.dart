import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/mushaf_type.dart';
import '../models/page_data.dart';
import '../models/word_model.dart';

class DatabaseService {
  static const int _lamCodePoint = 0x0644;
  static const Set<int> _alefCodePoints = {
    0x0622,
    0x0623,
    0x0625,
    0x0627,
    0x0671,
  };

  static DatabaseService? _instance;
  Database? _qpcDb;
  Database? _layoutDb;
  Database? _indopakLayoutDb;
  Database? _indopakWordsDb;
  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_qpcDb != null) return;
    _qpcDb = await _openAssetDb('assets/data/qpc-v4.db', 'qpc-v4.db');
    _layoutDb = await _openAssetDb(
      'assets/data/qpc-v4-tajweed-15-lines.db',
      'qpc-v4-tajweed-15-lines.db',
    );
  }

  Future<void> _initializeIndopak() async {
    if (_indopakLayoutDb != null) return;
    await initialize(); // ensure qpcDb is ready
    _indopakLayoutDb = await _openAssetDb(
      'assets/data/qudratullah-indopak-15-lines.db',
      'qudratullah-indopak-15-lines.db',
    );
    _indopakWordsDb = await _openAssetDb(
      'assets/data/indopak-nastaleeq.db',
      'indopak-nastaleeq.db',
    );
  }

  Future<Database> _openAssetDb(String assetPath, String fileName) async {
    final dir = await getApplicationSupportDirectory();
    final dbFile = File(p.join(dir.path, fileName));
    if (!dbFile.existsSync()) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await dbFile.writeAsBytes(bytes, flush: true);
    }
    return databaseFactoryFfi.openDatabase(
      dbFile.path,
      options: OpenDatabaseOptions(readOnly: true),
    );
  }

  Future<Database> get layoutDb async {
    await initialize();
    return _layoutDb!;
  }

  Future<PageData> getPage(
    int pageNumber, [
    MushafType mushafType = MushafType.hafs,
  ]) async {
    final Database activeLayoutDb;
    if (mushafType == MushafType.indopak) {
      await _initializeIndopak();
      activeLayoutDb = _indopakLayoutDb!;
    } else {
      await initialize();
      activeLayoutDb = _layoutDb!;
    }

    // 1. Fetch layout lines from layout DB
    final layoutRows = await activeLayoutDb.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number',
    );

    if (layoutRows.isEmpty) {
      return PageData(pageNumber: pageNumber, lines: const []);
    }

    // 2. For each ayah line, bulk-fetch words from appropriate words DB
    // Collect all needed word ID ranges first to do fewer queries
    final Database activeWordsDb =
        mushafType == MushafType.indopak ? _indopakWordsDb! : _qpcDb!;
    final List<LineData> lines = [];
    for (final row in layoutRows) {
      final lineNumber = row['line_number'] as int;
      final lineTypeStr = row['line_type'] as String;
      final isCentered = (row['is_centered'] as int) != 0;
      final surahNum = row['surah_number'];
      final surahNumber =
          surahNum is int && surahNum > 0
              ? surahNum
              : (surahNum is String && surahNum.isNotEmpty
                  ? int.tryParse(surahNum)
                  : null);

      final lineType = _parseLineType(lineTypeStr);

      List<WordModel> words = const [];
      if (lineType == PageLineType.ayah) {
        final firstId = row['first_word_id'];
        final lastId = row['last_word_id'];
        if (firstId != null && lastId != null) {
          final int first = firstId is int ? firstId : int.parse('$firstId');
          final int last = lastId is int ? lastId : int.parse('$lastId');
          if (first <= last) {
            final wordRows = await activeWordsDb.query(
              'words',
              where: 'id BETWEEN ? AND ?',
              whereArgs: [first, last],
              orderBy: 'id',
            );
            words =
                wordRows
                    .map(
                      (w) =>
                          _wordFromRow(w, pageNumber, lineNumber, mushafType),
                    )
                    .toList();
          }
        }
      }

      lines.add(
        LineData(
          lineNumber: lineNumber,
          lineType: lineType,
          isCentered: isCentered,
          surahNumber: surahNumber,
          words: words,
        ),
      );
    }

    return PageData(pageNumber: pageNumber, lines: lines);
  }

  PageLineType _parseLineType(String type) {
    return switch (type) {
      'surah_name' => PageLineType.surahName,
      'basmallah' => PageLineType.basmallah,
      _ => PageLineType.ayah,
    };
  }

  WordModel _wordFromRow(
    Map<String, dynamic> row,
    int pageNumber,
    int lineNumber,
    MushafType mushafType,
  ) {
    final id = row['id'] as int;
    final surah = row['surah'] as int;
    final ayah = row['ayah'] as int;
    final wordPos = row['word'] as int;
    final rawText = row['text'] as String;
    final glyphText =
        mushafType == MushafType.indopak
            ? _normalizeIndopakText(rawText)
            : rawText;
    final location = row['location'] as String? ?? '$surah:$ayah:$wordPos';
    // location is "surah:ayah:word", verseKey is "surah:ayah"
    final parts = location.split(':');
    final verseKey = parts.length >= 2 ? '${parts[0]}:${parts[1]}' : location;

    return WordModel(
      id: id,
      position: wordPos,
      text: glyphText,
      codeV2: glyphText,
      verseKey: verseKey,
      surahNumber: surah,
      ayahNumber: ayah,
      pageNumber: pageNumber,
      lineNumber: lineNumber,
      charTypeName: 'word',
    );
  }

  String _normalizeIndopakText(String text) {
    final codePoints = text.runes.toList(growable: false);
    if (codePoints.length < 3) {
      return text;
    }

    final normalized = <int>[];
    for (var index = 0; index < codePoints.length; index++) {
      final codePoint = codePoints[index];
      if (codePoint != _lamCodePoint) {
        normalized.add(codePoint);
        continue;
      }

      final marks = <int>[];
      var probe = index + 1;
      while (probe < codePoints.length && _isArabicMark(codePoints[probe])) {
        marks.add(codePoints[probe]);
        probe += 1;
      }

      if (marks.isEmpty ||
          probe >= codePoints.length ||
          !_alefCodePoints.contains(codePoints[probe])) {
        normalized.add(codePoint);
        continue;
      }

      normalized.add(_lamCodePoint);
      normalized.add(codePoints[probe]);
      normalized.addAll(marks);
      index = probe;
    }

    return String.fromCharCodes(normalized);
  }

  bool _isArabicMark(int codePoint) {
    return (codePoint >= 0x064B && codePoint <= 0x065F) || codePoint == 0x0670;
  }
}
