import 'package:flutter/services.dart';

import '../models/indopak_font_choice.dart';
import '../models/page_font_source.dart';

class FontService {
  static const int _totalPages = 604;
  static const String uthmanicHafsFamily = 'UthmanicHafs';
  static const String indopakFontFamily = 'IndopakNastaleeq';
  static const String kfgqpcNastaleeqFontFamily = 'KFGQPCNastaleeq';
  static const String digitalKhattIndoPakFontFamily = 'DigitalKhattIndoPak';
  static const String nastaleeqFontFamily = 'Nastaleeq';
  static final Set<String> _loadedPages = <String>{};
  static final Map<String, Future<void>> _loadingPages =
      <String, Future<void>>{};

  static final Set<IndopakFontChoice> _loadedIndopakFonts =
      <IndopakFontChoice>{};
  static final Map<IndopakFontChoice, Future<void>> _loadingIndopakFonts =
      <IndopakFontChoice, Future<void>>{};

  static Future<void> ensureIndopakFontLoaded([
    IndopakFontChoice choice = IndopakFontChoice.indopak,
  ]) {
    if (_loadedIndopakFonts.contains(choice)) {
      return Future.value();
    }
    final inFlight = _loadingIndopakFonts[choice];
    if (inFlight != null) {
      return inFlight;
    }
    final future = _loadIndopakFont(choice);
    _loadingIndopakFonts[choice] = future;
    return future.whenComplete(() {
      _loadingIndopakFonts.remove(choice);
      _loadedIndopakFonts.add(choice);
    });
  }

  static Future<void> _loadIndopakFont(IndopakFontChoice choice) async {
    final assetPath = switch (choice) {
      IndopakFontChoice.indopak => 'assets/fonts/indopak.ttf',
      IndopakFontChoice.kfgqpcNastaleeq =>
        'assets/fonts/KFGQPCNastaleeq-Regular.ttf',
      IndopakFontChoice.digitalKhattIndoPak =>
        'assets/fonts/DigitalKhattIndoPak.otf',
      IndopakFontChoice.nastaleeq => 'assets/fonts/Nastaleeq.ttf',
    };
    final byteData = await rootBundle.load(assetPath);
    final loader = FontLoader(fontFamilyForIndopakChoice(choice));
    loader.addFont(Future.value(byteData));
    await loader.load();
  }

  static String fontFamilyForIndopakChoice(IndopakFontChoice choice) {
    return switch (choice) {
      IndopakFontChoice.indopak => indopakFontFamily,
      IndopakFontChoice.kfgqpcNastaleeq => kfgqpcNastaleeqFontFamily,
      IndopakFontChoice.digitalKhattIndoPak => digitalKhattIndoPakFontFamily,
      IndopakFontChoice.nastaleeq => nastaleeqFontFamily,
    };
  }

  static bool isIndopakFontFamily(String fontFamily) {
    return fontFamily == indopakFontFamily ||
        fontFamily == kfgqpcNastaleeqFontFamily ||
        fontFamily == digitalKhattIndoPakFontFamily ||
        fontFamily == nastaleeqFontFamily;
  }

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
    PageFontSource source = PageFontSource.edited,
  }) {
    final n = pageNumber.clamp(1, _totalPages);
    final prefix = 'QCF4V4${source.familyKey}';
    if (flat) return dark ? '${prefix}FlatDkP$n' : '${prefix}FlatP$n';
    return dark ? '${prefix}DarkPage$n' : '${prefix}Page$n';
  }

  static const String surahFontFamily = 'QCF4Surah';

  static String _pageKey(int pageNumber, PageFontSource source) {
    return '${source.name}:$pageNumber';
  }

  static bool isFontLoaded(
    int pageNumber, {
    PageFontSource source = PageFontSource.edited,
  }) => _loadedPages.contains(_pageKey(pageNumber, source));

  static Future<void> ensureFontLoaded(
    int pageNumber, {
    PageFontSource source = PageFontSource.edited,
  }) {
    final normalized = pageNumber.clamp(1, _totalPages);
    final key = _pageKey(normalized, source);
    if (_loadedPages.contains(key)) {
      return Future.value();
    }
    final inFlight = _loadingPages[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadFromAssets(normalized, source: source);
    _loadingPages[key] = future;
    return future.whenComplete(() {
      _loadingPages.remove(key);
      _loadedPages.add(key);
    });
  }

  static void prefetchAdjacent(
    int pageNumber, {
    PageFontSource source = PageFontSource.edited,
  }) {
    for (final candidate in <int>[pageNumber - 1, pageNumber + 1]) {
      if (candidate >= 1 && candidate <= _totalPages) {
        ensureFontLoaded(candidate, source: source);
      }
    }
  }

  static Future<void> _loadFromAssets(
    int pageNumber, {
    required PageFontSource source,
  }) async {
    final byteData = await rootBundle.load(
      '${source.assetDirectory}/p$pageNumber.ttf',
    );

    // 1. Light variant — original (CPAL palette 0 = black ink + tajweed).
    final lightLoader = FontLoader(
      fontFamilyForPage(pageNumber, source: source),
    );
    lightLoader.addFont(Future.value(byteData));

    // 2. Dark variant — palette 0↔1 swapped (white ink + dark tajweed).
    final darkData = _patchFont(byteData, swapPalettes: true);
    final darkLoader = FontLoader(
      fontFamilyForPage(pageNumber, dark: true, source: source),
    );
    darkLoader.addFont(Future.value(darkData));

    // 3. Flat-light — tajweed COLR layers → 0xFFFF (foreground colour),
    //    ayah ornament layers preserved.
    final flatData = _patchFont(byteData, flattenTajweed: true);
    final flatLoader = FontLoader(
      fontFamilyForPage(pageNumber, flat: true, source: source),
    );
    flatLoader.addFont(Future.value(flatData));

    // 4. Flat-dark — swap + flatten.
    final flatDarkData = _patchFont(
      byteData,
      swapPalettes: true,
      flattenTajweed: true,
    );
    final flatDarkLoader = FontLoader(
      fontFamilyForPage(pageNumber, dark: true, flat: true, source: source),
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
