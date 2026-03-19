import 'package:flutter/material.dart';

import '../models/chapter_model.dart';
import '../models/mushaf_display_mode.dart';
import '../models/page_data.dart';
import '../services/font_service.dart';

class MushafPageWidget extends StatelessWidget {
  final int pageNumber;
  final PageData? pageData; // null while loading
  final Map<int, ChapterModel> chaptersById;
  final bool fontLoaded;
  final MushafDisplayMode displayMode;
  final bool showTajweed;

  const MushafPageWidget({
    super.key,
    required this.pageNumber,
    required this.pageData,
    required this.chaptersById,
    required this.fontLoaded,
    required this.displayMode,
    this.showTajweed = true,
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
                          ? _LoadingLines(textColor: textColor)
                          : _PageLines(
                            pageNumber: pageNumber,
                            pageData: pageData!,
                            chaptersById: chaptersById,
                            fontLoaded: fontLoaded,
                            textColor: textColor,
                            borderColor: borderColor,
                            showTajweed: showTajweed,
                            displayMode: displayMode,
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
  const _LoadingLines({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(PageData.totalLines, (_) {
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

  const _PageLines({
    required this.pageNumber,
    required this.pageData,
    required this.chaptersById,
    required this.fontLoaded,
    required this.textColor,
    required this.borderColor,
    required this.showTajweed,
    required this.displayMode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = displayMode.brightness == Brightness.dark;
    final fontFamily = FontService.fontFamilyForPage(
      pageNumber,
      dark: isDark,
      flat: !showTajweed,
    );
    final lineSlots = List<LineData?>.generate(
      PageData.totalLines,
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

    // The page always has a fixed aspect-ratio parent (AspectRatio widget in
    // MushafScreen), so this Column receives a finite bounded height.
    // Flexible distributes that height proportionally across the 15 line slots
    // so each line has exactly that much vertical space and text is centred
    // inside it — matching the evenly-spaced appearance of the printed mushaf.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lineData in lineSlots)
          Flexible(
            flex: _lineFlex(lineData, useCenteredProfile),
            child: _buildLine(lineData, fontFamily),
          ),
      ],
    );
  }

  Widget _buildLine(LineData? lineData, String fontFamily) {
    if (lineData == null) {
      return const SizedBox.shrink();
    }

    return switch (lineData.lineType) {
      PageLineType.surahName => _SurahNameBox(
        textColor: textColor,
        borderColor: borderColor,
        surahNumber: lineData.surahNumber ?? 1,
      ),
      PageLineType.basmallah => _BismillahLine(textColor: textColor),
      PageLineType.ayah => _LineContent(
        lineData: lineData,
        textColor: textColor,
        fontFamily: fontFamily,
        fontLoaded: fontLoaded,
        showTajweed: showTajweed,
      ),
    };
  }

  int _lineFlex(LineData? lineData, bool useCenteredProfile) {
    // Each flex unit = 1/Σflex of the available page-text-area height.
    // All 15 slots must sum to the same total whether the page is normal or
    // has surah headers, so lines given smaller flex compensate with larger
    // flex on adjacent lines via the "null" blank-slot weight.
    if (lineData == null) {
      // Trailing blank slot — give it the same weight as a normal ayah line
      // so pages that end early still space out evenly.
      return 100;
    }

    // Surah header (frame glyph) is very wide and short (~10:1 aspect ratio).
    // Give it a small but non-trivial slot so it doesn't crowd adjacent lines.
    // Bismillah is taller (large glyph), gets a bit more.
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

/// Bismillah line rendered with the page font.
class _BismillahLine extends StatelessWidget {
  final Color textColor;

  const _BismillahLine({required this.textColor});

  static const _bismillah = '\uFDFD';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        // Top padding ensures a clear gap below the surah header above.
        padding: const EdgeInsets.only(top: 4, bottom: 1),
        child: Text(
          _bismillah,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: FontService.uthmanicHafsFamily,
            fontFamilyFallback: const [FontService.surahFontFamily],
            fontSize: 22,
            color: textColor,
            height: 1.05,
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
    if (!fontLoaded) {
      return Align(
        alignment:
            lineData.isCentered ? Alignment.center : Alignment.centerRight,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            lineData.fallbackText,
            textDirection: TextDirection.rtl,
            textAlign: lineData.isCentered ? TextAlign.center : TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily: FontService.uthmanicHafsFamily,
              fontSize: 21,
              color: textColor,
              height: 1.18,
            ),
          ),
        ),
      );
    }

    final layoutResult = LayoutBuilder(
      builder: (context, constraints) {
        // Measure all words at a stable base size first.
        const double baseSize = 25.5;
        final baseStyle = TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: const [FontService.uthmanicHafsFamily],
          fontSize: baseSize,
          color: textColor,
          height: 1.08,
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

        // For non-centered (full-justification) lines, scale the font so the
        // words fill the available width exactly with a minimal 1.5 px gap
        // between each word.  Centered lines keep the base size and are
        // positioned by Align.center below.
        final double fontSize;
        const double gapWidth = 1.5;
        if (lineData.isCentered || contentWidth < 1) {
          fontSize = baseSize;
        } else {
          final totalFixedGap = gapWidth * gapCount;
          final scaleFactor = (availableWidth - totalFixedGap) / contentWidth;
          fontSize = (baseSize * scaleFactor).clamp(
            baseSize * 0.4,
            baseSize * 4.0,
          );
        }

        final style = TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: const [FontService.uthmanicHafsFamily],
          fontSize: fontSize,
          color: textColor,
          height: 1.08,
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
          alignment:
              lineData.isCentered ? Alignment.center : Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment:
                lineData.isCentered ? Alignment.center : Alignment.centerRight,
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
