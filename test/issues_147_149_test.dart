import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart' show CupertinoApp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #147 follow-up (a `CNPopupMenuButton` label drawn for a frame at the
/// wrong width) and #149 (glass widgets under a sheet that doesn't publish
/// its frame). The native-path tests run on a macOS 26+ host with the
/// target platform set to iOS.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  void listen(
    WidgetTester tester,
    List<String> prefixes, {
    Object? Function(MethodCall)? reply,
  }) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    for (final prefix in prefixes) {
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(MethodChannel('$prefix$id'), (
          call,
        ) async {
          calls.add(call);
          return reply?.call(call);
        });
      }
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final prefix in prefixes) {
        for (var id = 0; id < 40; id++) {
          messenger.setMockMethodCallHandler(MethodChannel('$prefix$id'), null);
        }
      }
    });
  }

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

  Map<Object?, Object?> creationParams(MethodCall create) {
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

  group('#147 CNPopupMenuButton width and label in the same frame', () {
    // Each title measures 10 pt per character; the unmeasured button is 80.
    Object? reply(MethodCall call) {
      if (call.method == 'getIntrinsicSize') {
        return {'width': 120.0, 'height': 24.0};
      }
      if (call.method == 'measureTitle') {
        final title = (call.arguments as Map)['title'] as String;
        return {'width': title.length * 10.0, 'height': 24.0};
      }
      return null;
    }

    Widget host(ValueListenable<String> label, ValueListenable<bool> shown) {
      return CupertinoApp(
        home: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: shown,
            builder: (_, s, _) => !s
                ? const SizedBox()
                : ValueListenableBuilder<String>(
                    valueListenable: label,
                    builder: (_, l, _) => CNPopupMenuButton(
                      buttonLabel: l,
                      shrinkWrap: true,
                      items: const [CNPopupMenuItem(label: 'One')],
                      onSelected: (_) {},
                    ),
                  ),
          ),
        ),
      );
    }

    double width(WidgetTester tester) =>
        tester.getSize(find.byType(UiKitView)).width;

    testWidgets(
      'a fresh button is created hidden and shown in the frame that gives it '
      'the measured width',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, ['CupertinoNativePopupMenuButton_'], reply: reply);
        await tester.pumpWidget(
          host(ValueNotifier('Fresh 147 a'), ValueNotifier(true)),
        );
        await settle(tester);

        final create = named('create').single;
        expect(creationParams(create)['hiddenUntilSized'], isTrue);
        final reveal = named('reveal').single;
        expect((reveal.arguments as Map)['atWidth'], 120.0);
        expect(width(tester), 120.0);
        await tearDownView(tester);
      },
      skip: skip,
    );

    testWidgets(
      'a new label is measured first, then set at its width; a remount '
      'with a label measured before starts at that width, shown',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, ['CupertinoNativePopupMenuButton_'], reply: reply);
        final label = ValueNotifier('Fresh 147 b');
        final shown = ValueNotifier(true);
        await tester.pumpWidget(host(label, shown));
        await settle(tester);
        calls.clear();

        label.value = 'A much longer label';
        await settle(tester);
        final measure = named('measureTitle').single;
        expect((measure.arguments as Map)['title'], 'A much longer label');
        final set = named('setButtonTitle').single.arguments as Map;
        expect(set['title'], 'A much longer label');
        expect(set['atWidth'], 190.0, reason: 'held for the new width');
        expect(width(tester), 190.0);
        expect(named('create'), isEmpty);
        expect(named('getIntrinsicSize'), isEmpty);

        shown.value = false;
        await settle(tester);
        calls.clear();
        shown.value = true;
        await tester.pump();
        await tester.pump();
        final create = named('create').single;
        expect(creationParams(create)['hiddenUntilSized'], isNull);
        expect(width(tester), 190.0, reason: 'the remembered width');
        await tearDownView(tester);
      },
      skip: skip,
    );
  });

  group('#149 a sheet that does not publish its frame', () {
    Widget app(GlobalKey<NavigatorState> navigator, Widget page) {
      return MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [CNTabBarRouteObserver()],
        home: page,
      );
    }

    void openSheet(GlobalKey<NavigatorState> navigator) {
      showModalBottomSheet<void>(
        context: navigator.currentContext!,
        builder: (_) => const SizedBox(height: 200, width: double.infinity),
      );
    }

    testWidgets('the observer measures where the sheet is', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(navigator, const Scaffold()));
      expect(CNTabBarRouteObserver.routeModalRect.value, isNull);

      openSheet(navigator);
      await tester.pumpAndSettle();
      // 200 pt at the bottom of the 800 by 600 test screen.
      final rect = CNTabBarRouteObserver.routeModalRect.value!;
      expect(rect.bottom, 600);
      expect(rect.top, 400);
      expect(rect.height, 200);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(CNTabBarRouteObserver.routeModalRect.value, isNull);
    });

    testWidgets(
      'a default glass button above the sheet stays, one under it is removed',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, ['CupertinoNativeButton_']);
        final navigator = GlobalKey<NavigatorState>();
        Widget button(Key key) => CNButton.icon(
          key: key,
          icon: const CNSymbol('xmark'),
          config: const CNButtonConfig(style: CNButtonStyle.glass),
          onPressed: () {},
        );
        await tester.pumpWidget(
          app(
            navigator,
            Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Center(child: button(const Key('top'))),
                  // Under the middle of the sheet (at most 640 pt wide, centred).
                  Center(child: button(const Key('bottom'))),
                ],
              ),
            ),
          ),
        );
        await settle(tester);
        expect(find.byType(UiKitView), findsNWidgets(2));

        openSheet(navigator);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('top')),
            matching: find.byType(UiKitView),
          ),
          findsOneWidget,
          reason: 'the sheet is nowhere near it',
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('bottom')),
            matching: find.byType(UiKitView),
          ),
          findsNothing,
          reason: 'the sheet covers it',
        );

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        await settle(tester);
        expect(find.byType(UiKitView), findsNWidgets(2));
        await tearDownView(tester);
      },
      skip: skip || !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
