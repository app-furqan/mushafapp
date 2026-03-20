import 'package:flutter/material.dart';

import '../models/chapter_model.dart';
import '../models/mushaf_display_mode.dart';
import '../models/mushaf_type.dart';
import '../models/page_data.dart';
import '../services/font_service.dart';

class MushafPageWidget extends StatelessWidget {
  final int pageNumber;
  final PageData? pageData; // null while loading
  final Map<int, ChapterModel> chaptersById;
  final bool fontLoaded;
  final MushafDisplayMode displayMode;
  final bool showTajweed;
  final MushafType mushafType;

  const MushafPageWidget({
    super.key,
    required this.pageNumber,
    required this.pageData,
    required this.chaptersById,
    required this.fontLoaded,
    required this.displayMode,
    this.showTajweed = true,
    this.mushafType = MushafType.hafs,
  });

  @override
  Widget build(BuildContext context) {
    final pageColor = displayMode.pageColor;
    final borderColor = displayMode.borderColor;
    final textColor = displayMode.textColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: pageColor,
        border: Border.all(color: borderColor, width: 1.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            color: pageColor,
            border: Border.all(
              color: borderColor.withValues(alpha: 0.72),
              width: 0.75,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child:
                      pageData == null
                          ? _LoadingLines(
                            textColor: textColor,
                            linesPerPage: mushafType.linesPerPage,
                          )
                          : _PageLines(
                            pageNumber: pageNumber,
                            pageData: pageData!,
                            chaptersById: chaptersById,
                            fontLoaded: fontLoaded,
                            textColor: textColor,
                            borderColor: borderColor,
                            showTajweed: showTajweed,
                            displayMode: displayMode,
                            mushafType: mushafType,
                          ),
                ),
              ),
              _PageNumberDivider(
                pageNumber: pageNumber,
                textColor: textColor,
                borderColor: borderColor,
                pageColor: pageColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingLines extends StatelessWidget {
  final Color textColor;
  final int linesPerPage;
  const _LoadingLines({required this.textColor, this.linesPerPage = 15});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(linesPerPage, (_) {
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
  final Map<int, ChapterModel> chaptersById;
  final bool fontLoaded;
  final Color textColor;
  final Color borderColor;
  final bool showTajweed;
  final MushafDisplayMode displayMode;
  final MushafType mushafType;

  const _PageLines({
    required this.pageNumber,
    required this.pageData,
    required this.chaptersById,
    required this.fontLoaded,
    required this.textColor,
    required this.borderColor,
    required this.showTajweed,
    required this.displayMode,
    required this.mushafType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = displayMode.brightness == Brightness.dark;
    final String fontFamily;
    if (mushafType == MushafType.indopak) {
      fontFamily = FontService.indopakFontFamily;
    } else {
      fontFamily = FontService.fontFamilyForPage(
        pageNumber,
        dark: isDark,
        flat: !showTajweed,
      );
    }

    final linesPerPage = mushafType.linesPerPage;
    final lineSlots = List<LineData?>.generate(
      linesPerPage,
      (slotIndex) => pageData.lineFor(slotIndex + 1),
    );
    final centeredAyahCount =
        pageData.lines
            .where(
              (line) => line.lineType == PageLineType.ayah && line.isCentered,
            )
            .length;
    final hasTrailingBlanks = lineSlots.any((line) => line == null);
    final useCenteredProfile = centeredAyahCount >= 4 || hasTrailingBlanks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lineData in lineSlots)
          Flexible(
            flex:
                mushafType == MushafType.indopak
                    ? _indopakLineFlex(lineData)
                    : _hafsLineFlex(lineData, useCenteredProfile),
            child: _buildLineSlot(lineData, fontFamily),
          ),
      ],
    );
  }

  Widget _buildLineSlot(LineData? lineData, String fontFamily) {
    final line = _buildLine(lineData, fontFamily);
    if (mushafType != MushafType.indopak || lineData == null) {
      return line;
    }

    final verticalPadding = switch (lineData.lineType) {
      PageLineType.surahName => 1.5,
      PageLineType.basmallah => 1.0,
      PageLineType.ayah => 0.75,
    };

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: line,
    );
  }

  Widget _buildLine(LineData? lineData, String fontFamily) {
    if (lineData == null) {
      return const SizedBox.shrink();
    }

    return switch (lineData.lineType) {
      PageLineType.surahName =>
        mushafType == MushafType.indopak
            ? _SurahNameTextBox(
              textColor: textColor,
              borderColor: borderColor,
              surahNumber: lineData.surahNumber ?? 1,
              chaptersById: chaptersById,
            )
            : _SurahNameBox(
              textColor: textColor,
              borderColor: borderColor,
              surahNumber: lineData.surahNumber ?? 1,
            ),
      PageLineType.basmallah => _BismillahLine(
        textColor: textColor,
        fontFamily: fontFamily,
      ),
      PageLineType.ayah => _LineContent(
        lineData: lineData,
        textColor: textColor,
        fontFamily: fontFamily,
        fontLoaded: fontLoaded,
        showTajweed: showTajweed,
      ),
    };
  }

  // IndoPak: keep the same 15-slot grid visible on every page, including the
  // introductory pages where the final slots are intentionally blank.
  int _indopakLineFlex(LineData? lineData) {
    if (lineData == null) {
      return 100;
    }

    return switch (lineData.lineType) {
      PageLineType.surahName => 72,
      PageLineType.basmallah => 88,
      PageLineType.ayah => 100,
    };
  }

  // Hafs (QCF4): fixed-slot flex weights matching the printed 15-line grid.
  int _hafsLineFlex(LineData? lineData, bool useCenteredProfile) {
    if (lineData == null) {
      return 100;
    }
    return switch (lineData.lineType) {
      PageLineType.surahName => 55,
      PageLineType.basmallah => 80,
      PageLineType.ayah when lineData.isCentered => 90,
      PageLineType.ayah => 100,
    };
  }
}

class _PageNumberDivider extends StatelessWidget {
  final int pageNumber;
  final Color textColor;
  final Color borderColor;
  final Color pageColor;

  const _PageNumberDivider({
    required this.pageNumber,
    required this.textColor,
    required this.borderColor,
    required this.pageColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 18, top: 2, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: borderColor.withValues(alpha: 0.52),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: pageColor,
              border: Border.all(
                color: borderColor.withValues(alpha: 0.76),
                width: 0.95,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$pageNumber',
              style: TextStyle(
                color: textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: borderColor.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative surah name banner.
///
/// Renders the per-surah glyph from QCF4Surah (U+F100 + surahNumber − 1)
/// centred inside a decorative double-border frame.  The glyph is sized with
/// [FittedBox.scaleDown] so it never overflows.
class _SurahNameBox extends StatelessWidget {
  final Color textColor;
  final Color borderColor;
  final int surahNumber;

  const _SurahNameBox({
    required this.textColor,
    required this.borderColor,
    required this.surahNumber,
  });

  @override
  Widget build(BuildContext context) {
    final n = surahNumber.clamp(1, 114);
    final glyph = String.fromCharCode(0xF100 + n - 1);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor.withValues(alpha: 0.8),
          width: 0.95,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: borderColor.withValues(alpha: 0.42),
            width: 0.65,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                glyph,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: FontService.surahFontFamily,
                  fontSize: 48,
                  color: textColor,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Surah name banner for the IndoPak edition.
///
/// Uses the Arabic surah name from chapter metadata instead of the QCF4Surah
/// glyph font, because the IndoPak edition does not use per-page QCF4 fonts.
class _SurahNameTextBox extends StatelessWidget {
  final Color textColor;
  final Color borderColor;
  final int surahNumber;
  final Map<int, ChapterModel> chaptersById;

  const _SurahNameTextBox({
    required this.textColor,
    required this.borderColor,
    required this.surahNumber,
    required this.chaptersById,
  });

  @override
  Widget build(BuildContext context) {
    final n = surahNumber.clamp(1, 114);
    final name = chaptersById[n]?.nameArabic ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor.withValues(alpha: 0.85),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: borderColor.withValues(alpha: 0.45),
            width: 0.7,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Text(
                name,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: FontService.indopakFontFamily,
                  fontSize: 26,
                  color: textColor,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bismillah line rendered with the page font.
class _BismillahLine extends StatelessWidget {
  final Color textColor;
  final String fontFamily;

  const _BismillahLine({required this.textColor, required this.fontFamily});

  static const _bismillah = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِیْمِ';
  static const _bismillahHafs = '\uFDFD';

  bool get _isIndopak => fontFamily == FontService.indopakFontFamily;

  @override
  Widget build(BuildContext context) {
    final text = _isIndopak ? _bismillah : _bismillahHafs;
    return Align(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            text,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback:
                  _isIndopak
                      ? null
                      : const [
                        FontService.uthmanicHafsFamily,
                        FontService.surahFontFamily,
                      ],
              fontSize: _isIndopak ? 28 : 22,
              color: textColor,
              height: 1.15,
            ),
          ),
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
  final bool showTajweed;

  const _LineContent({
    required this.lineData,
    required this.textColor,
    required this.fontFamily,
    required this.fontLoaded,
    required this.showTajweed,
  });

  @override
  Widget build(BuildContext context) {
    final isIndopak = fontFamily == FontService.indopakFontFamily;
    final lineAlignment =
        isIndopak
            ? Alignment.center
            : (lineData.isCentered ? Alignment.center : Alignment.centerRight);
    final lineTextAlign =
        isIndopak
            ? TextAlign.center
            : (lineData.isCentered ? TextAlign.center : TextAlign.right);

    if (!fontLoaded) {
      return Align(
        alignment: lineAlignment,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            lineData.fallbackText,
            textDirection: TextDirection.rtl,
            textAlign: lineTextAlign,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily:
                  isIndopak
                      ? FontService.indopakFontFamily
                      : FontService.uthmanicHafsFamily,
              fontFamilyFallback:
                  isIndopak ? null : const [FontService.uthmanicHafsFamily],
              fontSize: isIndopak ? 22.5 : 21,
              color: textColor,
              height: isIndopak ? 1.0 : 1.18,
            ),
          ),
        ),
      );
    }

    final layoutResult = LayoutBuilder(
      builder: (context, constraints) {
        // Measure all words at a stable base size first.
        final baseSize = isIndopak ? 22.5 : 25.5;
        final lineHeight = isIndopak ? 1.0 : 1.08;
        final baseStyle = TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback:
              isIndopak ? null : const [FontService.uthmanicHafsFamily],
          fontSize: baseSize,
          color: textColor,
          height: lineHeight,
          fontFeatures: const [
            FontFeature.enable('liga'),
            FontFeature.enable('calt'),
            FontFeature.enable('rlig'),
          ],
        );

        final wordWidths = [
          for (final word in lineData.words)
            _measureWordWidth(context, word.glyphText, baseStyle),
        ];
        final contentWidth = wordWidths.fold<double>(
          0,
          (sum, width) => sum + width,
        );
        final gapCount =
            lineData.words.length > 1 ? lineData.words.length - 1 : 1;
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : contentWidth;

        // IndoPak lines look cleaner when the font size stays stable and the
        // remaining width is absorbed mostly as word spacing. Hafs keeps the
        // more aggressive per-line fitting used by the page fonts.
        final double fontSize;
        final double gapWidth;
        final minGapWidth = isIndopak ? 3.0 : 1.5;
        if (lineData.isCentered || contentWidth < 1) {
          fontSize = baseSize;
          gapWidth = minGapWidth;
        } else if (isIndopak) {
          final preferredGap = ((availableWidth - contentWidth) / gapCount)
              .clamp(minGapWidth, 12.0);
          final widthWithPreferredGaps = contentWidth + preferredGap * gapCount;

          if (widthWithPreferredGaps <= availableWidth) {
            fontSize = baseSize;
            gapWidth = preferredGap;
          } else {
            final totalFixedGap = minGapWidth * gapCount;
            final scaleFactor = (availableWidth - totalFixedGap) / contentWidth;
            fontSize = (baseSize * scaleFactor).clamp(
              baseSize * 0.82,
              baseSize * 1.06,
            );
            gapWidth = minGapWidth;
          }
        } else {
          final totalFixedGap = minGapWidth * gapCount;
          final scaleFactor = (availableWidth - totalFixedGap) / contentWidth;
          fontSize = (baseSize * scaleFactor).clamp(
            baseSize * 0.4,
            baseSize * 4.0,
          );
          gapWidth = minGapWidth;
        }

        final style = TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback:
              isIndopak ? null : const [FontService.uthmanicHafsFamily],
          fontSize: fontSize,
          color: textColor,
          height: lineHeight,
          fontFeatures: const [
            FontFeature.enable('liga'),
            FontFeature.enable('calt'),
            FontFeature.enable('rlig'),
          ],
        );

        final row = Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              for (var index = 0; index < lineData.words.length; index++) ...[
                Semantics(
                  label: lineData.words[index].text,
                  child: ExcludeSemantics(
                    child: Text(
                      lineData.words[index].glyphText,
                      textDirection: TextDirection.rtl,
                      style: style,
                    ),
                  ),
                ),
                if (index < lineData.words.length - 1)
                  SizedBox(width: gapWidth),
              ],
            ],
          ),
        );

        return Align(
          alignment: lineAlignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: lineAlignment,
            child: row,
          ),
        );
      },
    );
    // When tajweed is disabled the "flat" font variant is used (selected in
    // _PageLines) which redirects all COLR tajweed layers to the foreground
    // colour (0xFFFF) at the font level, so no widget-level colour filter is
    // needed.  Ayah-number ornament colours (palette entries 10-12) are
    // preserved by the flat variant.
    return layoutResult;
  }

  double _measureWordWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}
