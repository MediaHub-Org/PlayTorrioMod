import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../services/books/book_progress_service.dart';
import '../../services/books/books_service.dart';
import '../../services/books/reader_settings.dart';
import '../../services/window/window_service.dart';
import '../../services/discord/discord_rpc_service.dart';

/// Reads an already-downloaded PDF file via `pdfrx`.
///
/// Ported from upstream's `pdf_reader_page.dart` (2026-09-02): PDF rendering
/// is fully standalone (`pdfrx` decodes the file directly, no shared parsing
/// with [BookReaderPage]'s EPUB path), so it was addable without touching
/// the working EPUB reader. See `ROADMAP.md` for why MOBI/FB2 aren't here
/// too -- both need a parser service this fork doesn't have, PDF didn't.
class PdfReaderPage extends StatefulWidget {
  final File file;
  final BookResult book;
  final int initialPage;

  const PdfReaderPage({
    super.key,
    required this.file,
    required this.book,
    this.initialPage = 1,
  });

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  late final PdfViewerController _pdfController;
  int _currentPage = 1;
  int _pageCount = 1;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage < 1 ? 1 : widget.initialPage;
    _pdfController = PdfViewerController();
    DiscordRpcService.instance.setReadingBook(
      title: widget.book.title,
      author: widget.book.author,
      page: _currentPage,
    );
    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    DiscordRpcService.instance.clearToIdle();
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
    }
  }

  /// [BookProgress] has no page-count/percent fields, only "chapter" -- reuse
  /// that slot to hold the current page number, matching how the reader-open
  /// helper already threads `initialChapter` through as a page number for
  /// PDFs. [scrollFraction] is a real fit for page/total though, so it
  /// carries the percent EPUB's own scroll-position field would.
  void _saveProgress(int page, int total) {
    if (total <= 0) return;
    BookProgressService.instance.saveProgress(
      book: widget.book,
      chapter: page - 1,
      scrollFraction: (page / total).clamp(0.0, 1.0),
      filePath: widget.file.path,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      if (_currentPage < _pageCount) {
        _pdfController.goToPage(pageNumber: _currentPage + 1);
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      if (_currentPage > 1) {
        _pdfController.goToPage(pageNumber: _currentPage - 1);
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      WindowService.instance.toggleFullscreen();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderSettingsData>(
      valueListenable: ReaderSettings.settingsNotifier,
      builder: (context, settings, _) {
        return Focus(
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Scaffold(
            backgroundColor: const Color(0xFF101014),
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    child: PdfViewer.file(
                      widget.file.path,
                      controller: _pdfController,
                      initialPageNumber: _currentPage,
                      params: PdfViewerParams(
                        backgroundColor: const Color(0xFF141419),
                        onPageChanged: (pageNumber) {
                          if (pageNumber != null) {
                            setState(() => _currentPage = pageNumber);
                            _saveProgress(pageNumber, _pageCount);
                          }
                        },
                        onViewerReady: (document, controller) {
                          setState(() {
                            _pageCount = document.pages.length;
                          });
                          _saveProgress(_currentPage, document.pages.length);
                        },
                      ),
                    ),
                  ),
                ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  top: _showControls ? 0 : -80,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1E26).withValues(alpha: 0.94),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Back to Library',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.book.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.book.author,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Zoom In',
                          onPressed: () => _pdfController.zoomUp(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.zoom_out_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Zoom Out',
                          onPressed: () => _pdfController.zoomDown(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: 'Fullscreen (F)',
                          onPressed: () =>
                              WindowService.instance.toggleFullscreen(),
                        ),
                      ],
                    ),
                  ),
                ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  bottom: _showControls ? 0 : -90,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1E26).withValues(alpha: 0.94),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          tooltip: 'Previous Page',
                          onPressed: _currentPage > 1
                              ? () => _pdfController.goToPage(
                                  pageNumber: _currentPage - 1,
                                )
                              : null,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Page $_currentPage of $_pageCount',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    '${((_currentPage / (_pageCount > 0 ? _pageCount : 1)) * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),
                                  activeTrackColor: const Color(0xFF7C3AED),
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: const Color(0xFF7C3AED),
                                ),
                                child: Slider(
                                  value: _currentPage.toDouble().clamp(
                                    1,
                                    _pageCount > 1
                                        ? _pageCount.toDouble()
                                        : 1.0,
                                  ),
                                  min: 1,
                                  max: _pageCount > 1
                                      ? _pageCount.toDouble()
                                      : 1.0,
                                  divisions: _pageCount > 1
                                      ? _pageCount - 1
                                      : 1,
                                  onChanged: (val) {
                                    final target = val.round();
                                    _pdfController.goToPage(pageNumber: target);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          tooltip: 'Next Page',
                          onPressed: _currentPage < _pageCount
                              ? () => _pdfController.goToPage(
                                  pageNumber: _currentPage + 1,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
