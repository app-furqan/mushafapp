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
  Map<int, ChapterModel> _chapterStartsByPage = const {};

  int _currentPage = _initialPage;
  bool _showBottomBar = true;
  MushafDisplayMode _displayMode = MushafDisplayMode.light;

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
      final chapterMap = await _chapterService.getChapterStartsByPage();
      if (mounted) {
        setState(() => _chapterStartsByPage = chapterMap);
      }
    } catch (error) {
      debugPrint('Error loading chapter metadata: $error');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) {
                    _loadPageData(pageNumber);
                    _loadPageFont(pageNumber);
                  },
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: MushafPageWidget(
                    pageNumber: pageNumber,
                    pageData: _dataReady[pageNumber],
                    chapterStart: _chapterStartsByPage[pageNumber],
                    fontLoaded: _fontReady[pageNumber] ?? false,
                    displayMode: _displayMode,
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
            ],
          ),
        ),
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
