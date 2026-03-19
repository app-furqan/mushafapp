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
  MushafDisplayMode _displayMode = MushafDisplayMode.light;
  bool _tajweedEnabled = true;
  final _zoomNotifier = ValueNotifier<double>(1.0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage - 1);
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
        onTap: () => setState(() => _showBottomBar = !_showBottomBar),
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
              GestureDetector(
                onTap: () => _showPageJumpDialog(context),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
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

  void _showPageJumpDialog(BuildContext context) {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Go to page'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '1 – 604',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final p = int.tryParse(controller.text);
                  if (p != null) _jumpToPage(p);
                  Navigator.pop(ctx);
                },
                child: const Text('Go'),
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
