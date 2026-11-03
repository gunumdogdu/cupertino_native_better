import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `CNTabBarItem.menuItems` on the native bar: what the bar is created with
/// and told about menus. The host runs the native path (macOS 26+), with the
/// target platform set to iOS.
void main() {
  late List<MethodCall> calls;
  late Set<String> failing;

  setUp(() {
    calls = <MethodCall>[];
    failing = <String>{};
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
          if (failing.contains(call.method)) {
            throw MissingPluginException(call.method);
          }
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
          builder: (_, p, _) => Align(
            alignment: Alignment.bottomCenter,
            child: CNTabBar(
              items: [
                const CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                CNTabBarItem(
                  label: 'Create',
                  icon: const CNSymbol('plus'),
                  badge: p.badge,
                  menuItems: p.menu == null
                      ? null
                      : [CNPopupMenuItem(label: p.menu!)],
                ),
              ],
              currentIndex: 0,
              searchItem: p.search
                  ? const CNTabBarSearchItem(placeholder: 'Search')
                  : null,
              onTap: (_) {},
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The creation params of the bar created last.
  Map<Object?, Object?> lastCreationParams() {
    final create = calls.lastWhere((c) => c.method == 'create');
    final bytes = (create.arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

  Future<void> tearDownBar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  final skip = !(Platform.isMacOS || Platform.isIOS);

  testWidgets('a bar without menus sends none', (tester) async {
    final props = ValueNotifier(const _Props());
    await pumpBar(tester, navKey: GlobalKey(), props: props);

    expect(lastCreationParams().containsKey('menus'), isFalse);
    expect(named('setMenus'), isEmpty);

    await tearDownBar(tester);
  }, skip: skip);

  testWidgets('a bar with a menu is created with it, null for plain items', (
    tester,
  ) async {
    final props = ValueNotifier(const _Props(menu: 'New note'));
    await pumpBar(tester, navKey: GlobalKey(), props: props);

    final menus = lastCreationParams()['menus'] as List;
    expect(menus, hasLength(2));
    expect(menus[0], isNull);
    expect(menus[1], isA<Map>());
    expect(
      named('setMenus'),
      isEmpty,
      reason: 'the bar was created with the current menus',
    );

    await tearDownBar(tester);
  }, skip: skip);

  testWidgets('a changed entry is sent once; an equal rebuild sends nothing', (
    tester,
  ) async {
    final props = ValueNotifier(const _Props(menu: 'New note'));
    await pumpBar(tester, navKey: GlobalKey(), props: props);

    props.value = const _Props(menu: 'New list');
    await settle(tester);
    props.value = const _Props(menu: 'New list', badge: '1');
    await settle(tester);

    expect(named('setMenus'), hasLength(1));

    props.value = const _Props(badge: '1');
    await settle(tester);
    final removed = named('setMenus').last.arguments as Map;
    expect(removed['menus'], isEmpty, reason: 'no item has a menu any more');

    await tearDownBar(tester);
  }, skip: skip);

  testWidgets('a failing setMenus does not stop the other updates', (
    tester,
  ) async {
    final props = ValueNotifier(const _Props(menu: 'New note'));
    await pumpBar(tester, navKey: GlobalKey(), props: props);
    failing.add('setMenus');

    props.value = const _Props(menu: 'New list', badge: '4');
    await settle(tester);

    expect(named('setMenus'), hasLength(1));
    final badges = calls
        .where((c) => c.method == 'setBadges' || c.method == 'setItems')
        .map((c) => (c.arguments as Map)['badges']);
    expect(badges, contains(equals(['', '4'])));

    await tearDownBar(tester);
  }, skip: skip);

  testWidgets('a bar with a search item keeps menu items as plain tabs', (
    tester,
  ) async {
    final props = ValueNotifier(const _Props(menu: 'New note', search: true));
    await pumpBar(tester, navKey: GlobalKey(), props: props);

    props.value = const _Props(menu: 'New list', search: true);
    await settle(tester);

    expect(lastCreationParams().containsKey('menus'), isFalse);
    expect(named('setMenus'), isEmpty);

    await tearDownBar(tester);
  }, skip: skip);

  testWidgets(
    'a menu changed since the first mount reaches the recreated bar',
    (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final props = ValueNotifier(const _Props(menu: 'New note'));
      await pumpBar(tester, navKey: navKey, props: props);

      props.value = const _Props(menu: 'New list');
      await settle(tester);
      showCupertinoSheet<void>(
        context: navKey.currentContext!,
        scrollableBuilder: (_, _) => const SizedBox(),
      );
      await tester.pumpAndSettle();
      navKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(named('create'), hasLength(2));
      final sinceCreate = calls.skip(
        calls.lastIndexWhere((c) => c.method == 'create') + 1,
      );
      final sent = sinceCreate
          .where((c) => c.method == 'setMenus')
          .map((c) => (c.arguments as Map)['menus'] as List);
      expect(
        sent.map((m) => ((m[1] as Map)['labels'] as List).first),
        contains('New list'),
        reason: 'the new bar is built from the first params, then told',
      );

      await tearDownBar(tester);
    },
    skip: skip,
  );
}

class _Props {
  const _Props({this.menu, this.badge, this.search = false});

  /// The label of the second item's only menu entry, or null for no menu.
  final String? menu;
  final String? badge;
  final bool search;
}
