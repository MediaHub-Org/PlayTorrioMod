import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/iptv/hardcoded_channels.dart';

class IptvHeroCarousel extends StatefulWidget {
  final List<HardcodedChannel> channels;
  final Function(HardcodedChannel) onWatchNow;
  final Function(HardcodedChannel) onSourcesTap;

  const IptvHeroCarousel({
    super.key,
    required this.channels,
    required this.onWatchNow,
    required this.onSourcesTap,
  });

  @override
  State<IptvHeroCarousel> createState() => _IptvHeroCarouselState();
}

class _IptvHeroCarouselState extends State<IptvHeroCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || widget.channels.length <= 1 || _isHovering) return;
      final next = (_currentIndex + 1) % widget.channels.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _isDesktop() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = (screenHeight * 0.52).clamp(380.0, 560.0);
    final isDesktop = _isDesktop();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: RepaintBoundary(
        child: SizedBox(
          height: heroHeight,
          width: screenWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Page View
              PageView.builder(
                controller: _pageController,
                itemCount: widget.channels.length,
                onPageChanged: (idx) {
                  setState(() => _currentIndex = idx);
                },
                itemBuilder: (context, index) {
                  final ch = widget.channels[index];
                  return _IptvHeroSlide(
                    channel: ch,
                    onWatchNow: () => widget.onWatchNow(ch),
                    onSourcesTap: () => widget.onSourcesTap(ch),
                  );
                },
              ),

              // Desktop Previous / Next Hover Arrows
              if (isDesktop && _isHovering && widget.channels.length > 1) ...[
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _HeroArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () {
                        final prev = (_currentIndex - 1 + widget.channels.length) %
                            widget.channels.length;
                        _pageController.animateToPage(
                          prev,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _HeroArrowButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () {
                        final next = (_currentIndex + 1) % widget.channels.length;
                        _pageController.animateToPage(
                          next,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Indicator Dots
              if (widget.channels.length > 1)
                Positioned(
                  bottom: 18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        widget.channels.length,
                        (index) => GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentIndex == index ? 26 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _currentIndex == index
                                  ? const Color(0xFF7C5CFF)
                                  : Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: _currentIndex == index
                                  ? [
                                      const BoxShadow(
                                        color: Color(0xFF7C5CFF),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IptvHeroSlide extends StatelessWidget {
  final HardcodedChannel channel;
  final VoidCallback onWatchNow;
  final VoidCallback onSourcesTap;

  const _IptvHeroSlide({
    required this.channel,
    required this.onWatchNow,
    required this.onSourcesTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        channel.gradient.isNotEmpty ? channel.gradient.first : const Color(0xFF7C5CFF);
    final secondaryColor =
        channel.gradient.length > 1 ? channel.gradient.last : const Color(0xFF00D2EF);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient & Ambient Glow Mesh (Fallback base)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.45),
                secondaryColor.withValues(alpha: 0.20),
                const Color(0xFF080A0F),
              ],
              stops: const [0.0, 0.4, 0.9],
            ),
          ),
        ),

        // Backdrop photo if available
        if (channel.backdropUrl != null && channel.backdropUrl!.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: channel.backdropUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              memCacheWidth: 1920,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // Dark top/bottom gradient overlay for readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF080A0F).withValues(alpha: 0.25),
                  const Color(0xFF080A0F).withValues(alpha: 0.60),
                  const Color(0xFF080A0F).withValues(alpha: 0.92),
                  const Color(0xFF080A0F),
                ],
                stops: const [0.0, 0.42, 0.82, 1.0],
              ),
            ),
          ),
        ),

        // Left-to-right gradient overlay to make logo and buttons pop
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF080A0F).withValues(alpha: 0.88),
                  const Color(0xFF080A0F).withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // Content
        Positioned(
          left: 32,
          right: 32,
          bottom: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // LIVE Pulse & Category row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sensors_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'LIVE BROADCAST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      channel.category,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Channel Logo (instead of plain text name)
              if (channel.iconUrl != null && channel.iconUrl!.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 280,
                    maxHeight: 65,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: channel.iconUrl!,
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.contain,
                    memCacheWidth: 512,
                    errorWidget: (_, __, ___) => Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),

              const SizedBox(height: 12),

              // Description / stream info
              Text(
                'Instant live multi-source streaming with real-time stream resolution & high-framerate playback.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  // Primary Watch Live Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onWatchNow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C5CFF), Color(0xFF9D4EDD)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Watch Live',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Sources / Stream Selector Pill
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onSourcesTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded, color: Colors.white70, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Stream Feeds',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HeroArrowButton> createState() => _HeroArrowButtonState();
}

class _HeroArrowButtonState extends State<_HeroArrowButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isHovering
                ? const Color(0xFF7C5CFF)
                : Colors.black.withValues(alpha: 0.55),
            border: Border.all(
              color: _isHovering
                  ? const Color(0xFF7C5CFF)
                  : Colors.white.withValues(alpha: 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovering
                    ? const Color(0xFF7C5CFF).withValues(alpha: 0.45)
                    : Colors.black45,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
