import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #173: `CNSearchBar` takes right to left from the ambient
/// `Directionality` (or `textDirection`), and a switch reaches a bar on
/// screen; `labelFontFamily`, `labelFontSize` and `labelFontWeight` set the
/// font of the text, the placeholder and Cancel. Also: the clear icon's
/// colour colours the clear button when `clearButtonColor` is not set.

/// The bar's direction and font, changed by the tests.
class _Look {
  const _Look({this.direction, this.ambient, this.family, this.size});

  final TextDirection? direction;
  final TextDirection? ambient;
  final String? family;
  final double? size;
}

void main() {
  late List<MethodCall> calls;
  final viewIds = <int>[];
  final look = ValueNotifier<_Look>(const _Look());

  void mockNative(WidgetTester tester, TargetPlatform platform) {
    calls = <MethodCall>[];
    viewIds.clear();
    debugDefaultTargetPlatformOverride = platform;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        viewIds.add((call.arguments as Map)['id'] as int);
        calls.add(call);
      }
      return null;
    });
    for (var id = 0; id < 40; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('CNSearchBar_$id'), (
        call,
      ) async {
        calls.add(MethodCall(call.method, call.arguments));
        return null;
      });
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CNSearchBar_$id'),
          null,
        );
      }
    });
  }

  List<Map<Object?, Object?>> creations() => <Map<Object?, Object?>>[
    for (final c in calls)
      if (c.method == 'create')
        const StandardMessageCodec().decodeMessage(
              ByteData.sublistView((c.arguments as Map)['params'] as Uint8List),
            )
            as Map<Object?, Object?>,
  ];

  List<MethodCall> sent(String method) =>
      calls.where((c) => c.method == method).toList();

  Future<void> pumpBar(
    WidgetTester tester, {
    _Look initial = const _Look(),
    CNSymbol? clearIcon,
    Color? clearButtonColor,
    Color? placeholderColor,
    String? initialText,
    FontWeight? weight,
  }) async {
    look.value = initial;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ValueListenableBuilder<_Look>(
              valueListenable: look,
              builder: (_, l, _) {
                final bar = CNSearchBar(
                  expandable: false,
                  initialText: initialText,
                  textDirection: l.direction,
                  labelFontFamily: l.family,
                  labelFontSize: l.size,
                  labelFontWeight: weight,
                  clearIcon: clearIcon,
                  clearButtonColor: clearButtonColor,
                  placeholderColor: placeholderColor,
                );
                // Always wrapped, so a change of direction keeps the bar.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: l.ambient ?? TextDirection.ltr,
                      child: bar,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  for (final platform in <TargetPlatform>[
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    final native = platform == TargetPlatform.iOS
        ? PlatformVersion.shouldUseNativeGlass
        : PlatformVersion.shouldUseNativeControls;
    group('${platform.name} right to left', () {
      testWidgets('takes the ambient Directionality', (tester) async {
        mockNative(tester, platform);
        await pumpBar(tester, initial: const _Look(ambient: TextDirection.rtl));
        expect(creations().single['rtl'], true);
        await finish(tester);
      }, skip: !native);

      testWidgets('textDirection overrides it', (tester) async {
        mockNative(tester, platform);
        await pumpBar(
          tester,
          initial: const _Look(
            ambient: TextDirection.rtl,
            direction: TextDirection.ltr,
          ),
        );
        expect(creations().single['rtl'], false);
        await finish(tester);
      }, skip: !native);

      testWidgets(
        'a switch reaches the bar on screen without creating it again',
        (tester) async {
          mockNative(tester, platform);
          await pumpBar(tester, initial: const _Look());
          expect(creations().single['rtl'], false, reason: 'the app is LTR');
          expect(sent('setLayoutDirection'), isEmpty);

          look.value = const _Look(ambient: TextDirection.rtl);
          await tester.pumpAndSettle();
          expect(sent('setLayoutDirection').single.arguments, {'rtl': true});

          look.value = const _Look(
            ambient: TextDirection.rtl,
            direction: TextDirection.ltr,
          );
          await tester.pumpAndSettle();
          expect(sent('setLayoutDirection').map((c) => c.arguments), [
            {'rtl': true},
            {'rtl': false},
          ]);
          expect(creations(), hasLength(1));
          await finish(tester);
        },
        skip: !native,
      );
    });

    group('${platform.name} label font', () {
      testWidgets('is sent at creation', (tester) async {
        mockNative(tester, platform);
        await pumpBar(
          tester,
          initial: const _Look(family: 'Tajawal', size: 18),
          weight: FontWeight.w500,
        );
        final params = creations().single;
        expect(params['labelFontFamily'], 'Tajawal');
        expect(params['labelFontSize'], 18);
        expect(params['labelFontWeight'], 500);
        await finish(tester);
      }, skip: !native);

      testWidgets('none is sent without one', (tester) async {
        mockNative(tester, platform);
        await pumpBar(tester);
        final params = creations().single;
        expect(params['labelFontFamily'], isNull);
        expect(params['labelFontSize'], isNull);
        await finish(tester);
      }, skip: !native);

      testWidgets(
        'a change reaches the bar on screen without creating it again',
        (tester) async {
          mockNative(tester, platform);
          await pumpBar(tester);
          look.value = const _Look(family: 'Tajawal', size: 18);
          await tester.pumpAndSettle();
          expect(creations(), hasLength(1));
          if (platform == TargetPlatform.iOS) {
            expect(sent('setLabelFont').single.arguments, {
              'labelFontFamily': 'Tajawal',
              'labelFontSize': 18.0,
            });
          } else {
            final config = sent('setConfig').single.arguments as Map;
            expect(config['labelFontFamily'], 'Tajawal');
            expect(config['labelFontSize'], 18.0);
            expect(config['labelFontWeight'], isNull);
          }
          await finish(tester);
        },
        skip: !native,
      );
    });
  }

  testWidgets(
    'iOS: a new placeholder and Cancel title reach the bar on screen',
    (tester) async {
      mockNative(tester, TargetPlatform.iOS);
      final arabic = ValueNotifier<bool>(false);
      await tester.pumpWidget(
        CupertinoApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: arabic,
            builder: (_, ar, _) => Directionality(
              textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
              child: CNSearchBar(
                expandable: false,
                placeholder: ar ? 'ابحث' : 'Search',
                cancelText: ar ? 'إلغاء' : 'Cancel',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      arabic.value = true;
      await tester.pumpAndSettle();
      expect(creations(), hasLength(1));
      expect(sent('setLabels').single.arguments, {
        'placeholder': 'ابحث',
        'cancelText': 'إلغاء',
      });
      expect(sent('setLayoutDirection').single.arguments, {'rtl': true});
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  group('clear icon colour', () {
    testWidgets(
      'colours the clear button when clearButtonColor is not set',
      (tester) async {
        mockNative(tester, TargetPlatform.iOS);
        await pumpBar(
          tester,
          clearIcon: const CNSymbol('xmark.circle', color: Color(0xFF007AFF)),
          placeholderColor: const Color(0xFFFF3B30),
        );
        expect(creations().single['clearButtonColor'], 0xFF007AFF);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets('clearButtonColor wins', (tester) async {
      mockNative(tester, TargetPlatform.iOS);
      await pumpBar(
        tester,
        clearIcon: const CNSymbol('xmark.circle', color: Color(0xFF007AFF)),
        clearButtonColor: const Color(0xFF34C759),
      );
      expect(creations().single['clearButtonColor'], 0xFF34C759);
      await finish(tester);
    }, skip: !PlatformVersion.shouldUseNativeGlass);
  });

  group('the bar drawn in Flutter', () {
    Future<void> pumpFallback(
      WidgetTester tester, {
      _Look initial = const _Look(),
      CNSymbol? clearIcon,
    }) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await pumpBar(
        tester,
        initial: initial,
        clearIcon: clearIcon,
        initialText: 'kite',
        weight: FontWeight.w500,
      );
    }

    Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);
    final icon = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == CupertinoIcons.search,
    );
    final clear = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == CupertinoIcons.xmark_circle_fill,
    );
    final field = find.byType(CupertinoTextField);

    testWidgets('mirrors in a right-to-left Directionality', (tester) async {
      await pumpFallback(
        tester,
        initial: const _Look(ambient: TextDirection.rtl),
      );
      final glass = rectOf(tester, icon);
      final text = rectOf(tester, field);
      final x = rectOf(tester, clear);
      expect(glass.left, greaterThan(text.right - 1), reason: 'glass right');
      expect(x.right, lessThan(text.left + 1), reason: 'clear button left');
      // The gap between the glass and the field is on the glass's side.
      expect(glass.left - text.right, closeTo(8, 0.5));
      final cancel = tester.getRect(find.text('Cancel'));
      expect(cancel.right, lessThan(x.left), reason: 'Cancel on the left');
      await finish(tester);
    });

    testWidgets('textDirection overrides the ambient direction', (
      tester,
    ) async {
      await pumpFallback(
        tester,
        initial: const _Look(direction: TextDirection.rtl),
      );
      expect(
        rectOf(tester, icon).left,
        greaterThan(rectOf(tester, field).right - 1),
      );
      await finish(tester);
    });

    testWidgets('left to right keeps the glass on the left', (tester) async {
      await pumpFallback(tester);
      final glass = rectOf(tester, icon);
      final text = rectOf(tester, field);
      expect(glass.right, lessThan(text.left + 1));
      expect(text.left - glass.right, closeTo(8, 0.5));
      await finish(tester);
    });

    testWidgets('the label font sets the text, placeholder and Cancel', (
      tester,
    ) async {
      await pumpFallback(
        tester,
        initial: const _Look(family: 'Tajawal', size: 18),
      );
      final textField = tester.widget<CupertinoTextField>(field);
      for (final style in [textField.style!, textField.placeholderStyle!]) {
        expect(style.fontFamily, 'Tajawal');
        expect(style.fontSize, 18);
        expect(style.fontWeight, FontWeight.w500);
      }
      final cancel = tester.widget<Text>(find.text('Cancel'));
      expect(cancel.style!.fontFamily, 'Tajawal');
      expect(cancel.style!.fontSize, 18);
      await finish(tester);
    });

    testWidgets('the clear icon colour colours the clear button', (
      tester,
    ) async {
      await pumpFallback(
        tester,
        clearIcon: const CNSymbol('xmark.circle', color: Color(0xFF007AFF)),
      );
      expect(tester.widget<Icon>(clear).color, const Color(0xFF007AFF));
      await finish(tester);
    });
  });
}
