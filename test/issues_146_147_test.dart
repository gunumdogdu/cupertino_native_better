import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #146 (`CNTabRail` under a pushed page) and #147 (`CNPopupMenuButton`
/// label changes). The native-path tests run on a macOS 26+ host with the
/// target platform set to iOS.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  void listen(
    WidgetTester tester,
    String prefix, {
    Object? Function(MethodCall)? reply,
  }) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    for (var id = 0; id < 20; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('${prefix}_$id'), (
        call,
      ) async {
        calls.add(call);
        return reply?.call(call);
      });
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('${prefix}_$id'),
          null,
        );
      }
    });
  }

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

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

  group('#146 CNTabRail under a pushed page', () {
    const items = [
      CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
      CNTabBarItem(label: 'Calendar', icon: CNSymbol('calendar')),
    ];

    int railIndex(WidgetTester tester) => tester
        .widget<IndexedStack>(
          find.descendant(
            of: find.byType(CNTabRail, skipOffstage: false),
            matching: find.byType(IndexedStack, skipOffstage: false),
          ),
        )
        .index!;

    testWidgets(
      'is not drawn while a page is pushed over it or covers it, and comes '
      'back after the pop without a new view',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, 'CNTabRail');
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          CupertinoApp(
            navigatorKey: navigatorKey,
            home: Align(
              alignment: Alignment.centerLeft,
              child: CNTabRail(items: items, currentIndex: 0, onTap: (_) {}),
            ),
          ),
        );
        await settle(tester);
        expect(railIndex(tester), 1, reason: 'drawn at rest');
        final creates = named('create').length;
        expect(creates, 1);

        navigatorKey.currentState!.push(
          CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(child: SizedBox()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(railIndex(tester), 0, reason: 'not drawn during the push');
        await settle(tester);
        expect(railIndex(tester), 0, reason: 'not drawn while covered');

        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(railIndex(tester), 0, reason: 'not drawn during the pop');
        await settle(tester);
        expect(railIndex(tester), 1, reason: 'drawn again after the pop');
        expect(named('create').length, creates, reason: 'the same view');
        await tearDownView(tester);
      },
      skip: skip,
    );

    testWidgets('autoHideOnPageTransition: false keeps it drawn, clipped', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNTabRail');
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          home: Align(
            alignment: Alignment.centerLeft,
            child: CNTabRail(
              items: items,
              currentIndex: 0,
              onTap: (_) {},
              autoHideOnPageTransition: false,
            ),
          ),
        ),
      );
      await settle(tester);
      calls.clear();
      navigatorKey.currentState!.push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(child: SizedBox()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final transitioning = named('setTransitioning');
      expect(transitioning, isNotEmpty);
      expect((transitioning.first.arguments as Map)['active'], isTrue);
      await settle(tester);
      expect(
        (named('setTransitioning').last.arguments as Map)['active'],
        isFalse,
        reason: 'unclipped once the push has finished',
      );
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#147 CNPopupMenuButton label change', () {
    testWidgets('a new label is set in place, without a new native view', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(
        tester,
        'CupertinoNativePopupMenuButton',
        reply: (call) => call.method == 'getIntrinsicSize'
            ? {'width': 90.0, 'height': 24.0}
            : null,
      );
      final label = ValueNotifier('Newest');
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: label,
              builder: (_, l, _) => CNPopupMenuButton(
                buttonLabel: l,
                shrinkWrap: true,
                items: [
                  CNPopupMenuItem(label: 'Newest', checked: l == 'Newest'),
                  CNPopupMenuItem(label: 'Oldest', checked: l == 'Oldest'),
                ],
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(named('create'), hasLength(1));
      calls.clear();

      label.value = 'Oldest';
      await settle(tester);
      expect(named('create'), isEmpty, reason: 'no new native button');
      expect(named('dispose'), isEmpty);
      expect(
        (named('setButtonTitle').single.arguments as Map)['title'],
        'Oldest',
      );
      expect(named('setItems'), isNotEmpty, reason: 'the checkmark moved');
      expect(
        named('getIntrinsicSize'),
        isNotEmpty,
        reason: 'measured again for the new label',
      );
      await tearDownView(tester);
    }, skip: skip);
  });
}
