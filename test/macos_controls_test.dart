// The AppKit-backed controls on macOS: native on every macOS (12+), not only
// 26+; what they send to their macOS views (semantic labels, the colour
// well's size, the tab bar's badges, font and search tab).

import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The view types of the controls this file covers.
const _viewTypes = <String>[
  'CupertinoNativeSlider',
  'CupertinoNativeSwitch',
  'CupertinoNativeSegmentedControl',
  'CupertinoNativeStepper',
  'CupertinoNativeDatePicker',
  'CupertinoNativeColorWell',
  'CupertinoNativeTabBar',
];

/// [PlatformVersion.shouldUseNativeControls] reads the real [Platform]: the
/// native path only exists in a test running on a Mac.
final bool _notOnMac = !Platform.isMacOS;

void main() {
  late List<MethodCall> calls;
  late List<Map<Object?, Object?>> created;

  /// Answers the platform view and control channels as a macOS view would.
  void mockNative(WidgetTester tester) {
    calls = <MethodCall>[];
    created = <Map<Object?, Object?>>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final bytes = args['params'] as Uint8List?;
        created.add(<Object?, Object?>{
          'viewType': args['viewType'],
          'id': args['id'],
          if (bytes != null)
            ...const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(bytes),
                )
                as Map<Object?, Object?>,
        });
      }
      return null;
    });
    for (final type in _viewTypes) {
      for (var id = 0; id < 30; id++) {
        messenger.setMockMethodCallHandler(MethodChannel('${type}_$id'), (
          call,
        ) async {
          calls.add(call);
          if (call.method == 'getIntrinsicSize') {
            return {'width': 300.0, 'height': 40.0};
          }
          return null;
        });
      }
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final type in _viewTypes) {
        for (var id = 0; id < 30; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('${type}_$id'),
            null,
          );
        }
      }
    });
  }

  /// Lets PlatformViewGuard's debug delay pass and the views settle.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Removes the views and the overrides inside the test body, as the
  /// binding checks the platform override is unset when the body returns.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
    PlatformVersion.reset();
  }

  Map<Object?, Object?> paramsOf(String viewType) =>
      created.firstWhere((p) => p['viewType'] == viewType);

  testWidgets('every control is native on macOS 15, below Liquid Glass', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    PlatformVersion.debugOverrideVersions(macOSVersion: 15);
    expect(PlatformVersion.shouldUseNativeGlass, isFalse);
    expect(PlatformVersion.shouldUseNativeControls, isTrue);
    mockNative(tester);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: ListView(
            children: [
              CNSlider(value: 0.5, onChanged: (_) {}),
              Row(children: [CNSwitch(value: true, onChanged: (_) {})]),
              CNSegmentedControl(
                labels: const ['A', 'B'],
                selectedIndex: 0,
                onValueChanged: (_) {},
              ),
              Row(children: [CNStepper(value: 1, onChanged: (_) {})]),
              CNDatePicker(value: DateTime(2026, 11, 4), onChanged: (_) {}),
              Row(
                children: [
                  CNColorWell(
                    color: CupertinoColors.systemIndigo,
                    onChanged: (_) {},
                  ),
                ],
              ),
              CNTabBar(
                items: const [
                  CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                  CNTabBarItem(label: 'Inbox', icon: CNSymbol('tray')),
                ],
                currentIndex: 0,
                onTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.byType(AppKitView), findsNWidgets(_viewTypes.length));
    expect(created.map((p) => p['viewType']).toSet(), _viewTypes.toSet());
    await finish(tester);
  }, skip: _notOnMac);

  testWidgets('CNSegmentedControl sends its semanticLabel and its changes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    mockNative(tester);
    final label = ValueNotifier<String?>('Appearance');
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: ValueListenableBuilder<String?>(
            valueListenable: label,
            builder: (_, l, _) => CNSegmentedControl(
              labels: const ['Light', 'Dark'],
              selectedIndex: 0,
              semanticLabel: l,
              onValueChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(
      paramsOf('CupertinoNativeSegmentedControl')['semanticLabel'],
      'Appearance',
    );

    calls.clear();
    label.value = 'Theme';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      calls
          .where((c) => c.method == 'setSemanticLabel')
          .map((c) => c.arguments),
      [
        {'label': 'Theme'},
      ],
    );
    await finish(tester);
  }, skip: _notOnMac);

  testWidgets(
    'CNSegmentedControl fallback names the group',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNSegmentedControl(
              labels: const ['Light', 'Dark'],
              selectedIndex: 0,
              semanticLabel: 'Appearance',
              onValueChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Appearance'), findsOneWidget);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'the slider, switch, stepper, date picker and colour well send their '
    'semanticLabel to the macOS view',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      mockNative(tester);
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: ListView(
              children: [
                CNSlider(
                  value: 0.5,
                  semanticLabel: 'Volume',
                  onChanged: (_) {},
                ),
                Row(
                  children: [
                    CNSwitch(
                      value: true,
                      semanticLabel: 'Wi-Fi',
                      onChanged: (_) {},
                    ),
                  ],
                ),
                Row(
                  children: [
                    CNStepper(
                      value: 1,
                      semanticLabel: 'Guests',
                      onChanged: (_) {},
                    ),
                  ],
                ),
                CNDatePicker(
                  value: DateTime(2026, 11, 4),
                  semanticLabel: 'Birthday',
                  onChanged: (_) {},
                ),
                Row(
                  children: [
                    CNColorWell(
                      color: CupertinoColors.systemIndigo,
                      semanticLabel: 'Accent color',
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      expect(paramsOf('CupertinoNativeSlider')['semanticLabel'], 'Volume');
      expect(paramsOf('CupertinoNativeSwitch')['semanticLabel'], 'Wi-Fi');
      expect(paramsOf('CupertinoNativeStepper')['semanticLabel'], 'Guests');
      expect(
        paramsOf('CupertinoNativeDatePicker')['semanticLabel'],
        'Birthday',
      );
      expect(
        paramsOf('CupertinoNativeColorWell')['semanticLabel'],
        'Accent color',
      );
      // The slider's track colour is sent as trackTint, which the macOS
      // view reads at creation (it used to read only `tint`).
      final style = paramsOf('CupertinoNativeSlider')['style'] as Map;
      expect(style['trackTint'], isA<int>());
      await finish(tester);
    },
    skip: _notOnMac,
  );

  testWidgets('the macOS colour well keeps its shape and scales with size', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    mockNative(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CNColorWell(
                key: const Key('default'),
                color: CupertinoColors.systemIndigo,
                onChanged: (_) {},
              ),
              CNColorWell(
                key: const Key('large'),
                color: CupertinoColors.systemIndigo,
                size: 44,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await settle(tester);
    Size sizeOf(String key) => tester.getSize(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(AppKitView),
      ),
    );
    expect(sizeOf('default'), const Size(44, 24));
    expect(sizeOf('large'), const Size(60.5, 33));
    await finish(tester);
  }, skip: _notOnMac);

  group('CNTabBar on macOS', () {
    Future<ValueNotifier<_TabProps>> pumpBar(
      WidgetTester tester, {
      void Function(bool)? onSearchActiveChanged,
      List<int>? taps,
    }) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      mockNative(tester);
      final props = ValueNotifier(const _TabProps());
      await tester.pumpWidget(
        CupertinoApp(
          home: ValueListenableBuilder<_TabProps>(
            valueListenable: props,
            builder: (_, p, _) => Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                items: [
                  const CNTabBarItem(
                    label: 'Home',
                    icon: CNSymbol('house'),
                    activeIcon: CNSymbol('house.fill'),
                  ),
                  CNTabBarItem(
                    label: 'Inbox',
                    icon: const CNSymbol('tray'),
                    badge: p.badge,
                  ),
                ],
                currentIndex: 0,
                labelFontSize: p.fontSize,
                searchItem: onSearchActiveChanged == null
                    ? null
                    : CNTabBarSearchItem(
                        onSearchActiveChanged: onSearchActiveChanged,
                      ),
                onTap: (i) => taps?.add(i),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      return props;
    }

    Future<List<String>> change(
      WidgetTester tester,
      ValueNotifier<_TabProps> props,
      _TabProps next,
    ) async {
      calls.clear();
      props.value = next;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return [
        for (final c in calls)
          if (c.method != 'getIntrinsicSize') c.method,
      ];
    }

    testWidgets(
      'creates an AppKit bar with labels, symbols and badges, sized by the '
      'view',
      (tester) async {
        await pumpBar(tester);
        final params = paramsOf('CupertinoNativeTabBar');
        expect(params['labels'], ['Home', 'Inbox']);
        expect(params['sfSymbols'], ['house', 'tray']);
        expect(params['activeSfSymbols'], ['house.fill', 'tray']);
        expect(params['badges'], ['', '']);
        // Width and height come from getIntrinsicSize.
        expect(tester.getSize(find.byType(AppKitView)), const Size(300, 40));
        await finish(tester);
      },
      skip: _notOnMac,
    );

    testWidgets(
      'a badge reaches the bar through setBadges, a font through setFont',
      (tester) async {
        final props = await pumpBar(tester);
        expect(await change(tester, props, const _TabProps(badge: '3')), [
          'setBadges',
        ]);
        expect(
          (calls.firstWhere((c) => c.method == 'setBadges').arguments
              as Map)['badges'],
          ['', '3'],
        );
        expect(
          await change(
            tester,
            props,
            const _TabProps(badge: '3', fontSize: 15),
          ),
          ['setFont'],
        );
        expect(calls.firstWhere((c) => c.method == 'setFont').arguments, {
          'labelFontSize': 15.0,
        });
        await finish(tester);
      },
      skip: _notOnMac,
    );

    testWidgets('the search tab reports searchActiveChanged, not onTap', (
      tester,
    ) async {
      final active = <bool>[];
      final taps = <int>[];
      await pumpBar(tester, onSearchActiveChanged: active.add, taps: taps);
      final params = paramsOf('CupertinoNativeTabBar');
      expect(params['hasSearch'], isTrue);
      expect(params['searchSymbol'], 'magnifyingglass');

      // What the macOS view sends when its search segment is clicked,
      // then when a tab is clicked.
      final id = params['id'] as int;
      Future<void> fromNative(String method, Object args) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'CupertinoNativeTabBar_$id',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, args),
          ),
          (_) {},
        );
        await tester.pump();
      }

      await fromNative('searchActiveChanged', {'isActive': true});
      await fromNative('valueChanged', {'index': 1});
      expect(active, [true]);
      expect(taps, [1]);
      await finish(tester);
    }, skip: _notOnMac);
  });
}

@immutable
class _TabProps {
  const _TabProps({this.badge, this.fontSize});

  final String? badge;
  final double? fontSize;
}
