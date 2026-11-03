import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the clear glass styles keep the existing style names', () {
    expect(CNButtonStyle.glass.name, 'glass');
    expect(CNButtonStyle.prominentGlass.name, 'prominentGlass');
    expect(CNButtonStyle.clearGlass.name, 'clearGlass');
    expect(CNButtonStyle.prominentClearGlass.name, 'prominentClearGlass');
  });

  group('CNButton clear glass on the channel', () {
    final created = <Map<Object?, Object?>>[];

    void mockNative(WidgetTester tester) {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final params = (call.arguments as Map)['params'] as Uint8List;
          created.add(
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(params),
                )
                as Map<Object?, Object?>,
          );
        }
        return null;
      });
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeButton_$id'),
          (call) async =>
              call.method == 'getIntrinsicSize' ? {'width': 80.0} : null,
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

    Future<Map<Object?, Object?>> createdFor(
      WidgetTester tester,
      CNButtonStyle style, {
      Color? tint,
    }) async {
      created.clear();
      mockNative(tester);
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(primaryColor: Color(0xFF0000FF)),
          home: Center(
            child: CNButton(
              // A new key per case, so each one creates its own native view.
              key: ValueKey<Object?>((style, tint)),
              label: 'Go',
              tint: tint,
              onPressed: () {},
              config: CNButtonConfig(style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return created.single;
    }

    testWidgets(
      'a glass button is encoded as before',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final params = await createdFor(tester, CNButtonStyle.glass);
        expect(params, {
          'buttonTitle': 'Go',
          'buttonIconSize': 20.0,
          'round': true,
          'buttonStyle': 'glass',
          'enabled': true,
          'isDark': false,
          'style': <Object?, Object?>{},
          'imagePlacement': 'leading',
          'glassEffectInteractive': true,
          'interaction': true,
        });
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'clear glass sends its style and, like glass, no accent',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final params = await createdFor(tester, CNButtonStyle.clearGlass);
        expect(params['buttonStyle'], 'clearGlass');
        expect(params['style'], <Object?, Object?>{});

        final tinted = await createdFor(
          tester,
          CNButtonStyle.clearGlass,
          tint: const Color(0xFFFFFFFF),
        );
        expect(tinted['style'], {'tint': 0xFFFFFFFF});
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'prominent clear glass falls back to the theme accent',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final params = await createdFor(
          tester,
          CNButtonStyle.prominentClearGlass,
        );
        expect(params['buttonStyle'], 'prominentClearGlass');
        expect(params['style'], {'tint': 0xFF0000FF});
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });

  group('CNButton clear glass fallback', () {
    Future<Color?> fallbackColor(
      WidgetTester tester,
      CNButtonStyle style,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Material(
            child: Center(
              child: CNButton(
                label: 'Go',
                onPressed: () {},
                config: CNButtonConfig(style: style),
              ),
            ),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(CNButton),
          matching: find.byType(Container),
        ),
      );
      return (box.decoration as BoxDecoration).color;
    }

    testWidgets('matches the glass styles it stands in for', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final glass = await fallbackColor(tester, CNButtonStyle.glass);
      final clear = await fallbackColor(tester, CNButtonStyle.clearGlass);
      final prominent = await fallbackColor(
        tester,
        CNButtonStyle.prominentGlass,
      );
      final prominentClear = await fallbackColor(
        tester,
        CNButtonStyle.prominentClearGlass,
      );
      expect(clear, glass);
      expect(prominentClear, prominent);
      expect(prominent, isNot(glass));
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
