import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #187: `CNButtonConfig.appearance` fixes a native button's light or dark
/// look, as `LiquidGlassConfig.appearance` does for a container (#165). The
/// native-path tests run on a macOS 26+ host.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  void listen(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    for (var id = 0; id < 40; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativeButton_$id'),
        (call) async {
          calls.add(call);
          if (call.method == 'getIntrinsicSize') {
            return {'width': 80.0, 'height': 44.0};
          }
          return null;
        },
      );
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeButton_$id'),
          null,
        );
      }
    });
  }

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

  Map<Object?, Object?> creationParams() {
    final create = named('create').single;
    final bytes = (create.arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  Widget app(CNGlassAppearance appearance, {Brightness? brightness}) {
    return CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness ?? Brightness.light),
      home: Center(
        child: CNButton(
          label: 'Call',
          onPressed: () {},
          config: CNButtonConfig(
            style: CNButtonStyle.glass,
            shrinkWrap: true,
            appearance: appearance,
          ),
        ),
      ),
    );
  }

  test('the default is adaptive', () {
    expect(const CNButtonConfig().appearance, CNGlassAppearance.adaptive);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    group(platform.name, () {
      testWidgets(
        'an adaptive button sends no appearance, a fixed one sends it',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          listen(tester);
          await tester.pumpWidget(app(CNGlassAppearance.adaptive));
          await settle(tester);
          expect(creationParams().containsKey('appearance'), isFalse);
          await tearDownView(tester);

          debugDefaultTargetPlatformOverride = platform;
          calls.clear();
          await tester.pumpWidget(
            app(CNGlassAppearance.light, brightness: Brightness.dark),
          );
          await settle(tester);
          final params = creationParams();
          expect(params['appearance'], 'light');
          expect(params['isDark'], isTrue, reason: 'the app is still dark');
          await tearDownView(tester);
        },
        skip: skip,
      );

      testWidgets(
        'a change of appearance or of the app brightness is sent once',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          listen(tester);
          await tester.pumpWidget(app(CNGlassAppearance.adaptive));
          await settle(tester);
          expect(named('setBrightness'), isEmpty);

          await tester.pumpWidget(app(CNGlassAppearance.light));
          await settle(tester);
          expect(named('setBrightness').map((c) => c.arguments).toList(), [
            {'isDark': false, 'appearance': 'light'},
          ]);

          // The same appearance again: nothing to send.
          calls.clear();
          await tester.pumpWidget(app(CNGlassAppearance.light));
          await settle(tester);
          expect(named('setBrightness'), isEmpty);

          // A dark app keeps the fixed look; the brightness still goes over,
          // for a later switch back to adaptive.
          await tester.pumpWidget(
            app(CNGlassAppearance.light, brightness: Brightness.dark),
          );
          await settle(tester);
          expect(named('setBrightness').map((c) => c.arguments).toList(), [
            {'isDark': true, 'appearance': 'light'},
          ]);

          calls.clear();
          await tester.pumpWidget(
            app(CNGlassAppearance.adaptive, brightness: Brightness.dark),
          );
          await settle(tester);
          expect(named('setBrightness').map((c) => c.arguments).toList(), [
            {'isDark': true, 'appearance': 'adaptive'},
          ]);
          expect(named('create'), isEmpty, reason: 'the same native view');
          await tearDownView(tester);
        },
        skip: skip,
      );
    });
  }
}
