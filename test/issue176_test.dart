import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #176: `CNAccessibility.reduceTransparency` and
/// `CNScrollEdgeEffect.reduceTransparencyHeight`.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  const accessibility = MethodChannel('cn_accessibility');

  group('CNAccessibility.reduceTransparency', () {
    late int getStateCalls;

    void answer(WidgetTester tester, {required bool reduce}) {
      getStateCalls = 0;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(accessibility, (call) async {
        if (call.method == 'getState') {
          getStateCalls++;
          return {'reduceTransparency': reduce};
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(accessibility, null);
        CNAccessibility.debugReset();
      });
    }

    /// The native side reporting a change of the setting.
    Future<void> nativeChange(WidgetTester tester, bool reduce) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'cn_accessibility',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('onChanged', {'reduceTransparency': reduce}),
        ),
        (_) {},
      );
    }

    testWidgets('reads the setting on first use, once', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer(tester, reduce: true);
      final listenable = CNAccessibility.reduceTransparency;
      expect(listenable.value, isFalse, reason: 'before the answer');
      await tester.pump();
      expect(listenable.value, isTrue);
      CNAccessibility.reduceTransparency;
      await CNAccessibility.ensureInitialized();
      expect(getStateCalls, 1);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('follows changes while the app runs, and rebuilds listeners', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer(tester, reduce: false);
      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: CNAccessibility.reduceTransparency,
          builder: (_, reduce, _) =>
              Text(reduce ? 'solid' : 'blur', textDirection: TextDirection.ltr),
        ),
      );
      await tester.pump();
      expect(find.text('blur'), findsOneWidget);

      await nativeChange(tester, true);
      await tester.pump();
      expect(find.text('solid'), findsOneWidget);

      await nativeChange(tester, false);
      await tester.pump();
      expect(find.text('blur'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('ensureInitialized has the value before the first frame', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      answer(tester, reduce: true);
      await CNAccessibility.ensureInitialized();
      expect(CNAccessibility.reduceTransparency.value, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('stays off, without asking, on other platforms', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      answer(tester, reduce: true);
      await CNAccessibility.ensureInitialized();
      expect(CNAccessibility.reduceTransparency.value, isFalse);
      expect(getStateCalls, 0);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('debugSetReduceTransparency sets it for previews', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer(tester, reduce: false);
      CNAccessibility.debugSetReduceTransparency(true);
      await tester.pump();
      expect(CNAccessibility.reduceTransparency.value, isTrue);
      expect(getStateCalls, 0);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('CNScrollEdgeEffect.reduceTransparencyHeight', () {
    late List<MethodCall> calls;

    void listen(WidgetTester tester) {
      calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CNScrollEdgeEffect_$id'),
          (call) async {
            calls.add(call);
            return null;
          },
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (var id = 0; id < 20; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('CNScrollEdgeEffect_$id'),
            null,
          );
        }
      });
    }

    Map<Object?, Object?> creationParams() {
      final create = calls.firstWhere((c) => c.method == 'create');
      final bytes = (create.arguments as Map)['params'] as Uint8List;
      return const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(bytes),
          )
          as Map<Object?, Object?>;
    }

    List<Map<Object?, Object?>> updates() => calls
        .where((c) => c.method == 'update')
        .map((c) => c.arguments as Map<Object?, Object?>)
        .toList();

    Widget page({double height = 120, double? rtHeight}) {
      return CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(top: 60, bottom: 34),
          ),
          child: Stack(
            children: [
              ListView.builder(
                itemCount: 100,
                itemExtent: 50,
                itemBuilder: (_, i) => Text('Row $i'),
              ),
              CNScrollEdgeEffect(
                edge: CNScrollEdge.bottom,
                height: height,
                reduceTransparencyHeight: rtHeight,
              ),
            ],
          ),
        ),
      );
    }

    Future<void> tearDownView(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets(
      'the Reduce Transparency band is sent with the normal one',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester);
        await tester.pumpWidget(page(rtHeight: 34));
        await tester.pump();
        final params = creationParams();
        expect(params['band'], 120.0);
        expect(params['rtBand'], 34.0);
        // Sized for the taller band, with room for the soft end, so the view
        // keeps its size when the setting changes.
        final rect = tester.getRect(find.byType(UiKitView));
        expect(rect.height, 168.0);
        expect(rect.bottom, tester.getRect(find.byType(Stack).first).bottom);
        await tearDownView(tester);
      },
      skip: skip || !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'without it, nothing changes',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester);
        await tester.pumpWidget(page());
        await tester.pump();
        final params = creationParams();
        expect(params.containsKey('rtBand'), isTrue);
        expect(params['rtBand'], isNull);
        expect(tester.getRect(find.byType(UiKitView)).height, 168.0);
        await tearDownView(tester);
      },
      skip: skip || !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'a taller Reduce Transparency band sizes the view',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester);
        await tester.pumpWidget(page(height: 40, rtHeight: 90));
        await tester.pump();
        expect(tester.getRect(find.byType(UiKitView)).height, 138.0);
        await tearDownView(tester);
      },
      skip: skip || !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'a new value reaches the view on screen',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester);
        await tester.pumpWidget(page(rtHeight: 34));
        await tester.pump();
        calls.clear();

        await tester.pumpWidget(page(rtHeight: 0));
        await tester.pump();
        expect(calls.where((c) => c.method == 'create'), isEmpty);
        expect(updates().single['rtBand'], 0.0);
        calls.clear();

        await tester.pumpWidget(page());
        await tester.pump();
        final update = updates().single;
        expect(update.containsKey('rtBand'), isTrue);
        expect(update['rtBand'], isNull);
        await tearDownView(tester);
      },
      skip: skip || !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
