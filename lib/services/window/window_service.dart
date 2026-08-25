import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Centralized window and fullscreen state manager for desktop and mobile.
///
/// Implements the tri-state machine:
/// - Maximized window -> Unmaximize -> Hide title bar -> Maximize (Fullscreen)
/// - Normal window -> Hide title bar -> Maximize (Fullscreen)
/// - Fullscreen window -> Unmaximize -> Show title bar (Normal)
class WindowService with WindowListener {
  static final WindowService instance = WindowService._internal();
  WindowService._internal();

  final ValueNotifier<bool> isFullscreenNotifier = ValueNotifier<bool>(false);
  bool _isTransitioning = false;
  bool _isTitleBarHidden = false;

  bool get isFullscreen => isFullscreenNotifier.value;
  bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> initialize() async {
    if (!isDesktop) return;
    try {
      windowManager.addListener(this);
      final isMax = await windowManager.isMaximized();
      final isFs = await windowManager.isFullScreen();
      isFullscreenNotifier.value = isFs || (_isTitleBarHidden && isMax);
    } catch (e) {
      debugPrint('[WindowService] initialize error: $e');
    }
  }

  void dispose() {
    if (isDesktop) {
      windowManager.removeListener(this);
    }
  }

  /// Executes the state machine toggle.
  Future<void> toggleFullscreen() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      if (!isDesktop) {
        // Mobile fallback
        final next = !isFullscreenNotifier.value;
        isFullscreenNotifier.value = next;
        if (next) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
        return;
      }

      final isCurrentlyMaximized = await windowManager.isMaximized();

      if (isFullscreenNotifier.value) {
        // ── State 3: Fullscreen -> Exit to Normal ──
        // 1. Unmaximize
        await windowManager.unmaximize();
        // 2. Restore / show title bar
        await windowManager.setTitleBarStyle(TitleBarStyle.normal);
        _isTitleBarHidden = false;
        isFullscreenNotifier.value = false;
      } else if (isCurrentlyMaximized) {
        // ── State 1: Maximized (with title bar) -> Fullscreen ──
        // 1. Unmaximize first (crucial Win32 fix to prevent style mutation error)
        await windowManager.unmaximize();
        // 2. Hide title bar
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
        _isTitleBarHidden = true;
        // 3. Maximize again
        await windowManager.maximize();
        isFullscreenNotifier.value = true;
      } else {
        // ── State 2: Normal / Unmaximized -> Fullscreen ──
        // 1. Hide title bar
        await windowManager.setTitleBarStyle(
          TitleBarStyle.hidden,
          windowButtonVisibility: false,
        );
        _isTitleBarHidden = true;
        // 2. Maximize
        await windowManager.maximize();
        isFullscreenNotifier.value = true;
      }
    } catch (e) {
      debugPrint('[WindowService] toggleFullscreen error: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  /// Forces exit from fullscreen (e.g. when leaving player screen).
  Future<void> exitFullscreen() async {
    if (!isFullscreenNotifier.value && !_isTitleBarHidden) return;
    if (!isDesktop) {
      isFullscreenNotifier.value = false;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }
    _isTransitioning = true;
    try {
      await windowManager.unmaximize();
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      _isTitleBarHidden = false;
      isFullscreenNotifier.value = false;
    } catch (e) {
      debugPrint('[WindowService] exitFullscreen error: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  // ── WindowListener Callbacks (Synchronize OS events) ──

  @override
  void onWindowRestore() {
    if (_isTransitioning) return;
    if (_isTitleBarHidden) {
      // User dragged or restored window via OS gesture -> restore title bar
      windowManager.setTitleBarStyle(TitleBarStyle.normal);
      _isTitleBarHidden = false;
    }
    isFullscreenNotifier.value = false;
  }

  @override
  void onWindowUnmaximize() {
    if (_isTransitioning) return;
    if (_isTitleBarHidden) {
      windowManager.setTitleBarStyle(TitleBarStyle.normal);
      _isTitleBarHidden = false;
    }
    isFullscreenNotifier.value = false;
  }

  @override
  void onWindowMaximize() {
    if (_isTransitioning) return;
    isFullscreenNotifier.value = _isTitleBarHidden;
  }

  @override
  void onWindowLeaveFullScreen() {
    if (_isTransitioning) return;
    _isTitleBarHidden = false;
    isFullscreenNotifier.value = false;
  }
}
