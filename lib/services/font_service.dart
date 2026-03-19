import 'package:flutter/services.dart';

class FontService {
  static const int _totalPages = 604;
  static const String uthmanicHafsFamily = 'UthmanicHafs';
  static final Set<int> _loadedPages = <int>{};
  static final Map<int, Future<void>> _loadingPages = <int, Future<void>>{};

  static String fontFamilyForPage(int pageNumber, {bool dark = false}) {
    final normalized = pageNumber.clamp(1, _totalPages);
    return dark ? 'QCF4V4DarkPage$normalized' : 'QCF4V4Page$normalized';
  }

  static const String surahFontFamily = 'QCF4Surah';

  static bool isFontLoaded(int pageNumber) => _loadedPages.contains(pageNumber);

  static Future<void> ensureFontLoaded(int pageNumber) {
    final normalized = pageNumber.clamp(1, _totalPages);
    if (_loadedPages.contains(normalized)) {
      return Future.value();
    }
    final inFlight = _loadingPages[normalized];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadFromAssets(normalized);
    _loadingPages[normalized] = future;
    return future.whenComplete(() {
      _loadingPages.remove(normalized);
      _loadedPages.add(normalized);
    });
  }

  static void prefetchAdjacent(int pageNumber) {
    for (final candidate in <int>[pageNumber - 1, pageNumber + 1]) {
      if (candidate >= 1 && candidate <= _totalPages) {
        ensureFontLoaded(candidate);
      }
    }
  }

  static Future<void> _loadFromAssets(int pageNumber) async {
    final byteData = await rootBundle.load('assets/fonts/v4/p$pageNumber.ttf');

    // Register light variant (CPAL palette 0 = black ink + tajweed colours).
    final lightFamily = fontFamilyForPage(pageNumber);
    final lightLoader = FontLoader(lightFamily);
    lightLoader.addFont(Future.value(byteData));

    // Register dark variant (CPAL palette 0↔1 swapped so palette 1 — white
    // ink + adjusted tajweed colours — becomes the default).
    final darkData = _patchCpalPaletteSwap(byteData);
    final darkFamily = fontFamilyForPage(pageNumber, dark: true);
    final darkLoader = FontLoader(darkFamily);
    darkLoader.addFont(Future.value(darkData));

    await Future.wait([lightLoader.load(), darkLoader.load()]);
  }

  /// Returns a copy of [original] with the CPAL palette indices 0 and 1
  /// swapped so the dark-mode palette becomes the default.
  static ByteData _patchCpalPaletteSwap(ByteData original) {
    final src = original.buffer.asUint8List(
      original.offsetInBytes,
      original.lengthInBytes,
    );
    final bytes = Uint8List.fromList(src);
    final data = ByteData.view(bytes.buffer);

    // Parse OTF/TTF table directory to find CPAL table offset.
    final numTables = data.getUint16(4); // big-endian
    int? cpalOffset;
    for (var i = 0; i < numTables; i++) {
      final recOff = 12 + i * 16;
      // 'CPAL' = 0x43 0x50 0x41 0x4C
      if (data.getUint8(recOff) == 0x43 &&
          data.getUint8(recOff + 1) == 0x50 &&
          data.getUint8(recOff + 2) == 0x41 &&
          data.getUint8(recOff + 3) == 0x4C) {
        cpalOffset = data.getUint32(recOff + 8);
        break;
      }
    }
    if (cpalOffset == null) return original;

    // CPAL layout: ...+12 = colorRecordIndices[0], +14 = colorRecordIndices[1]
    final idx0 = data.getUint16(cpalOffset + 12);
    final idx1 = data.getUint16(cpalOffset + 14);
    data.setUint16(cpalOffset + 12, idx1);
    data.setUint16(cpalOffset + 14, idx0);

    return data;
  }
}
