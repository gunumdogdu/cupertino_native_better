import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../utils/version_detector.dart';
import 'liquid_glass_container.dart';
import '../style/glass_effect.dart';

/// Position for the toast on screen.
enum CNToastPosition {
  /// Show at the top of the screen.
  top,

  /// Show at the center of the screen.
  center,

  /// Show at the bottom of the screen.
  bottom,
}

/// Duration presets for toasts.
enum CNToastDuration {
  /// Short duration (2 seconds).
  short,

  /// Medium duration (3.5 seconds).
  medium,

  /// Long duration (5 seconds).
  long,
}

/// Style presets for toasts.
enum CNToastStyle {
  /// Default toast style.
  normal,

  /// Success toast (green tint).
  success,

  /// Error toast (red tint).
  error,

  /// Warning toast (yellow/orange tint).
  warning,

  /// Info toast (blue tint).
  info,
}

/// A native toast notification widget.
///
/// Toasts are lightweight, non-intrusive notifications that appear briefly
/// and auto-dismiss. Unlike snackbars, they don't require user interaction
/// and are typically positioned in the center or top of the screen.
///
/// On iOS 26+, supports Liquid Glass effects for a native look.
///
/// ## Basic Usage
///
/// ```dart
/// CNToast.show(
///   context: context,
///   message: 'Settings saved',
/// );
/// ```
///
/// ## With Icon
///
/// ```dart
/// CNToast.show(
///   context: context,
///   message: 'Copied to clipboard',
///   icon: Icon(CupertinoIcons.doc_on_clipboard_fill),
/// );
/// ```
///
/// ## Success Toast
///
/// ```dart
/// CNToast.success(
///   context: context,
///   message: 'Profile updated successfully',
/// );
/// ```
///
/// ## Error Toast
///
/// ```dart
/// CNToast.error(
///   context: context,
///   message: 'Failed to save changes',
/// );
/// ```
///
/// ## Custom Position
///
/// ```dart
/// CNToast.show(
///   context: context,
///   message: 'New message',
///   position: CNToastPosition.top,
/// );
/// ```
class CNToast {
  CNToast._();

  static final List<_ToastEntry> _queue = [];
  static bool _isShowing = false;

  /// Shows a toast with the given message.
  static void show({
    required BuildContext context,
    required String message,
    Widget? icon,
    CNToastPosition position = CNToastPosition.center,
    CNToastDuration duration = CNToastDuration.medium,
    CNToastStyle style = CNToastStyle.normal,
    Color? backgroundColor,
    Color? textColor,
    bool useGlassEffect = true,
  }) {
    _queue.add(_ToastEntry(
      context: context,
      message: message,
      icon: icon,
      position: position,
      duration: duration,
      style: style,
      backgroundColor: backgroundColor,
      textColor: textColor,
      useGlassEffect: useGlassEffect,
    ));

    if (!_isShowing) {
      _showNext();
    }
  }

  /// Shows a success toast.
  static void success({
    required BuildContext context,
    required String message,
    CNToastPosition position = CNToastPosition.center,
    CNToastDuration duration = CNToastDuration.medium,
    bool useGlassEffect = true,
  }) {
    show(
      context: context,
      message: message,
      icon: const Icon(
        CupertinoIcons.checkmark_circle_fill,
        color: CupertinoColors.systemGreen,
        size: 24,
      ),
      position: position,
      duration: duration,
      style: CNToastStyle.success,
      useGlassEffect: useGlassEffect,
    );
  }

  /// Shows an error toast.
  static void error({
    required BuildContext context,
    required String message,
    CNToastPosition position = CNToastPosition.center,
    CNToastDuration duration = CNToastDuration.medium,
    bool useGlassEffect = true,
  }) {
    show(
      context: context,
      message: message,
      icon: const Icon(
        CupertinoIcons.xmark_circle_fill,
        color: CupertinoColors.systemRed,
        size: 24,
      ),
      position: position,
      duration: duration,
      style: CNToastStyle.error,
      useGlassEffect: useGlassEffect,
    );
  }

  /// Shows a warning toast.
  static void warning({
    required BuildContext context,
    required String message,
    CNToastPosition position = CNToastPosition.center,
    CNToastDuration duration = CNToastDuration.medium,
    bool useGlassEffect = true,
  }) {
    show(
      context: context,
      message: message,
      icon: const Icon(
        CupertinoIcons.exclamationmark_triangle_fill,
        color: CupertinoColors.systemOrange,
        size: 24,
      ),
      position: position,
      duration: duration,
      style: CNToastStyle.warning,
      useGlassEffect: useGlassEffect,
    );
  }

  /// Shows an info toast.
  static void info({
    required BuildContext context,
    required String message,
    CNToastPosition position = CNToastPosition.center,
    CNToastDuration duration = CNToastDuration.medium,
    bool useGlassEffect = true,
  }) {
    show(
      context: context,
      message: message,
      icon: const Icon(
        CupertinoIcons.info_circle_fill,
        color: CupertinoColors.systemBlue,
        size: 24,
      ),
      position: position,
      duration: duration,
      style: CNToastStyle.info,
      useGlassEffect: useGlassEffect,
    );
  }

