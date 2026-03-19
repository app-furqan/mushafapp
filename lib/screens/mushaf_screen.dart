import 'package:flutter/material.dart';

import '../models/chapter_model.dart';
import '../models/mushaf_display_mode.dart';
import '../models/page_data.dart';
import '../services/chapter_service.dart';
import '../services/font_service.dart';
import '../services/quran_api_service.dart';
import '../widgets/mushaf_page_widget.dart';

class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  static const int _totalPages = 604;
  static const int _initialPage = 1;

  late final PageController _pageController;
  final _apiService = QuranApiService();
  final _chapterService = ChapterService();

  final _dataReady = <int, PageData?>{};
  final _dataFutures = <int, Future<PageData>>{};
  final _fontReady = <int, bool>{};
  final _fontFutures = <int, Future<void>>{};
  Map<int, ChapterModel> _chaptersById = const {};

  int _currentPage = _initialPage;
  bool _showBottomBar = true;
  bool _showLegend = false;
  MushafDisplayMode _displayMode = MushafDisplayMode.light;
  bool _tajweedEnabled = true;
  final _zoomNotifier = ValueNotifier<double>(1.0);
  late final TextEditingController _pageInputController;
  late final FocusNode _pageInputFocusNode;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage - 1);
    _pageInputController = TextEditingController(text: '$_initialPage');
    _pageInputFocusNode = FocusNode();
    _loadChapterMetadata();
    _loadPageData(_initialPage);
    _loadPageData(_initialPage + 1);
    _loadPageFont(_initialPage);
    _loadPageFont(_initialPage + 1);
  }

  Future<void> _loadChapterMetadata() async {
    try {
      final chapters = await _chapterService.getChapters();
      final chaptersById = <int, ChapterModel>{};
      for (final chapter in chapters) {
        chaptersById[chapter.id] = chapter;
      }
      if (mounted) {
        setState(() {
          _chaptersById = chaptersById;
        });
      }
    } catch (error) {
      debugPrint('Error loading chapter metadata: $error');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _zoomNotifier.dispose();
    _pageInputController.dispose();
    _pageInputFocusNode.dispose();
    super.dispose();
  }

  void _loadPageData(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _totalPages) return;
    if (_dataFutures.containsKey(pageNumber)) return;
    final future = _apiService
        .getPage(pageNumber)
        .then((data) {
          if (mounted) setState(() => _dataReady[pageNumber] = data);
          return data;
        })
        .catchError((e) {
          debugPrint('Error loading page $pageNumber: $e');
          return PageData(pageNumber: pageNumber, lines: const []);
        });
    _dataFutures[pageNumber] = future;
  }

  void _loadPageFont(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _totalPages) return;
    if (_fontFutures.containsKey(pageNumber)) return;

    final future = FontService.ensureFontLoaded(pageNumber)
        .then((_) {
          if (mounted) {
            setState(() => _fontReady[pageNumber] = true);
          }
        })
        .catchError((error) {
          debugPrint('Error loading font for page $pageNumber: $error');
          if (mounted) {
            setState(() => _fontReady[pageNumber] = false);
          }
        });
    _fontFutures[pageNumber] = future;
  }

  void _onPageChanged(int index) {
    final pageNumber = index + 1;
    _zoomNotifier.value = 1.0;
    setState(() => _currentPage = pageNumber);
    // Keep the text box in sync when the user swipes between pages.
    if (!_pageInputFocusNode.hasFocus) {
      _pageInputController.text = '$pageNumber';
    }
    for (final p in [pageNumber - 1, pageNumber, pageNumber + 1]) {
      _loadPageData(p);
      _loadPageFont(p);
    }
    FontService.prefetchAdjacent(pageNumber);
  }

  void _jumpToPage(int pageNumber) {
    final target = pageNumber.clamp(1, _totalPages);
    _pageController.jumpToPage(target - 1);
    _loadPageData(target);
    _loadPageFont(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _displayMode.scaffoldColor,
      body: GestureDetector(
        onTap:
            () => setState(() {
              _showBottomBar = !_showBottomBar;
              if (!_showBottomBar) _showLegend = false;
            }),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _totalPages,
              onPageChanged: _onPageChanged,
              reverse: true,
              itemBuilder: (context, index) {
                final pageNumber = index + 1;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadPageData(pageNumber);
                  _loadPageFont(pageNumber);
                });
                return _ZoomablePage(
                  zoomNotifier: _zoomNotifier,
                  child: ColoredBox(
                    color: _displayMode.scaffoldColor,
                    child: Center(
                      child: AspectRatio(
                        // Standard Hafs mushaf is ~17 × 24 cm (ratio ≈ 0.71).
                        // 0.67 leaves a little room for the outer border/padding.
                        aspectRatio: 0.67,
                        child: MushafPageWidget(
                          pageNumber: pageNumber,
                          pageData: _dataReady[pageNumber],
                          chaptersById: _chaptersById,
                          fontLoaded: _fontReady[pageNumber] ?? false,
                          displayMode: _displayMode,
                          showTajweed: _tajweedEnabled,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_showBottomBar) _buildBottomBar(),
            if (_showLegend)
              _TajweedLegend(
                displayMode: _displayMode,
                onClose: () => setState(() => _showLegend = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isDark = _displayMode.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          color: _displayMode.overlayBarColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              PopupMenuButton<MushafDisplayMode>(
                tooltip: 'Display mode',
                initialValue: _displayMode,
                onSelected: (mode) => setState(() => _displayMode = mode),
                itemBuilder: (context) {
                  return MushafDisplayMode.values
                      .map(
                        (mode) => PopupMenuItem<MushafDisplayMode>(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList();
                },
                icon: Icon(Icons.palette_outlined, color: textColor),
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next),
                tooltip: 'Previous page',
                onPressed:
                    _currentPage < _totalPages
                        ? () => _jumpToPage(_currentPage + 1)
                        : null,
                color: textColor,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: Slider(
                  value: _currentPage.toDouble(),
                  min: 1,
                  max: _totalPages.toDouble(),
                  divisions: _totalPages - 1,
                  label: 'Page $_currentPage',
                  onChanged: (v) => _jumpToPage(v.round()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.navigate_before),
                tooltip: 'Next page',
                onPressed:
                    _currentPage > 1
                        ? () => _jumpToPage(_currentPage - 1)
                        : null,
                color: textColor,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 46,
                height: 28,
                child: TextField(
                  controller: _pageInputController,
                  focusNode: _pageInputFocusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: textColor.withValues(alpha: 0.35),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: textColor),
                    ),
                  ),
                  onSubmitted: (value) {
                    final p = int.tryParse(value);
                    if (p != null) _jumpToPage(p);
                    _pageInputController.text = '$_currentPage';
                    _pageInputFocusNode.unfocus();
                  },
                ),
              ),
              Text(
                ' / $_totalPages',
                style: TextStyle(color: textColor, fontSize: 13),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<double>(
                valueListenable: _zoomNotifier,
                builder:
                    (_, zoom, __) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out),
                          tooltip: 'Zoom out',
                          onPressed:
                              zoom > 1.05
                                  ? () =>
                                      _zoomNotifier.value = (zoom / 1.25).clamp(
                                        1.0,
                                        4.0,
                                      )
                                  : null,
                          color: textColor,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in),
                          tooltip: 'Zoom in',
                          onPressed:
                              zoom < 3.95
                                  ? () =>
                                      _zoomNotifier.value = (zoom * 1.25).clamp(
                                        1.0,
                                        4.0,
                                      )
                                  : null,
                          color: textColor,
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.colorize),
                tooltip: _tajweedEnabled ? 'Tajweed on' : 'Tajweed off',
                onPressed:
                    () => setState(() => _tajweedEnabled = !_tajweedEnabled),
                color:
                    _tajweedEnabled
                        ? const Color(0xFF1B7340)
                        : textColor.withValues(alpha: 0.45),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Tajweed legend',
                onPressed:
                    _tajweedEnabled
                        ? () => setState(() => _showLegend = !_showLegend)
                        : null,
                color:
                    _tajweedEnabled
                        ? (_showLegend ? const Color(0xFF1B7340) : textColor)
                        : textColor.withValues(alpha: 0.35),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.format_list_bulleted),
                tooltip: 'Go to Surah',
                onPressed: () => _showSurahListDialog(context),
                color: textColor,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSurahListDialog(BuildContext context) {
    if (_chaptersById.isEmpty) return;
    final chapters =
        _chaptersById.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Go to Surah'),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            content: SizedBox(
              width: 360,
              height: 440,
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (_, i) {
                  final ch = chapters[i];
                  return ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 28,
                      child: Text(
                        '${ch.id}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    title: Text(
                      ch.nameArabic,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: Text(
                      'p. ${ch.startPage}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onTap: () {
                      _jumpToPage(ch.startPage);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tajweed legend overlay
// ---------------------------------------------------------------------------

class _TajweedLegend extends StatelessWidget {
  final MushafDisplayMode displayMode;
  final VoidCallback onClose;

  const _TajweedLegend({required this.displayMode, required this.onClose});

  static const _rules = [
    (color: Color(0xFFB50000), arabic: 'قَلْقَلَة', label: 'Qalqala'),
    (
      color: Color(0xFFFF7B00),
      arabic: 'إِخْفَاء / إِقْلَاب',
      label: 'Ikhfāʾ / Iqlab',
    ),
    (color: Color(0xFFCE9E00), arabic: 'إِظْهَار', label: 'Iẓhār'),
    (color: Color(0xFF09B000), arabic: 'مَدّ', label: 'Madd'),
    (color: Color(0xFF3F48E6), arabic: 'غُنَّة', label: 'Ghunna'),
    (color: Color(0xFF2FADFF), arabic: 'إِدْغَام', label: 'Idghām'),
    (color: Color(0xFFF40000), arabic: 'مَدّ لَازِم', label: 'Madd lāzim'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = displayMode.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E2E22) : Colors.white;
    final borderColor = displayMode.borderColor;
    final textColor = displayMode.textColor;
    final labelColor = isDark ? Colors.white70 : Colors.black87;

    return Positioned(
      bottom: 52,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: borderColor.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                child: Row(
                  children: [
                    Text(
                      'Tajweed Legend',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: onClose,
                      color: labelColor.withValues(alpha: 0.6),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.75,
                color: borderColor.withValues(alpha: 0.3),
              ),
              // Base ink row
              _LegendRow(
                color: isDark ? Colors.white : Colors.black,
                arabic: 'نَص',
                label: 'Standard text',
                textColor: textColor,
                labelColor: labelColor,
              ),
              // Tajweed rule rows
              for (final rule in _rules)
                _LegendRow(
                  color: rule.color,
                  arabic: rule.arabic,
                  label: rule.label,
                  textColor: textColor,
                  labelColor: labelColor,
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String arabic;
  final String label;
  final Color textColor;
  final Color labelColor;

  const _LegendRow({
    required this.color,
    required this.arabic,
    required this.label,
    required this.textColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            arabic,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: labelColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePage extends StatefulWidget {
  final Widget child;
  final ValueNotifier<double> zoomNotifier;

  const _ZoomablePage({required this.child, required this.zoomNotifier});

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  late final TransformationController _controller;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _controller.addListener(_onTransformChanged);
    widget.zoomNotifier.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    widget.zoomNotifier.removeListener(_onZoomChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
    if ((scale - widget.zoomNotifier.value).abs() > 0.05) {
      widget.zoomNotifier.value = scale;
    }
  }

  void _onZoomChanged() {
    final scale = widget.zoomNotifier.value;
    if ((scale - _controller.value.getMaxScaleOnAxis()).abs() < 0.05) return;
    _controller.value =
        _controller.value.clone()
          ..setIdentity()
          ..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: _isZoomed,
      child: widget.child,
    );
  }
}
