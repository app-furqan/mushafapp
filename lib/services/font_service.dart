import 'package:flutter/services.dart';

class FontService {
  static const int _totalPages = 604;
  static const String uthmanicHafsFamily = 'UthmanicHafs';
  static final Set<int> _loadedPages = <int>{};
  static final Map<int, Future<void>> _loadingPages = <int, Future<void>>{};

  /// Returns the font family name for a given page.
  ///
  /// [dark] selects the dark-mode palette (CPAL 0↔1 swapped).
  /// [flat] selects the no-tajweed variant where all COLR tajweed layers use
  /// the foreground colour (0xFFFF) while ayah-number ornament colours are
  /// preserved.
  static String fontFamilyForPage(
    int pageNumber, {
    bool dark = false,
    bool flat = false,
  }) {
    final n = pageNumber.clamp(1, _totalPages);
    if (flat) return dark ? 'QCF4V4FlatDkP$n' : 'QCF4V4FlatP$n';
    return dark ? 'QCF4V4DarkPage$n' : 'QCF4V4Page$n';
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

    // 1. Light variant — original (CPAL palette 0 = black ink + tajweed).
    final lightLoader = FontLoader(fontFamilyForPage(pageNumber));
    lightLoader.addFont(Future.value(byteData));

    // 2. Dark variant — palette 0↔1 swapped (white ink + dark tajweed).
    final darkData = _patchFont(byteData, swapPalettes: true);
    final darkLoader = FontLoader(fontFamilyForPage(pageNumber, dark: true));
    darkLoader.addFont(Future.value(darkData));

    // 3. Flat-light — tajweed COLR layers → 0xFFFF (foreground colour),
    //    ayah ornament layers preserved.
    final flatData = _patchFont(byteData, flattenTajweed: true);
    final flatLoader = FontLoader(fontFamilyForPage(pageNumber, flat: true));
    flatLoader.addFont(Future.value(flatData));

    // 4. Flat-dark — swap + flatten.
    final flatDarkData = _patchFont(
      byteData,
      swapPalettes: true,
      flattenTajweed: true,
    );
    final flatDarkLoader = FontLoader(
      fontFamilyForPage(pageNumber, dark: true, flat: true),
    );
    flatDarkLoader.addFont(Future.value(flatDarkData));

    await Future.wait([
      lightLoader.load(),
      darkLoader.load(),
      flatLoader.load(),
      flatDarkLoader.load(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Font-byte patching helpers
  // ---------------------------------------------------------------------------

  /// Finds the file offset of the table with the given 4-char [tag], or null.
  static int? _findTableOffset(ByteData data, String tag) {
    final numTables = data.getUint16(4);
    for (var i = 0; i < numTables; i++) {
      final recOff = 12 + i * 16;
      if (data.getUint8(recOff) == tag.codeUnitAt(0) &&
          data.getUint8(recOff + 1) == tag.codeUnitAt(1) &&
          data.getUint8(recOff + 2) == tag.codeUnitAt(2) &&
          data.getUint8(recOff + 3) == tag.codeUnitAt(3)) {
        return data.getUint32(recOff + 8);
      }
    }
    return null;
  }

  /// Returns a patched copy of [original].
  ///
  /// [swapPalettes] swaps CPAL colorRecordIndices 0 ↔ 1 so the dark palette
  /// becomes the default.
  ///
  /// [flattenTajweed] rewrites every COLR v0 layer record whose paletteIndex
  /// is NOT an ayah-number ornament entry (10, 11, 12) to 0xFFFF so the
  /// renderer uses the TextStyle foreground colour instead.
  static ByteData _patchFont(
    ByteData original, {
    bool swapPalettes = false,
    bool flattenTajweed = false,
  }) {
    final src = original.buffer.asUint8List(
      original.offsetInBytes,
      original.lengthInBytes,
    );
    final bytes = Uint8List.fromList(src);
    final data = ByteData.view(bytes.buffer);

    // --- CPAL palette swap ---------------------------------------------------
    if (swapPalettes) {
      final cpalOff = _findTableOffset(data, 'CPAL');
      if (cpalOff != null) {
        final idx0 = data.getUint16(cpalOff + 12);
        final idx1 = data.getUint16(cpalOff + 14);
        data.setUint16(cpalOff + 12, idx1);
        data.setUint16(cpalOff + 14, idx0);
      }
    }

    // --- COLR tajweed flatten ------------------------------------------------
    if (flattenTajweed) {
      final colrOff = _findTableOffset(data, 'COLR');
      if (colrOff != null) {
        final layerRecOff = colrOff + data.getUint32(colrOff + 8);
        final numLayers = data.getUint16(colrOff + 12);

        // Palette entries 10, 11, 12 are the decorative ayah-number ornament
        // colours and must be preserved.  Everything else (base ink, tajweed
        // marks, structural grays) is redirected to the foreground colour.
        const ornament = {10, 11, 12};
        for (var i = 0; i < numLayers; i++) {
          final palOff = layerRecOff + i * 4 + 2;
          final palIdx = data.getUint16(palOff);
          if (palIdx != 0xFFFF && !ornament.contains(palIdx)) {
            data.setUint16(palOff, 0xFFFF);
          }
        }
      }
    }

    return data;
  }
}
