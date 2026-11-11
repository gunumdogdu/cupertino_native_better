import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #153 (a light and a dark label colour) and #154 (a `CNButton` label drawn
/// for a frame at the old width; vertical padding ignored). The native-path
/// tests run on a macOS 26+ host with the target platform set to iOS.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  /// Each title measures 10 pt per character, [height] high; a button's own
  /// size is its title's, or [ownSize].
  void listen(
    WidgetTester tester,
    String prefix, {
    Size? ownSize,
    double height = 24,
  }) {
    final titles = <int, String?>{};
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final bytes = args['params'] as Uint8List;
        final params =
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(bytes),
                )
                as Map;
        titles[args['id'] as int] =
            (params['buttonTitle'] ?? params['buttonLabel']) as String?;
      }
      return null;
    });
    for (var id = 0; id < 40; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('$prefix$id'), (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'setButtonTitle') {
          titles[id] = (call.arguments as Map)['title'] as String;
        }
        if (call.method == 'getIntrinsicSize') {
          final own =
              ownSize ?? Size((titles[id]?.length ?? 12) * 10.0, height);
          return {'width': own.width, 'height': own.height};
        }
        if (call.method == 'measureTitle') {
          final title = (call.arguments as Map)['title'] as String;
          return {
            'width': title.length * 10.0,
            'height': ownSize?.height ?? height,
          };
        }
        return null;
      });
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(MethodChannel('$prefix$id'), null);
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

  Size viewSize(WidgetTester tester) => tester.getSize(find.byType(UiKitView));

  Widget host(Widget child) => CupertinoApp(home: Center(child: child));

  Widget counter(
    ValueListenable<String> label,
    ValueListenable<bool> shown, {
    bool animate = false,
  }) {
    return host(
      ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (_, s, _) => !s
            ? const SizedBox()
            : ValueListenableBuilder<String>(
                valueListenable: label,
                builder: (_, l, _) => CNButton(
                  label: l,
                  onPressed: () {},
                  config: CNButtonConfig(
                    shrinkWrap: true,
                    animateSizeChanges: animate,
                  ),
                ),
              ),
      ),
    );
  }

  group('#154 CNButton label and width in the same frame', () {
    testWidgets(
      'a fresh shrink-wrapped button is created hidden and shown in the '
      'frame that gives it the measured width',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, 'CupertinoNativeButton_');
        await tester.pumpWidget(
          counter(ValueNotifier('Fresh 154 a'), ValueNotifier(true)),
        );
        await settle(tester);

        expect(
          creationParams(named('create').single)['hiddenUntilSized'],
          isTrue,
        );
        final reveal = named('reveal').single.arguments as Map;
        expect(reveal['atWidth'], 110.0);
        expect(viewSize(tester).width, 110.0);
        await tearDownView(tester);
      },
      skip: skip,
    );

    testWidgets(
      'a new label is measured first and set at its width; a remount with a '
      'label measured before starts at that width, shown',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, 'CupertinoNativeButton_');
        final label = ValueNotifier('Fresh 154 b');
        final shown = ValueNotifier(true);
        await tester.pumpWidget(counter(label, shown));
        await settle(tester);
        calls.clear();

        label.value = '10/12 (154 b)';
        await settle(tester);
        expect(
          (named('measureTitle').single.arguments as Map)['title'],
          '10/12 (154 b)',
        );
        final set = named('setButtonTitle').single.arguments as Map;
        expect(set['title'], '10/12 (154 b)');
        expect(set['atWidth'], 130.0, reason: 'held for the new width');
        expect(set['keepsTitleWhole'], isFalse);
        expect(viewSize(tester).width, 130.0);
        expect(named('create'), isEmpty);

        shown.value = false;
        await settle(tester);
        calls.clear();
        shown.value = true;
        await tester.pump();
        await tester.pump();
        expect(
          creationParams(named('create').single)['hiddenUntilSized'],
          isNull,
        );
        expect(viewSize(tester).width, 130.0, reason: 'the remembered width');
        await tearDownView(tester);
      },
      skip: skip,
    );

    testWidgets(
      'with animateSizeChanges the label is set at once, kept whole, and the '
      'width eases to the new one',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, 'CupertinoNativeButton_');
        final label = ValueNotifier('Fresh 154 c');
        await tester.pumpWidget(
          counter(label, ValueNotifier(true), animate: true),
        );
        await settle(tester);
        expect(
          creationParams(named('create').single)['keepsTitleWhole'],
          isTrue,
        );
        expect(viewSize(tester).width, 110.0, reason: 'no animation on mount');
        calls.clear();

        label.value = 'A longer label 154 c';
        await tester.pump();
        await tester.pump();
        final set = named('setButtonTitle').single.arguments as Map;
        expect(set['keepsTitleWhole'], isTrue);
        expect(set.containsKey('atWidth'), isFalse);
        await tester.pump(const Duration(milliseconds: 100));
        final mid = viewSize(tester).width;
        expect(mid, greaterThan(110.0));
        expect(mid, lessThan(200.0));
        await tester.pump(const Duration(milliseconds: 200));
        expect(viewSize(tester).width, 200.0);
        await tearDownView(tester);
      },
      skip: skip,
    );
  });

  group('#154 vertical padding', () {
    Widget padded(EdgeInsets? padding, {double? minHeight}) => host(
      CNButton(
        label: 'Padded',
        onPressed: () {},
        config: CNButtonConfig(
          shrinkWrap: true,
          padding: padding,
          minHeight: minHeight,
        ),
      ),
    );

    testWidgets(
      'reaches the native button, and the height fits the label and it',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, 'CupertinoNativeButton_', ownSize: const Size(80, 62));
        await tester.pumpWidget(
          padded(const EdgeInsets.symmetric(horizontal: 12, vertical: 20)),
        );
        await settle(tester);
        final params = creationParams(named('create').single);
        expect(params['paddingTop'], 20.0);
        expect(params['paddingBottom'], 20.0);
        expect(viewSize(tester).height, 62.0);
        await tearDownView(tester);
      },
      skip: skip,
    );

    testWidgets('the height is at least minHeight, or 44', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativeButton_', ownSize: const Size(80, 30));
      await tester.pumpWidget(
        padded(const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
      );
      await settle(tester);
      expect(viewSize(tester).height, 44.0);
      await tearDownView(tester);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativeButton_', ownSize: const Size(80, 25));
      await tester.pumpWidget(
        padded(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minHeight: 20,
        ),
      );
      await settle(tester);
      expect(viewSize(tester).height, 25.0);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('without vertical padding the height stays minHeight or 44', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativeButton_', ownSize: const Size(80, 62));
      await tester.pumpWidget(
        padded(const EdgeInsets.symmetric(horizontal: 12)),
      );
      await settle(tester);
      expect(viewSize(tester).height, 44.0);
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#153 a light and a dark label colour', () {
    const light = Color(0xFF262626);
    const dark = Color(0xFFFFFFFF);

    testWidgets('CNButton sends both and updates them', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativeButton_');
      final colours = ValueNotifier<(Color?, Color?)>((light, dark));
      await tester.pumpWidget(
        host(
          ValueListenableBuilder<(Color?, Color?)>(
            valueListenable: colours,
            builder: (_, c, _) => CNButton(
              label: '3/12',
              onPressed: () {},
              config: CNButtonConfig(
                labelColorLight: c.$1,
                labelColorDark: c.$2,
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      final params = creationParams(named('create').single);
      expect(params['labelColorLight'], light.toARGB32());
      expect(params['labelColorDark'], dark.toARGB32());
      calls.clear();

      colours.value = (null, const Color(0xFFFFCC00));
      await settle(tester);
      final style = named('setLabelStyle').single.arguments as Map;
      expect(style['clearLabelColorLight'], isTrue);
      expect(style['labelColorDark'], 0xFFFFCC00);
      expect(style['clearLabelColorDark'], isFalse);
      expect(named('create'), isEmpty);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('CNPopupMenuButton sends both', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      await tester.pumpWidget(
        host(
          CNPopupMenuButton(
            buttonLabel: 'Sort',
            labelColorLight: light,
            labelColorDark: dark,
            items: const [CNPopupMenuItem(label: 'Newest')],
            onSelected: (_) {},
          ),
        ),
      );
      await settle(tester);
      final params = creationParams(named('create').single);
      expect(params['labelColorLight'], light.toARGB32());
      expect(params['labelColorDark'], dark.toARGB32());
      await tearDownView(tester);
    }, skip: skip);
  });
}
