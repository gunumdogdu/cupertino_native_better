import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// With autoHideOnModal the native bar is destroyed while a sheet is up and
/// created again when it closes. These tests change props after the first
/// mount, open and close a sheet, and check what the new native bar is told.
void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    required GlobalKey<NavigatorState> navKey,
    required ValueListenable<_Props> props,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    // The view id is not known up front, so listen on the first few.
    for (var id = 0; id < 20; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativeTabBar_$id'),
        (call) async {
          calls.add(call);
          if (call.method == 'getIntrinsicSize') {
            return {'width': 400.0, 'height': 63.0};
          }
          return null;
        },
      );
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeTabBar_$id'),
          null,
        );
      }
    });

    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navKey,
        navigatorObservers: [CNTabBarRouteObserver()],
        home: ValueListenableBuilder<_Props>(
          valueListenable: props,
          builder: (_, p, _) => CupertinoTheme(
            data: CupertinoThemeData(brightness: p.brightness),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                items: [
                  CNTabBarItem(label: p.label, icon: const CNSymbol('house')),
                  CNTabBarItem(
                    label: 'Profile',
                    icon: const CNSymbol('person'),
                    badge: p.badge,
                  ),
                  const CNTabBarItem(
                    label: 'Settings',
                    icon: CNSymbol('gearshape'),
                  ),
                ],
                currentIndex: 0,
                tint: p.tint,
                labelFontSize: p.labelFontSize,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    // Past PlatformViewGuard's debug delay, then let the native bar land and
    // run its delayed refresh passes.
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openAndCloseSheet(
    WidgetTester tester,
    GlobalKey<NavigatorState> navKey,
  ) async {
    showCupertinoSheet<void>(
      context: navKey.currentContext!,
      scrollableBuilder: (_, _) => const SizedBox(),
    );
    await tester.pumpAndSettle();
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
  }

  /// Calls sent to the native bar after it was last created.
  List<MethodCall> sinceLastCreate() => calls
      .skip(calls.lastIndexWhere((c) => c.method == 'create') + 1)
      .toList();

  Future<void> tearDownBar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  final skip = !(Platform.isMacOS || Platform.isIOS);

  testWidgets(
    'a badge changed since the first mount reaches the recreated bar',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final props = ValueNotifier(const _Props());
      await pumpBar(tester, navKey: navKey, props: props);

      props.value = const _Props(badge: '7');
      await tester.pump(const Duration(milliseconds: 100));
      await openAndCloseSheet(tester, navKey);

      expect(
        calls.where((c) => c.method == 'create').length,
        2,
        reason: 'the sheet destroyed the bar and closing it created a new one',
      );
      final badges = sinceLastCreate()
          .where((c) => c.method == 'setBadges' || c.method == 'setItems')
          .map((c) => (c.arguments as Map)['badges']);
      expect(badges, contains(equals(['', '7', ''])));

      await tearDownBar(tester);
    },
    skip: skip,
  );

  testWidgets(
    'labels, tint and theme changed since the first mount reach the recreated bar',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final props = ValueNotifier(const _Props());
      await pumpBar(tester, navKey: navKey, props: props);

      props.value = const _Props(
        label: 'Start',
        tint: CupertinoColors.systemPink,
        brightness: Brightness.dark,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await openAndCloseSheet(tester, navKey);

      final after = sinceLastCreate();
      final labels = after
          .where((c) => c.method == 'setItems')
          .map((c) => (c.arguments as Map)['labels']);
      expect(labels, contains(equals(['Start', 'Profile', 'Settings'])));
      final tints = after
          .where((c) => c.method == 'setStyle')
          .map((c) => (c.arguments as Map)['tint']);
      expect(tints, contains(CupertinoColors.systemPink.darkColor.toARGB32()));
      final brightness = after
          .where((c) => c.method == 'setBrightness')
          .map((c) => (c.arguments as Map)['isDark']);
      expect(brightness, contains(true));

      await tearDownBar(tester);
    },
    skip: skip,
  );

  testWidgets(
    'a label font changed since the first mount reaches the recreated bar',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final props = ValueNotifier(const _Props());
      await pumpBar(tester, navKey: navKey, props: props);

      props.value = const _Props(labelFontSize: 13);
      await tester.pump(const Duration(milliseconds: 100));
      await openAndCloseSheet(tester, navKey);

      final after = sinceLastCreate();
      final fonts = after
          .where((c) => c.method == 'setFont')
          .map((c) => (c.arguments as Map)['labelFontSize']);
      expect(fonts, contains(13.0));

      await tearDownBar(tester);
    },
    skip: skip,
  );
}

class _Props {
  const _Props({
    this.label = 'Home',
    this.badge = '3',
    this.tint,
    this.brightness = Brightness.light,
    this.labelFontSize,
  });

  final String label;
  final String? badge;
  final Color? tint;
  final Brightness brightness;
  final double? labelFontSize;
}
