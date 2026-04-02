import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Guards platform-view creation during app startup / hot-restart.
///
/// On iOS, `FlutterPlatformViewsController` may retain residual view
/// registrations from a previous Dart isolate immediately after a hot
/// restart. If the new isolate's widgets request platform-view creation
/// in the very first frame, the engine can reject them with
/// `PlatformException(recreating_view, ...)` because the old IDs
/// haven't been fully purged yet.
///
/// This guard delays platform-view widgets by **two post-frame
/// callbacks** (matching the engine's reset lifecycle), then latches
/// [isReady] to `true` for the remainder of the process lifetime.
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
  /// Two nested post-frame callbacks are used so the engine's
  /// platform-view controller has had at least one full frame
  /// to run its own cleanup before any new views are requested.
  static void ensureScheduled() {
    if (_ready || _scheduled) return;
    _scheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_ready) return;
        _ready = true;
        readyNotifier.value = true;
      });
    });
  }
}
