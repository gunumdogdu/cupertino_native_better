import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// A badge change takes the lightweight setBadges path. Another prop changed
/// in the same rebuild must still reach the native bar in that same sync.
void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
  });

  Future<void> pumpBar(
    WidgetTester tester,
    ValueListenable<_Props> props,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
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
        home: ValueListenableBuilder<_Props>(
          valueListenable: props,
          builder: (_, p, _) => Align(
            alignment: Alignment.bottomCenter,
            child: CNTabBar(
              items: [
                const CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                CNTabBarItem(
                  label: 'Inbox',
                  icon: const CNSymbol('tray'),
                  badge: p.badge,
                ),
                const CNTabBarItem(
                  label: 'Settings',
                  icon: CNSymbol('gearshape'),
                ),
              ],
              currentIndex: 1,
              split: p.split,
              iconSize: p.iconSize,
              labelFontSize: p.labelFontSize,
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

  /// Changes the props in one rebuild and returns what that sync sent.
  Future<List<MethodCall>> change(
    WidgetTester tester,
    ValueNotifier<_Props> props,
    _Props next,
  ) async {
    final from = calls.length;
    props.value = next;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return calls
        .skip(from)
        .where((c) => c.method != 'getIntrinsicSize')
        .toList();
  }

  Future<void> tearDownBar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  final skip = !(Platform.isMacOS || Platform.isIOS);

  testWidgets('a badge change alone sends only setBadges', (tester) async {
    final props = ValueNotifier(const _Props());
    await pumpBar(tester, props);

    final sent = await change(tester, props, const _Props(badge: '4'));

    expect(sent.map((c) => c.method), ['setBadges']);
    expect((sent.single.arguments as Map)['badges'], ['', '4', '']);

    await tearDownBar(tester);
  }, skip: skip);

  testWidgets('badge and split in one rebuild send setLayout', (tester) async {
    final props = ValueNotifier(const _Props());
    await pumpBar(tester, props);

    final sent = await change(
      tester,
      props,
      const _Props(badge: '4', split: true),
    );

    expect(sent.map((c) => c.method), containsAll(['setBadges', 'setLayout']));
    final layout = sent.singleWhere((c) => c.method == 'setLayout');
    expect(layout.arguments, containsPair('split', true));
    expect(layout.arguments, containsPair('selectedIndex', 1));

    await tearDownBar(tester);
  }, skip: skip);

  testWidgets('badge and label font in one rebuild send setFont', (
    tester,
  ) async {
    final props = ValueNotifier(const _Props());
    await pumpBar(tester, props);

    final sent = await change(
      tester,
      props,
      const _Props(badge: '4', labelFontSize: 16),
    );

    expect(sent.map((c) => c.method), containsAll(['setBadges', 'setFont']));
    final font = sent.singleWhere((c) => c.method == 'setFont');
    expect(font.arguments, containsPair('labelFontSize', 16.0));

    await tearDownBar(tester);
  }, skip: skip);

  testWidgets('badge and iconSize in one rebuild send one setItems', (
    tester,
  ) async {
    final props = ValueNotifier(const _Props());
    await pumpBar(tester, props);

    final sent = await change(
      tester,
      props,
      const _Props(badge: '4', iconSize: 34),
    );

    // setItems carries the badges too, so no separate setBadges.
    expect(sent.map((c) => c.method), ['setItems']);
    final items = sent.single.arguments as Map;
    expect(items['sfSymbolSizes'], [34.0, 34.0, 34.0]);
    expect(items['badges'], ['', '4', '']);
    expect(items['selectedIndex'], 1);

    await tearDownBar(tester);
  }, skip: skip);
}

class _Props {
  const _Props({
    this.badge = '3',
    this.split = false,
    this.iconSize,
    this.labelFontSize,
  });

  final String? badge;
  final bool split;
  final double? iconSize;
  final double? labelFontSize;
}
