import 'package:flutter/services.dart';

class FontService {
  static const int _totalPages = 604;
  static const String uthmanicHafsFamily = 'UthmanicHafs';
  static final Set<int> _loadedPages = <int>{};
  static final Map<int, Future<void>> _loadingPages = <int, Future<void>>{};

  static String fontFamilyForPage(int pageNumber) {
    final normalized = pageNumber.clamp(1, _totalPages);
    return 'QCF4V4Page$normalized';
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
    final family = fontFamilyForPage(pageNumber);
    final byteData = await rootBundle.load('assets/fonts/v4/p$pageNumber.ttf');
    final loader = FontLoader(family);
    loader.addFont(Future.value(byteData));
    await loader.load();
  }
}
