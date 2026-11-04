import 'package:flutter/services.dart';

/// Calls on a platform view's channel for methods that not every platform
/// implements.
extension OptionalMethodCall on MethodChannel {
  /// Calls [method] and treats a missing native implementation as "not
  /// supported on this platform" rather than as an error.
  ///
  /// The macOS views answer only part of what the iOS views do (for example
  /// `setSemanticLabel`, `setInteraction`, `setLabelStyle` and the tab bar's
  /// search calls), so there the call ends in a [MissingPluginException]. The
  /// widgets send these from `didUpdateWidget` without awaiting them, so the
  /// exception used to escape as an uncaught async error. In a terminal run
  /// that only logs, but a debugger that breaks on uncaught exceptions (the
  /// IDE default) pauses the UI isolate on it, and with the merged platform
  /// and UI threads (the macOS default) the UI isolate runs on the main
  /// thread, so the whole app stops with a spinning cursor (#47).
  ///
  /// Every other error still reaches the caller.
  Future<void> invokeOptionalMethod(String method, [Object? arguments]) async {
    try {
      await invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // This platform's native view does not implement [method].
    }
  }
}
