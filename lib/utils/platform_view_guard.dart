import 'package:flutter/foundation.dart';

/// Guards platform-view creation during app startup / hot-restart.
///
/// On iOS, `FlutterPlatformViewsController` may retain residual view
/// registrations from a previous Dart isolate immediately after a **hot
/// restart**. If the new isolate's widgets request platform-view
/// creation before the engine has purged the stale registrations, it
/// rejects them with `PlatformException(recreating_view, ...)`.
///
/// This guard delays platform-view widgets by 500 ms in **debug mode
/// only** — release builds (cold start, no isolate-recycling) flip
/// readiness to `true` immediately so the native iOS 26 widgets render
/// from the very first frame and no Flutter fallback is briefly shown
/// (Issue #41).
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

  // Release builds: ready immediately. There is no hot-restart in
  // production so the isolate-recycle race the guard exists for can't
  // happen — and the 500 ms fallback flash is very visible to users.
  static bool _ready = kReleaseMode;
  static bool _scheduled = false;

  /// Whether it is safe to create platform views.
  static bool get isReady => _ready;

  /// Notifier that fires once when readiness flips to `true`.
  static final ValueNotifier<bool> readyNotifier = ValueNotifier<bool>(
    kReleaseMode,
  );

  /// Schedules the readiness flip if it hasn't been scheduled yet.
  /// No-op in release mode (already ready). In debug mode, waits 500 ms
  /// to let the engine finish purging stale platform-view registrations
  /// from a previous Dart isolate after a hot restart.
  static void ensureScheduled() {
    if (_ready || _scheduled) return;
    _scheduled = true;

    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (_ready) return;
      _ready = true;
      readyNotifier.value = true;
    });
  }
}
