import 'package:flutter/material.dart';

import '../models/chapter_model.dart';
import '../models/mushaf_display_mode.dart';
import '../models/page_data.dart';
import '../services/font_service.dart';

class MushafPageWidget extends StatelessWidget {
  final int pageNumber;
  final PageData? pageData; // null while loading
  final ChapterModel? chapterStart;
  final bool fontLoaded;
  final MushafDisplayMode displayMode;

  const MushafPageWidget({
    super.key,
    required this.pageNumber,
    required this.pageData,
    required this.chapterStart,
    required this.fontLoaded,
    required this.displayMode,
  });

  static const int _linesPerPage = 15;

  @override
  Widget build(BuildContext context) {
    final pageColor = displayMode.pageColor;
    final borderColor = displayMode.borderColor;
    final textColor = displayMode.textColor;

    return Container(
      color: pageColor,
      child: AspectRatio(
        aspectRatio: 0.65,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: pageColor,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            children: [
              _BorderBar(color: borderColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child:
                      pageData == null
                          ? _LoadingLines(textColor: textColor)
                          : _PageLines(
                            pageNumber: pageNumber,
                            pageData: pageData!,
                            chapterStart: chapterStart,
                            fontLoaded: fontLoaded,
                            textColor: textColor,
                            borderColor: borderColor,
                          ),
                ),
              ),
              _BorderBar(color: borderColor),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '$pageNumber',
                  style: TextStyle(color: textColor, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BorderBar extends StatelessWidget {
  final Color color;
  const _BorderBar({required this.color});

  @override
  Widget build(BuildContext context) => Container(height: 3, color: color);
}

class _LoadingLines extends StatelessWidget {
  final Color textColor;
  const _LoadingLines({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(MushafPageWidget._linesPerPage, (_) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _PageLines extends StatelessWidget {
  final int pageNumber;
  final PageData pageData;
  final ChapterModel? chapterStart;
  final bool fontLoaded;
  final Color textColor;
  final Color borderColor;

  const _PageLines({
    required this.pageNumber,
    required this.pageData,
    required this.chapterStart,
    required this.fontLoaded,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final fontFamily = FontService.fontFamilyForPage(pageNumber);
    final lineMap = {for (final l in pageData.lines) l.lineNumber: l};
    final minLine = pageData.minLine;
    final headerSlots = minLine - 1;

    return Column(
      children: List.generate(MushafPageWidget._linesPerPage, (slotIndex) {
        final lineNumber = slotIndex + 1;

        // Header area (surah name + bismillah) for pages that start a new surah
        if (lineNumber <= headerSlots) {
          return Expanded(child: _headerWidget(lineNumber, headerSlots));
        }

        final lineData = lineMap[lineNumber];
        if (lineData == null) {
          return const Expanded(child: SizedBox.shrink());
        }

        return Expanded(
          child: _LineContent(
            lineData: lineData,
            textColor: textColor,
            fontFamily: fontFamily,
            fontLoaded: fontLoaded,
          ),
        );
      }),
    );
  }

  Widget _headerWidget(int lineNumber, int totalHeaderSlots) {
    if (chapterStart == null) {
      return const SizedBox.shrink();
    }

    if (totalHeaderSlots == 1 && chapterStart!.bismillahPre) {
      return _BismillahLine(textColor: textColor);
    }

    if (totalHeaderSlots >= 2) {
      if (lineNumber == 1) {
        return _SurahNameBox(
          borderColor: borderColor,
          textColor: textColor,
          title: chapterStart!.nameArabic,
        );
      }
      if (lineNumber == 2 && chapterStart!.bismillahPre) {
        return _BismillahLine(textColor: textColor);
      }
    }
    return const SizedBox.shrink();
  }
}

/// Decorative surah name header box (uses QCF4Surah font for styling).
class _SurahNameBox extends StatelessWidget {
  final Color borderColor;
  final Color textColor;
  final String title;

  const _SurahNameBox({
    required this.borderColor,
    required this.textColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Text(
        'سورة $title',
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: FontService.uthmanicHafsFamily,
          fontFamilyFallback: const [FontService.surahFontFamily],
          fontSize: 18,
          color: textColor,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Bismillah line rendered with the page font.
class _BismillahLine extends StatelessWidget {
  final Color textColor;

  const _BismillahLine({required this.textColor});

  static const _bismillah = '\uFDFD';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Text(
        _bismillah,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: FontService.uthmanicHafsFamily,
          fontFamilyFallback: const [FontService.surahFontFamily],
          fontSize: 24,
          color: textColor,
          height: 1.4,
        ),
      ),
    );
  }
}

class _LineContent extends StatelessWidget {
  final LineData lineData;
  final Color textColor;
  final String fontFamily;
  final bool fontLoaded;

  const _LineContent({
    required this.lineData,
    required this.textColor,
    required this.fontFamily,
    required this.fontLoaded,
  });

  @override
  Widget build(BuildContext context) {
    if (!fontLoaded) {
      return Align(
        alignment: Alignment.centerRight,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            lineData.fallbackText,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily: FontService.uthmanicHafsFamily,
              fontSize: 22,
              color: textColor,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: RichText(
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.clip,
          text: TextSpan(
            children: [
              for (final word in lineData.words)
                TextSpan(
                  text: word.glyphText,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontFamilyFallback: const [FontService.uthmanicHafsFamily],
                    fontSize: 27,
                    color: textColor,
                    height: 1.45,
                    fontFeatures: const [
                      FontFeature.enable('liga'),
                      FontFeature.enable('calt'),
                      FontFeature.enable('rlig'),
                    ],
                  ),
                  semanticsLabel: word.text,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
