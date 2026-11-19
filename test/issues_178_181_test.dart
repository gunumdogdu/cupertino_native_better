import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/reusable_platform_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #179 (a right-to-left label measured for its own direction) and #181
/// (`CNPopupMenuButton.itemLabelFontFamily`). #178 is native only: the menu
/// is laid out right to left from its first frame.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  void listen(WidgetTester tester, String prefix) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    for (var id = 0; id < 40; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('$prefix$id'), (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'getIntrinsicSize' ||
            call.method == 'measureTitle') {
          return {'width': 141.0, 'height': 22.0};
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
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Removes the button. With nothing kept for reuse (#166), the next one is
  /// created anew.
  Future<void> unmount(WidgetTester tester) async {
    ReusablePlatformViews.keepAlive = Duration.zero;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tearDownView(WidgetTester tester) async {
    await unmount(tester);
    debugDefaultTargetPlatformOverride = null;
  }

  group('#179 a label measured in its own direction', () {
    // A label no other test uses, so the shared width cache starts empty.
    const label = 'سيارات معروضة 179';

    Widget host(TextDirection direction) {
      return CupertinoApp(
        home: Center(
          child: Directionality(
            textDirection: direction,
            child: CNPopupMenuButton(
              buttonLabel: label,
              buttonIcon: const CNSymbol('arrow.up.arrow.down', size: 14),
              imagePadding: 4,
              contentPadding: EdgeInsetsDirectional.zero,
              height: 22,
              shrinkWrap: true,
              buttonStyle: CNButtonStyle.plain,
              items: const [CNPopupMenuItem(label: label, checked: true)],
              onSelected: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets(
      'a width measured left to right is not used right to left, and the '
      'other way round',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, 'CupertinoNativePopupMenuButton_');

        await tester.pumpWidget(host(TextDirection.ltr));
        await settle(tester);
        expect(
          creationParams(named('create').single)['hiddenUntilSized'],
          isTrue,
          reason: 'not measured yet',
        );
        await unmount(tester);
        calls.clear();

        // The same label and options, right to left: measured again, so it
        // isn't shown at the left-to-right width.
        await tester.pumpWidget(host(TextDirection.rtl));
        await settle(tester);
        expect(
          creationParams(named('create').single)['hiddenUntilSized'],
          isTrue,
          reason: 'right to left has its own width',
        );
        await unmount(tester);
        calls.clear();

        // Both directions are known now: shown at once.
        for (final direction in TextDirection.values) {
          await tester.pumpWidget(host(direction));
          await settle(tester);
          final params = creationParams(named('create').single);
          expect(params['hiddenUntilSized'], isNull, reason: '$direction');
          expect(params['rtl'], direction == TextDirection.rtl);
          await unmount(tester);
          calls.clear();
        }
        debugDefaultTargetPlatformOverride = null;
      },
      skip: skip,
    );
  });

  group('#181 itemLabelFontFamily', () {
    Widget host({String? family, bool icon = false}) {
      const items = [
        CNPopupMenuItem(label: 'Newest', checked: true),
        CNPopupMenuItem(label: 'Price', subtitle: 'Low to high'),
      ];
      return CupertinoApp(
        home: Center(
          child: icon
              ? CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis'),
                  itemLabelFontFamily: family,
                  items: items,
                  onSelected: (_) {},
                )
              : CNPopupMenuButton(
                  buttonLabel: 'Sort',
                  itemLabelFontFamily: family,
                  items: items,
                  onSelected: (_) {},
                ),
        ),
      );
    }

    testWidgets('is sent when the view is created, on both constructors', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      for (final icon in [false, true]) {
        await tester.pumpWidget(host(family: 'Tajawal', icon: icon));
        await settle(tester);
        expect(
          creationParams(named('create').single)['itemLabelFontFamily'],
          'Tajawal',
          reason: icon ? '.icon' : 'label',
        );
        await unmount(tester);
        calls.clear();
      }
      debugDefaultTargetPlatformOverride = null;
    }, skip: skip);

    testWidgets('null sends nothing, so the menu keeps the system font', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      await tester.pumpWidget(host());
      await settle(tester);
      expect(
        creationParams(
          named('create').single,
        ).containsKey('itemLabelFontFamily'),
        isFalse,
      );
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('a new family makes a new native button', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      await tester.pumpWidget(host(family: 'Tajawal'));
      await settle(tester);
      expect(named('create'), hasLength(1));

      await tester.pumpWidget(host(family: 'Georgia'));
      await settle(tester);
      expect(named('create'), hasLength(2));
      expect(
        creationParams(named('create').last)['itemLabelFontFamily'],
        'Georgia',
      );
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('the fallback action sheet uses it for item titles only', (
      tester,
    ) async {
      PlatformVersion.debugForceFallbacks = true;
      addTearDown(PlatformVersion.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(host(family: 'Tajawal'));
      await tester.tap(find.text('Sort'));
      await tester.pumpAndSettle();

      TextStyle? styleOf(String text) =>
          tester.widget<Text>(find.text(text)).style;
      expect(styleOf('Newest')?.fontFamily, 'Tajawal');
      expect(styleOf('Price')?.fontFamily, 'Tajawal');
      expect(styleOf('Low to high')?.fontFamily, isNull, reason: 'subtitle');

      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      await tearDownView(tester);
    });
  });
}
