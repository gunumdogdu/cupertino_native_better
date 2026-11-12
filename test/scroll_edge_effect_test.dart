import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// CNScrollEdgeEffect (#150). The native-path tests run on a macOS 26+ host
/// with the target platform set to iOS.
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

  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  Widget page(
    ScrollController controller, {
    CNScrollEdge edge = CNScrollEdge.top,
  }) {
    return CupertinoApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: 60, bottom: 30),
        ),
        child: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemCount: 100,
              itemExtent: 50,
              itemBuilder: (_, i) => Text('Row $i'),
            ),
            CNScrollEdgeEffect(edge: edge, controller: controller),
          ],
        ),
      ),
    );
  }

  testWidgets('draws nothing off iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(page(ScrollController()));
    expect(find.byType(UiKitView), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'a band from the edge, the safe area by default, with room for the soft '
    'end, and off at rest',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(page(ScrollController()));
      await tester.pump();
      final params = creationParams();
      expect(params['edge'], 'top');
      expect(params['style'], 'soft');
      expect(params['band'], 60.0);
      expect(params['underneath'], 0.0, reason: 'nothing under the edge');
      final rect = tester.getRect(find.byType(UiKitView));
      expect(rect.top, 0);
      expect(rect.height, 108.0);
      expect(
        rect.width,
        800 > 0 ? tester.getSize(find.byType(Stack).first).width : 0,
      );
      await tearDownView(tester);
    },
    skip: skip || !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'mirrors how far the content is under the edge',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      final controller = ScrollController();
      await tester.pumpWidget(page(controller));
      await tester.pump();
      calls.clear();

      controller.jumpTo(30);
      await tester.pump();
      expect(updates().last['underneath'], 30.0);
      controller.jumpTo(500);
      await tester.pump();
      expect(updates().last['underneath'], 100.0, reason: 'capped');
      final count = updates().length;
      controller.jumpTo(600);
      await tester.pump();
      expect(updates().length, count, reason: 'no change past the cap');
      controller.jumpTo(0);
      await tester.pump();
      expect(updates().last['underneath'], 0.0);
      await tearDownView(tester);
    },
    skip: skip || !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'the bottom edge counts the content left below',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      final controller = ScrollController();
      await tester.pumpWidget(page(controller, edge: CNScrollEdge.bottom));
      await tester.pump();
      final params = creationParams();
      expect(params['band'], 30.0);
      expect(params['underneath'], 0.0, reason: 'off until laid out');
      await tester.pump();
      expect(updates().last['underneath'], 100.0, reason: 'a long list');
      expect(
        tester.getRect(find.byType(UiKitView)).bottom,
        tester.getSize(find.byType(Stack).first).height,
      );
      calls.clear();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(updates().last['underneath'], 0.0);
      await tearDownView(tester);
    },
    skip: skip || !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'a drag that starts on the band scrolls the content under it',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      final controller = ScrollController();
      await tester.pumpWidget(page(controller));
      await tester.pump();
      await tester.dragFrom(const Offset(200, 30), const Offset(0, -200));
      await tester.pump();
      expect(controller.offset, greaterThan(100));
      await tearDownView(tester);
    },
    skip: skip || !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'style and brightness changes reach the native view',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      final style = ValueNotifier(CNScrollEdgeStyle.soft);
      await tester.pumpWidget(
        CupertinoApp(
          home: ValueListenableBuilder<CNScrollEdgeStyle>(
            valueListenable: style,
            builder: (_, s, _) => CNScrollEdgeEffect(
              style: s,
              height: 100,
              brightness: Brightness.dark,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(creationParams()['isDark'], isTrue);
      expect(creationParams()['band'], 100.0);
      expect(creationParams()['underneath'], isNull, reason: 'always on');
      calls.clear();
      style.value = CNScrollEdgeStyle.hard;
      await tester.pump();
      expect(updates().single['style'], 'hard');
      await tearDownView(tester);
    },
    skip: skip || !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'the colour of the page under the edge goes with it: the theme scaffold '
    'background by default, so the effect fades toward it and hard is a band '
    'of it (#150)',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      Widget app(Brightness brightness, {Color? color, Brightness? own}) =>
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: CNScrollEdgeEffect(
              height: 100,
              backgroundColor: color,
              brightness: own,
            ),
          );

      await tester.pumpWidget(app(Brightness.light));
      await tester.pump();
      expect(creationParams()['color'], 0xFFFFFFFF, reason: 'light page');
      await tearDownView(tester);

      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pump();
      expect(creationParams()['color'], 0xFF000000, reason: 'dark page');
      expect(creationParams()['isDark'], isTrue);
      await tearDownView(tester);

      // A brightness of its own takes that brightness's system background.
      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(app(Brightness.light, own: Brightness.dark));
      await tester.pump();
      expect(creationParams()['color'], 0xFF000000);
      await tearDownView(tester);

      // A colour of its own, resolved for the effect's brightness.
      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        app(
          Brightness.light,
          color: CupertinoColors.systemGroupedBackground,
          own: Brightness.dark,
        ),
      );
      await tester.pump();
      expect(
        creationParams()['color'],
        CupertinoColors.systemGroupedBackground.darkColor.toARGB32(),
      );
      calls.clear();
      await tester.pumpWidget(
        app(Brightness.light, color: const Color(0xFFFF2020)),
      );
      await tester.pump();
      expect(updates().single['color'], 0xFFFF2020, reason: 'a change');
      await tearDownView(tester);
    },
    skip: skip || !PlatformVersion.shouldUseNativeGlass,
  );

  group('CNTabScaffold.bottomScrollEdgeEffect', () {
    Widget scaffold(bool effect, ScrollController controller) {
      return CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(top: 60, bottom: 30),
          ),
          child: CNTabScaffold(
            placement: CNTabPlacement.bottom,
            bottomScrollEdgeEffect: effect,
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              CNTabBarItem(label: 'A', icon: CNSymbol('house')),
              CNTabBarItem(label: 'B', icon: CNSymbol('gear')),
            ],
            body: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemExtent: 50,
              itemBuilder: (_, i) => Text('Row $i'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'puts the effect behind the bar and follows the body scroll view',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester);
        final controller = ScrollController();
        await tester.pumpWidget(scaffold(false, controller));
        await tester.pump();
        expect(find.byType(CNScrollEdgeEffect), findsNothing);

        await tester.pumpWidget(scaffold(true, controller));
        await tester.pump();
        await tester.pump();
        final effect = tester.widget<CNScrollEdgeEffect>(
          find.byType(CNScrollEdgeEffect),
        );
        expect(effect.edge, CNScrollEdge.bottom);
        expect(effect.height, 30 + CNTabScaffold.bottomBarExtent);
        calls.clear();
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        await tester.pump();
        expect(updates().last['underneath'], 0.0);
        controller.jumpTo(0);
        await tester.pump();
        expect(updates().last['underneath'], 100.0);
        await tearDownView(tester);
      },
      skip: skip || !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
