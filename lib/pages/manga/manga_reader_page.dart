import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/manga/manga.dart';
import '../../models/manga/manga_chapter.dart';
import '../../services/manga/manga_service.dart';
import '../../widgets/common/custom_scroll_track.dart';

class MangaReaderPage extends StatefulWidget {
  final Manga manga;
  final List<MangaChapter> chapters;
  final int currentChapterIndex;
  final int resumePageIndex;

  const MangaReaderPage({
    super.key,
    required this.manga,
    required this.chapters,
    required this.currentChapterIndex,
    this.resumePageIndex = 0,
  });

  @override
  State<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends State<MangaReaderPage> {
  final MangaService _mangaService = MangaService();
  final FocusNode _focusNode = FocusNode();

  late int _currentChapterIndex;
  late int _currentPageIndex;

  List<String> _pageUrls = [];
  bool _isLoading = true;
  bool _showOverlay = true;
  bool _isHorizontalMode = true; // Default to Horizontal Page Flip

  PageController? _pageController;
  final ScrollController _verticalScrollController = ScrollController();
  final TransformationController _transformationController = TransformationController();

  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.currentChapterIndex;
    _currentPageIndex = widget.resumePageIndex;
    _pageController = PageController(initialPage: _currentPageIndex);

    _verticalScrollController.addListener(_onVerticalScroll);
    _loadChapter();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController?.dispose();
    _verticalScrollController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Matrix4 _buildCenterScaleMatrix(double scale, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    return Matrix4.identity()
      ..translate(cx, cy)
      ..scale(scale)
      ..translate(-cx, -cy);
  }

  void _zoomIn() {
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _currentZoom = (_currentZoom + 0.25).clamp(0.25, 5.0);
      if ((_currentZoom - 1.0).abs() < 0.05) {
        _currentZoom = 1.0;
        _transformationController.value = Matrix4.identity();
      } else {
        _transformationController.value = _buildCenterScaleMatrix(_currentZoom, size);
      }
    });
  }

  void _zoomOut() {
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _currentZoom = (_currentZoom - 0.25).clamp(0.25, 5.0);
      if ((_currentZoom - 1.0).abs() < 0.05) {
        _currentZoom = 1.0;
        _transformationController.value = Matrix4.identity();
      } else {
        _transformationController.value = _buildCenterScaleMatrix(_currentZoom, size);
      }
    });
  }

  void _resetZoom() {
    setState(() {
      _currentZoom = 1.0;
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _loadChapter() async {
    _resetZoom();
    setState(() => _isLoading = true);

    final chapter = widget.chapters[_currentChapterIndex];
    final urls = await _mangaService.getChapterImages(chapter.id);

    if (mounted) {
      setState(() {
        _pageUrls = urls;
        _isLoading = false;

        if (urls.isNotEmpty && _currentPageIndex >= urls.length) {
          _currentPageIndex = 0;
        }
      });

      for (final url in urls) {
        precacheImage(CachedNetworkImageProvider(url), context);
      }

      if (_pageController?.hasClients ?? false) {
        _pageController!.jumpToPage(_currentPageIndex);
      } else {
        _pageController = PageController(initialPage: _currentPageIndex);
      }

      _saveProgress();
    }
  }

  void _saveProgress() {
    _mangaService.saveProgress(
      widget.manga,
      _currentChapterIndex,
      _currentPageIndex,
      widget.chapters,
    );
  }

  void _onVerticalScroll() {
    if (_isHorizontalMode || _pageUrls.isEmpty) return;

    final offset = _verticalScrollController.offset;
    final estimatedIndex = (offset / 1000).floor().clamp(0, _pageUrls.length - 1);

    if (estimatedIndex != _currentPageIndex) {
      setState(() => _currentPageIndex = estimatedIndex);
      _saveProgress();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPageIndex = index);
    _saveProgress();
  }

  void _toggleMode() {
    _resetZoom();
    setState(() {
      _isHorizontalMode = !_isHorizontalMode;
      if (_isHorizontalMode) {
        _pageController = PageController(initialPage: _currentPageIndex);
      }
    });
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  void _nextChapter() {
    if (_currentChapterIndex > 0) {
      setState(() {
        _currentChapterIndex--;
        _currentPageIndex = 0;
      });
      _loadChapter();
    }
  }

  void _prevChapter() {
    if (_currentChapterIndex < widget.chapters.length - 1) {
      setState(() {
        _currentChapterIndex++;
        _currentPageIndex = 0;
      });
      _loadChapter();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return;
    }

    if (_isHorizontalMode) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.space) {
        if (_currentPageIndex < _pageUrls.length - 1) {
          _pageController?.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        } else {
          _nextChapter();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_currentPageIndex > 0) {
          _pageController?.previousPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        } else {
          _prevChapter();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterTitle = widget.chapters[_currentChapterIndex].name.isNotEmpty
        ? widget.chapters[_currentChapterIndex].name
        : 'Chapter ${widget.chapters[_currentChapterIndex].number}';

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Main Interactive Zoom & Pan Reader Container (Works in both Horizontal and Vertical modes)
            GestureDetector(
              onTap: _toggleOverlay,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
                    )
                  : _pageUrls.isEmpty
                      ? const Center(
                          child: Text(
                            'No pages found for this chapter.',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        )
                      : InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 0.25,
                          maxScale: 5.0,
                          panEnabled: true, // Enables click & drag panning in both Horizontal & Vertical modes when zoomed!
                          scaleEnabled: true,
                          clipBehavior: Clip.none,
                          onInteractionUpdate: (_) {
                            final s = _transformationController.value.getMaxScaleOnAxis();
                            if ((s - _currentZoom).abs() > 0.05) {
                              setState(() => _currentZoom = s);
                            }
                          },
                          child: _isHorizontalMode
                              ? _buildHorizontalPageView()
                              : _buildVerticalWebtoonReader(),
                        ),
            ),

            // Custom Vertical Scroller for Webtoon Mode
            if (!_isHorizontalMode && !_isLoading && _pageUrls.isNotEmpty)
              Positioned(
                right: 20,
                top: 100,
                bottom: 100,
                child: Center(
                  child: CustomScrollTrack(
                    controller: _verticalScrollController,
                    axis: Axis.vertical,
                    length: 320.0,
                  ),
                ),
              ),

            // Top Header Overlay
            if (_showOverlay)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(chapterTitle),
              ),

            // Bottom Navigation & Controls Overlay
            if (_showOverlay)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(),
              ),
          ],
        ),
      ),
    );
  }

  // 1. Horizontal Reading Mode with PageView (Supports Center Zoom & Click-and-Drag Pan)
  Widget _buildHorizontalPageView() {
    return PageView.builder(
      controller: _pageController,
      physics: _currentZoom > 1.05
          ? const NeverScrollableScrollPhysics() // When zoomed in, allow mouse drag to pan around the page without triggering page swipe
          : const BouncingScrollPhysics(),
      itemCount: _pageUrls.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: CachedNetworkImage(
            imageUrl: _pageUrls[index],
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
            ),
          ),
        );
      },
    );
  }

  // 2. Vertical Webtoon Continuous Scroll Mode
  Widget _buildVerticalWebtoonReader() {
    return ListView.builder(
      controller: _verticalScrollController,
      physics: _currentZoom > 1.05
          ? const NeverScrollableScrollPhysics() // When zoomed in, allow mouse drag to pan around the page
          : const BouncingScrollPhysics(),
      itemCount: _pageUrls.length + 1,
      itemBuilder: (context, index) {
        if (index == _pageUrls.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _currentChapterIndex > 0 ? _nextChapter : null,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                label: const Text(
                  'Next Chapter',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFF),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          );
        }

        return Container(
          color: Colors.black,
          margin: const EdgeInsets.only(bottom: 4),
          child: CachedNetworkImage(
            imageUrl: _pageUrls[index],
            fit: BoxFit.fitWidth,
            placeholder: (context, url) => const SizedBox(
              height: 350,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white24),
              ),
            ),
            errorWidget: (context, url, error) => const SizedBox(
              height: 200,
              child: Center(
                child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
              ),
            ),
          ),
        );
      },
    );
  }

  // Top Glass Bar
  Widget _buildTopBar(String title) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: const EdgeInsets.only(top: 40, bottom: 12, left: 16, right: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.manga.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isHorizontalMode ? 'Switch to Vertical Webtoon Mode' : 'Switch to Horizontal Flip Mode',
                icon: Icon(
                  _isHorizontalMode ? Icons.view_day_rounded : Icons.view_carousel_rounded,
                  color: const Color(0xFFA78BFA),
                ),
                onPressed: _toggleMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom Glass Control Bar with Page Counter, Navigation & Button Zoom Controls
  Widget _buildBottomBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isHorizontalMode && _pageUrls.isNotEmpty)
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF7C5CFF),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: const Color(0xFF7C5CFF),
                    overlayColor: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _currentPageIndex.toDouble().clamp(0.0, (_pageUrls.length - 1).toDouble()),
                    min: 0.0,
                    max: (_pageUrls.length - 1).toDouble(),
                    divisions: _pageUrls.length > 1 ? _pageUrls.length - 1 : 1,
                    onChanged: (val) {
                      final targetPage = val.round();
                      _pageController?.jumpToPage(targetPage);
                      _onPageChanged(targetPage);
                    },
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Prev Chapter Button
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                    onPressed: _currentChapterIndex < widget.chapters.length - 1 ? _prevChapter : null,
                    tooltip: 'Previous Chapter',
                  ),

                  // Interactive Zoom Control Cluster (Button Zoom + Center Alignment)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 20),
                          onPressed: _currentZoom > 0.26 ? _zoomOut : null,
                          tooltip: 'Zoom Out (-)',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                        ),
                        InkWell(
                          onTap: _resetZoom,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              '${(_currentZoom * 100).round()}%',
                              style: TextStyle(
                                color: (_currentZoom - 1.0).abs() > 0.03 ? const Color(0xFFA78BFA) : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                          onPressed: _currentZoom < 4.9 ? _zoomIn : null,
                          tooltip: 'Zoom In (+)',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Page Counter Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Page ${_currentPageIndex + 1} / ${_pageUrls.isNotEmpty ? _pageUrls.length : "?"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Next Chapter Button
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                    onPressed: _currentChapterIndex > 0 ? _nextChapter : null,
                    tooltip: 'Next Chapter',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
