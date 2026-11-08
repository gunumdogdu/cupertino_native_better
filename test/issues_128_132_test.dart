import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart side of #128 (`CNFloatingIsland` updates), #129 (read-only
/// popover rows), #131 (tab bar action items) and #132 (tab accessibility
/// names, icon-only height). The native-path tests run on a macOS 26+ host
/// with the target platform set to iOS.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  /// Records every call on the platform-views channel and on [prefix]_0..19.
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

  Map<Object?, Object?> creationParams() {
    final create = calls.lastWhere((c) => c.method == 'create');
    final bytes = (create.arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  int viewId() =>
      ((calls.lastWhere((c) => c.method == 'create').arguments as Map)['id']
              as num)
          .toInt();

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

  Future<void> fromNative(
    WidgetTester tester,
    String channel,
    String method,
    Object? args,
  ) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  group('#129 read-only popover rows', () {
    test('a read-only row is encoded with readOnly, others without it', () {
      final c = debugEncodePopoverContent(
        const CNPopoverContent(
          rows: [
            CNPopoverRow(
              id: 'prompt',
              readOnly: true,
              item: CNListItem(title: 'Prompt', trailingText: '1,204'),
            ),
            CNPopoverRow(
              id: 'open',
              item: CNListItem(title: 'Open'),
            ),
          ],
        ),
      );
      final rows = c['rows']! as List;
      expect((rows[0] as Map)['readOnly'], true);
      expect((rows[1] as Map).containsKey('readOnly'), isFalse);
    });
  });

  group('#128 CNFloatingIsland', () {
    Future<void> pumpIsland(
      WidgetTester tester,
      ValueListenable<_IslandProps> props, {
      required ValueChanged<bool> onChanged,
    }) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNFloatingIsland');
      await tester.pumpWidget(
        CupertinoApp(
          home: ValueListenableBuilder<_IslandProps>(
            valueListenable: props,
            builder: (_, p, _) => CNFloatingIsland(
              isExpanded: p.expanded,
              expandedHeight: p.expandedHeight,
              tint: p.tint,
              collapsed: const SizedBox(width: 120, height: 44),
              expanded: const SizedBox(width: 200, height: 100),
              onExpandStateChanged: onChanged,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
    }

    testWidgets('a new size or tint reaches the native island once', (
      tester,
    ) async {
      final props = ValueNotifier(const _IslandProps());
      await pumpIsland(tester, props, onChanged: (_) {});
      expect(named('setConfig'), isEmpty, reason: 'created with the config');

      props.value = const _IslandProps(expandedHeight: 180);
      await settle(tester);
      props.value = const _IslandProps(expandedHeight: 180);
      await settle(tester);
      expect(named('setConfig'), hasLength(1));
      expect(
        (named('setConfig').single.arguments as Map)['expandedHeight'],
        180.0,
      );

      props.value = const _IslandProps(
        expandedHeight: 180,
        tint: Color(0xFFFF8A00),
      );
      await settle(tester);
      expect(named('setConfig'), hasLength(2));
      expect((named('setConfig').last.arguments as Map)['tint'], 0xFFFF8A00);

      await tearDownView(tester);
    }, skip: skip);

    testWidgets(
      'isExpanded from the app reaches native, and the callback may setState',
      (tester) async {
        final props = ValueNotifier(const _IslandProps());
        final reported = <bool>[];
        await pumpIsland(
          tester,
          props,
          onChanged: (expanded) {
            reported.add(expanded);
            // What an app mirroring the state does; it asserted when the
            // island called back during the parent's build.
            props.value = _IslandProps(expanded: expanded);
          },
        );

        props.value = const _IslandProps(expanded: true);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(named('expand'), hasLength(1));
        expect(reported, [true]);

        props.value = const _IslandProps(expanded: false);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(named('collapse'), hasLength(1));
        expect(reported, [true, false]);

        await tearDownView(tester);
      },
      skip: skip,
    );
  });

  group('#131 #132 CNTabBar', () {
    Future<void> pumpBar(
      WidgetTester tester,
      ValueListenable<List<CNTabBarItem>> items, {
      required ValueChanged<int> onTap,
    }) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(
        tester,
        'CupertinoNativeTabBar',
        reply: (call) => call.method == 'getIntrinsicSize'
            ? {'width': 400.0, 'height': 63.0}
            : null,
      );
      await tester.pumpWidget(
        CupertinoApp(
          navigatorObservers: [CNTabBarRouteObserver()],
          home: ValueListenableBuilder<List<CNTabBarItem>>(
            valueListenable: items,
            builder: (_, list, _) => Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                split: true,
                rightCount: 1,
                items: list,
                currentIndex: 0,
                onTap: onTap,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    List<CNTabBarItem> items({VoidCallback? compose, String? inboxName}) => [
      CNTabBarItem(icon: const CNSymbol('tray'), semanticLabel: inboxName),
      const CNTabBarItem(icon: CNSymbol('archivebox')),
      CNTabBarItem(
        label: 'Compose',
        icon: const CNSymbol('square.and.pencil'),
        onPressed: compose,
      ),
    ];

    testWidgets('a plain bar sends neither names nor actions', (tester) async {
      await pumpBar(tester, ValueNotifier(items()), onTap: (_) {});
      final params = creationParams();
      expect(params.containsKey('semanticLabels'), isFalse);
      expect(params.containsKey('actions'), isFalse);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('names and action items are sent at creation', (tester) async {
      await pumpBar(
        tester,
        ValueNotifier(items(compose: () {}, inboxName: 'Inbox')),
        onTap: (_) {},
      );
      final params = creationParams();
      expect(params['semanticLabels'], ['Inbox', '', '']);
      expect(params['actions'], [2]);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('a changed name or action goes out with setItems', (
      tester,
    ) async {
      final list = ValueNotifier(items());
      await pumpBar(tester, list, onTap: (_) {});
      calls.clear();

      list.value = items(compose: () {}, inboxName: 'Inbox');
      await settle(tester);
      final setItems = named('setItems');
      expect(setItems, hasLength(1));
      final args = setItems.single.arguments as Map;
      expect(args['semanticLabels'], ['Inbox', '', '']);
      expect(args['actions'], [2]);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('actionPressed calls onPressed, never onTap', (tester) async {
      var composed = 0;
      final taps = <int>[];
      await pumpBar(
        tester,
        ValueNotifier(items(compose: () => composed++)),
        onTap: taps.add,
      );
      await fromNative(
        tester,
        'CupertinoNativeTabBar_${viewId()}',
        'actionPressed',
        {'index': 2},
      );
      expect(composed, 1);
      expect(taps, isEmpty);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets(
      'an action item reported as selected runs its action and puts the '
      'selection back',
      (tester) async {
        var composed = 0;
        final taps = <int>[];
        await pumpBar(
          tester,
          ValueNotifier(items(compose: () => composed++)),
          onTap: taps.add,
        );
        final channel = 'CupertinoNativeTabBar_${viewId()}';
        calls.clear();
        await fromNative(tester, channel, 'valueChanged', {'index': 2});
        await settle(tester);
        expect(composed, 1);
        expect(taps, isEmpty);
        expect((named('setSelectedIndex').last.arguments as Map)['index'], 0);

        await fromNative(tester, channel, 'valueChanged', {'index': 1});
        expect(taps, [1], reason: 'a destination still calls onTap');
        await tearDownView(tester);
      },
      skip: skip,
    );
  });
}

@immutable
class _IslandProps {
  const _IslandProps({
    this.expanded = false,
    this.expandedHeight = 140,
    this.tint,
  });

  final bool expanded;
  final double expandedHeight;
  final Color? tint;
}