  /// Shows a loading toast that must be dismissed manually.
  static CNLoadingToastHandle loading({
    required BuildContext context,
    String message = 'Loading...',
    CNToastPosition position = CNToastPosition.center,
    bool useGlassEffect = true,
  }) {
    final handle = CNLoadingToastHandle._();

    final overlay = Overlay.of(context);
    final shouldUseGlass = PlatformVersion.supportsLiquidGlass && useGlassEffect;

    handle._overlayEntry = OverlayEntry(
      builder: (context) {
        return _ToastOverlay(
          message: message,
          icon: const CupertinoActivityIndicator(),
          position: position,
          style: CNToastStyle.normal,
          backgroundColor: null,
          textColor: null,
          useGlassEffect: shouldUseGlass,
          onDismiss: () {},
          isLoading: true,
        );
      },
    );

    overlay.insert(handle._overlayEntry!);
    return handle;
  }

  /// Clears all pending toasts.
  static void clear() {
    _queue.clear();
  }

  static void _showNext() {
    if (_queue.isEmpty) {
      _isShowing = false;
      return;
    }

    _isShowing = true;
    final entry = _queue.removeAt(0);

    final overlay = Overlay.of(entry.context);
    final shouldUseGlass =
        PlatformVersion.supportsLiquidGlass && entry.useGlassEffect;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) {
        return _ToastOverlay(
          message: entry.message,
          icon: entry.icon,
          position: entry.position,
          style: entry.style,
          backgroundColor: entry.backgroundColor,
          textColor: entry.textColor,
          useGlassEffect: shouldUseGlass,
          onDismiss: () {
            overlayEntry.remove();
            _showNext();
          },
          isLoading: false,
        );
      },
    );

    overlay.insert(overlayEntry);

    // Auto dismiss
    final durationMs = _getDurationMs(entry.duration);
    Timer(Duration(milliseconds: durationMs), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
      _showNext();
    });
  }

  static int _getDurationMs(CNToastDuration duration) {
    switch (duration) {
      case CNToastDuration.short:
        return 2000;
      case CNToastDuration.medium:
        return 3500;
      case CNToastDuration.long:
        return 5000;
    }
  }
}

class _ToastEntry {
  _ToastEntry({
    required this.context,
    required this.message,
    this.icon,
    required this.position,
    required this.duration,
    required this.style,
    this.backgroundColor,
    this.textColor,
    required this.useGlassEffect,
  });

  final BuildContext context;
  final String message;
  final Widget? icon;
  final CNToastPosition position;
  final CNToastDuration duration;
  final CNToastStyle style;
  final Color? backgroundColor;
  final Color? textColor;
  final bool useGlassEffect;
}

/// Handle for dismissing a loading toast.
class CNLoadingToastHandle {
  CNLoadingToastHandle._();

  OverlayEntry? _overlayEntry;

  /// Dismisses the loading toast.
  void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    this.icon,
    required this.position,
    required this.style,
    this.backgroundColor,
    this.textColor,
    required this.useGlassEffect,
    required this.onDismiss,
    required this.isLoading,
  });

  final String message;
  final Widget? icon;
  final CNToastPosition position;
  final CNToastStyle style;
  final Color? backgroundColor;
  final Color? textColor;
  final bool useGlassEffect;
  final VoidCallback onDismiss;
  final bool isLoading;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(BuildContext context) {
    if (widget.backgroundColor != null) return widget.backgroundColor!;

    final brightness = CupertinoTheme.of(context).brightness ?? Brightness.light;
    final isDark = brightness == Brightness.dark;

    switch (widget.style) {
      case CNToastStyle.normal:
        return isDark
            ? const Color(0xE6333333)
            : const Color(0xE6FFFFFF);
      case CNToastStyle.success:
        return isDark
            ? const Color(0xE6264D26)
            : const Color(0xE6E8F5E9);
      case CNToastStyle.error:
        return isDark
            ? const Color(0xE64D2626)
            : const Color(0xE6FFEBEE);
      case CNToastStyle.warning:
        return isDark
            ? const Color(0xE64D3D26)
            : const Color(0xE6FFF3E0);
      case CNToastStyle.info:
        return isDark
            ? const Color(0xE626444D)
            : const Color(0xE6E3F2FD);
    }
  }

  Color _getTextColor(BuildContext context) {
    if (widget.textColor != null) return widget.textColor!;

    return CupertinoColors.label.resolveFrom(context);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor(context);
    final textColor = _getTextColor(context);

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            widget.icon!,
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              widget.message,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    if (widget.useGlassEffect) {
      content = LiquidGlassContainer(
        config: LiquidGlassConfig(
          effect: CNGlassEffect.regular,
          shape: CNGlassEffectShape.capsule,
          tint: backgroundColor,
        ),
        child: content,
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: content,
      );
    }

    // Position the toast
    double? top;
    double? bottom;
    Alignment alignment;

    final topPadding = MediaQuery.of(context).viewPadding.top;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    switch (widget.position) {
      case CNToastPosition.top:
        top = topPadding + 60;
        alignment = Alignment.topCenter;
        break;
      case CNToastPosition.center:
        alignment = Alignment.center;
        break;
      case CNToastPosition.bottom:
        bottom = bottomPadding + 100;
        alignment = Alignment.bottomCenter;
        break;
    }

    return Positioned.fill(
      top: top,
      bottom: bottom,
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
