// Issue #165: `LiquidGlassConfig.appearance` keeps the glass light or dark
// whatever the app's brightness, and reaches the native view as
// `appearance` in the creation params and in `updateConfig`.

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creation params of each glass container created, in order.
final _created = <Map<Object?, Object?>>[];

/// `updateConfig` arguments sent to the glass containers, in order.
final _updates = <Map<Object?, Object?>>[];

void _mockNative(WidgetTester tester) {
  _created.clear();
  _updates.clear();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
    call,
  ) async {
    if (call.method == 'create') {
      final args = call.arguments as Map;
      if (args['viewType'] == 'CupertinoNativeLiquidGlassContainer') {
        final bytes = args['params'] as Uint8List;
        _created.add(
          const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(bytes),
              )
              as Map<Object?, Object?>,
        );
      }
    }
    return null;
  });
  for (var id = 0; id < 30; id++) {
    messenger.setMockMethodCallHandler(
      MethodChannel('CupertinoNativeLiquidGlassContainer_$id'),
      (call) async {
        if (call.method == 'updateConfig') {
          _updates.add(call.arguments as Map<Object?, Object?>);
        }
        return null;
      },
    );
  }
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (var id = 0; id < 30; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativeLiquidGlassContainer_$id'),
        null,
      );
    }
  });
}

/// Pumps [child] in a light app and waits out the platform view start-up.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness),
      home: Center(child: child),
    ),
  );
  // Platform views wait 500 ms after start-up in debug builds.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

/// Removes the views and the platform override inside the test body, as the
/// binding checks the override is unset when the body returns.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  debugDefaultTargetPlatformOverride = null;
}

Widget _glass(CNGlassAppearance? appearance, {Key? key}) =>
    LiquidGlassContainer(
      key: key,
      config: appearance == null
          ? const LiquidGlassConfig()
          : LiquidGlassConfig(appearance: appearance),
      child: const SizedBox(width: 160, height: 56),
    );

void main() {
  group('CNGlassAppearance', () {
    test('has adaptive, light and dark', () {
      expect(CNGlassAppearance.values, [
        CNGlassAppearance.adaptive,
        CNGlassAppearance.light,
        CNGlassAppearance.dark,
      ]);
    });
  });

  group('LiquidGlassConfig.appearance', () {
    test('defaults to adaptive', () {
      expect(const LiquidGlassConfig().appearance, CNGlassAppearance.adaptive);
    });

    test('is part of equality and the hash code', () {
      const light = LiquidGlassConfig(appearance: CNGlassAppearance.light);
      const alsoLight = LiquidGlassConfig(appearance: CNGlassAppearance.light);
      const dark = LiquidGlassConfig(appearance: CNGlassAppearance.dark);
      expect(light, alsoLight);
      expect(light.hashCode, alsoLight.hashCode);
      expect(light, isNot(dark));
      expect(light, isNot(const LiquidGlassConfig()));
    });
  });

  final skip = !PlatformVersion.shouldUseNativeControls;

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    group('LiquidGlassContainer on ${platform.name}', () {
      testWidgets('sends adaptive by default', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        _mockNative(tester);
        await _pump(tester, _glass(null));

        expect(_created.single['appearance'], 'adaptive');
        expect(_created.single['isDark'], false);
        await _finish(tester);
      }, skip: skip);

      testWidgets('sends light and dark as set', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        _mockNative(tester);
        await _pump(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _glass(CNGlassAppearance.light),
              _glass(CNGlassAppearance.dark),
            ],
          ),
          // Light glass in a dark app: the brightness still goes along,
          // the native side lets the appearance win.
          brightness: Brightness.dark,
        );

        expect(_created.map((p) => p['appearance']), ['light', 'dark']);
        expect(_created.map((p) => p['isDark']), [true, true]);
        await _finish(tester);
      }, skip: skip);

      testWidgets('sends a changed appearance with updateConfig', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        _mockNative(tester);
        const key = ValueKey('glass');
        await _pump(tester, _glass(CNGlassAppearance.adaptive, key: key));
        expect(_updates, isEmpty);

        await _pump(tester, _glass(CNGlassAppearance.light, key: key));
        expect(_created, hasLength(1), reason: 'the view is kept');
        expect(_updates.last['appearance'], 'light');

        await _pump(tester, _glass(CNGlassAppearance.dark, key: key));
        expect(_updates.last['appearance'], 'dark');
        await _finish(tester);
      }, skip: skip);

      testWidgets('liquidGlass() forwards the appearance', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        _mockNative(tester);
        // liquidGlass() only wraps where Liquid Glass exists, which a test
        // host may not report; the container itself is checked above.
        await _pump(
          tester,
          const SizedBox(
            width: 120,
            height: 44,
          ).liquidGlass(appearance: CNGlassAppearance.dark),
        );

        if (PlatformVersion.supportsLiquidGlass) {
          expect(_created.single['appearance'], 'dark');
        } else {
          expect(_created, isEmpty);
        }
        await _finish(tester);
      }, skip: skip);
    });
  }
}
