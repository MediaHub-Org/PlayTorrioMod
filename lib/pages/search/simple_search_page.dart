import 'dart:async';

import 'package:flutter/material.dart';

/// A full-screen search page for a section with its own search backend
/// (not the addon catalog [SearchPage]/[AddonManager.searchAll] covers) --
/// Podcasts (iTunes API), Books (libgen.li) and Audiobooks (AudiobookBay)
/// each need this rather than the shared one.
///
/// Same shape as [SearchPage] itself (back button + search field in the
/// header, full-screen results below) so every section's search reads the
/// same way, even though what each one searches is unrelated.
class SimpleSearchPage<T> extends StatefulWidget {
  /// Shown as the field's placeholder, e.g. "Search podcasts...".
  final String hintText;

  final Future<List<T>> Function(String query) onSearch;

  /// Builds one result. Used inside a [GridView] if [gridDelegate] is set,
  /// otherwise inside a [ListView].
  final Widget Function(BuildContext context, T item) itemBuilder;

  final SliverGridDelegate? gridDelegate;

  /// Icon shown before any query has been entered.
  final IconData emptyIcon;

  /// Message shown before any query has been entered.
  final String emptyMessage;

  const SimpleSearchPage({
    super.key,
    required this.hintText,
    required this.onSearch,
    required this.itemBuilder,
    this.gridDelegate,
    this.emptyIcon = Icons.search_rounded,
    this.emptyMessage = 'Search to get started',
  });

  @override
  State<SimpleSearchPage<T>> createState() => _SimpleSearchPageState<T>();
}

class _SimpleSearchPageState<T> extends State<SimpleSearchPage<T>> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _isLoading = false;
  bool _hasSearched = false;
  List<T> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    setState(() {}); // refresh the clear button's visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _hasSearched = false;
        _results = const [];
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    final results = await widget.onSearch(trimmed);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: _onChanged,
                        onSubmitted: _search,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: Colors.white38,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  color: Colors.white60,
                                  splashRadius: 18,
                                  onPressed: () {
                                    _controller.clear();
                                    _onChanged('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
      );
    }
    if (!_hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.emptyIcon, color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              Text(
                widget.emptyMessage,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No results found.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    if (widget.gridDelegate != null) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: widget.gridDelegate!,
        itemCount: _results.length,
        itemBuilder: (context, index) =>
            widget.itemBuilder(context, _results[index]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          widget.itemBuilder(context, _results[index]),
    );
  }
}
