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

  const MushafPageWidget({
    super.key,
    required this.pageNumber,
    required this.pageData,
    required this.chaptersById,
    required this.fontLoaded,
    required this.displayMode,
  });

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

  const _PageLines({
    required this.pageNumber,
    required this.pageData,
    required this.chaptersById,
    required this.fontLoaded,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final fontFamily = FontService.fontFamilyForPage(pageNumber);

    return Column(
      children: List.generate(PageData.totalLines, (slotIndex) {
        final lineNumber = slotIndex + 1;
        final lineData = pageData.lineFor(lineNumber);
        if (lineData == null) {
          return const Expanded(child: SizedBox.shrink());
        }

        final chapter =
            lineData.surahNumber == null
                ? null
                : chaptersById[lineData.surahNumber!];

        return Expanded(
          child: switch (lineData.lineType) {
            PageLineType.surahName => _SurahNameBox(
              borderColor: borderColor,
              textColor: textColor,
              title: chapter?.nameArabic ?? '',
            ),
            PageLineType.basmallah => _BismillahLine(textColor: textColor),
            PageLineType.ayah => _LineContent(
              lineData: lineData,
              textColor: textColor,
              fontFamily: fontFamily,
              fontLoaded: fontLoaded,
            ),
          },
        );
      }),
    );
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
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor.withValues(alpha: 0.82),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: borderColor.withValues(alpha: 0.48),
            width: 0.75,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: borderColor.withValues(alpha: 0.34),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                'سورة $title',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: FontService.uthmanicHafsFamily,
                  fontFamilyFallback: const [FontService.surahFontFamily],
                  fontSize: 17,
                  color: textColor,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: borderColor.withValues(alpha: 0.34),
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(vertical: 1),
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

    final style = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: const [FontService.uthmanicHafsFamily],
      fontSize: 25.5,
      color: textColor,
      height: 1.08,
      fontFeatures: const [
        FontFeature.enable('liga'),
        FontFeature.enable('calt'),
        FontFeature.enable('rlig'),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wordWidths = [
          for (final word in lineData.words)
            _measureWordWidth(context, word.glyphText, style),
        ];
        final contentWidth = wordWidths.fold<double>(
          0,
          (sum, width) => sum + width,
        );
        final gapCount =
            lineData.words.length > 1 ? lineData.words.length - 1 : 1;
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : contentWidth;
        final freeSpace = (availableWidth - contentWidth).clamp(0.0, 160.0);

        final gapWidth =
            lineData.isCentered
                ? 1.5
                : gapCount == 0
                ? 0.0
                : (freeSpace / gapCount).clamp(1.5, 18.0);

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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: availableWidth),
              child: row,
            ),
          ),
        );
      },
    );
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
