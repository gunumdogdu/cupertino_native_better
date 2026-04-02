import 'package:flutter/widgets.dart';

/// Guards platform-view creation during app startup / hot-restart.
///
/// On iOS, `FlutterPlatformViewsController` may retain residual view
/// registrations from a previous Dart isolate immediately after a hot
/// restart. If the new isolate's widgets request platform-view creation
/// before the engine has fully purged these stale registrations, it
/// rejects them with `PlatformException(recreating_view, ...)`.
///
/// This guard delays platform-view widgets by a short fixed duration
/// (500 ms) after the first widget requests readiness, giving the
/// engine ample time to run its internal cleanup.  The delay fires
/// only once per app lifetime — subsequent checks are instantaneous.
///
/// Usage inside component `build` methods:
/// ```dart
/// if (!PlatformViewGuard.isReady) {
///   PlatformViewGuard.ensureScheduled();
///   return _fallbackWidget();
/// }
/// return UiKitView(...);
/// ```
class PlatformViewGuard {
  PlatformViewGuard._();

  static bool _ready = false;
  static bool _scheduled = false;

  /// Whether it is safe to create platform views.
  static bool get isReady => _ready;

  /// Notifier that fires once when readiness flips to `true`.
  static final ValueNotifier<bool> readyNotifier =
      ValueNotifier<bool>(false);

  /// Schedules the readiness flip if it hasn't been scheduled yet.
  ///
  /// A 500 ms timer is used instead of post-frame callbacks because
  /// the engine's platform-view cleanup runs asynchronously and may
  /// not complete within one or two vsync intervals.  500 ms is long
  /// enough for the engine to finish while remaining imperceptible
  /// to the user (the Flutter fallback widgets are shown meanwhile).
  static void ensureScheduled() {
    if (_ready || _scheduled) return;
    _scheduled = true;

    Future<void>.delayed(
      const Duration(milliseconds: 500),
      () {
        if (_ready) return;
        _ready = true;
        readyNotifier.value = true;
      },
    );
  }
}
