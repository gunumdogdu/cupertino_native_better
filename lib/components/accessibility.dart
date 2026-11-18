/// Accessibility settings of iOS and macOS that Flutter doesn't expose.
///
/// {@category Components}
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _channel = MethodChannel('cn_accessibility');

/// Accessibility settings of iOS and macOS that Flutter doesn't expose, for
/// the whole app.
///
/// Flutter's `MediaQuery` has Reduce Motion (`disableAnimations`), Increase
/// Contrast (`highContrast`) and Bold Text (`boldText`), but not Reduce
/// Transparency. [reduceTransparency] adds it, from the system itself and
/// with no platform view, so any widget can follow it:
///
/// ```dart
/// ValueListenableBuilder<bool>(
///   valueListenable: CNAccessibility.reduceTransparency,
///   builder: (context, reduce, child) => reduce
///       ? ColoredBox(color: solid, child: child)
///       : BackdropFilter(filter: blur, child: child),
///   child: bar,
/// )
/// ```
///
/// Native views of this package, such as Liquid Glass and
/// `CNScrollEdgeEffect`, follow the setting by themselves; this is for what
/// the app draws in Flutter.
abstract final class CNAccessibility {
  static final ValueNotifier<bool> _reduceTransparency = ValueNotifier<bool>(
    false,
  );
  static Future<void>? _initialized;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Whether Reduce Transparency is on: Settings › Accessibility › Display &
  /// Text Size on iOS, System Settings › Accessibility › Display on macOS.
  ///
  /// Updates while the app runs when the user changes the setting. The
  /// value is read from the system on first use, which takes a moment;
  /// until then it is false. To have it on the first frame, await
  /// [ensureInitialized] before `runApp`.
  ///
  /// Always false on other platforms.
  static ValueListenable<bool> get reduceTransparency {
    ensureInitialized();
    return _reduceTransparency;
  }

  /// Reads the settings from the system and starts following their changes.
  ///
  /// [reduceTransparency] does this on first use. Await it before `runApp`
  /// to have the right values on the first frame:
  ///
  /// ```dart
  /// Future<void> main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await CNAccessibility.ensureInitialized();
  ///   runApp(const App());
  /// }
  /// ```
  static Future<void> ensureInitialized() => _initialized ??= _initialize();

  static Future<void> _initialize() async {
    if (!_supported) return;
    WidgetsFlutterBinding.ensureInitialized();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onChanged') _apply(call.arguments);
    });
    try {
      _apply(await _channel.invokeMethod<Object?>('getState'));
    } on MissingPluginException {
      // Tests, and platforms without the plugin: the settings stay off.
    } on PlatformException {
      // Same.
    }
  }

  static void _apply(Object? state) {
    if (state is! Map) return;
    final reduce = state['reduceTransparency'];
    if (reduce is bool) _reduceTransparency.value = reduce;
  }

  /// Sets [reduceTransparency], for tests and previews. A change from the
  /// system replaces it.
  @visibleForTesting
  static void debugSetReduceTransparency(bool value) {
    _initialized ??= Future<void>.value();
    _reduceTransparency.value = value;
  }

  /// Forgets the settings and stops following them, for tests.
  @visibleForTesting
  static void debugReset() {
    _initialized = null;
    _reduceTransparency.value = false;
    _channel.setMethodCallHandler(null);
  }
}
