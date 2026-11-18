import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/popup_menu_encoder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #167 (popup menu right to left), #168 (checked icon), #169 (content
/// padding).
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
          return {'width': 90.0, 'height': 32.0};
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

  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  int? resolve(Color? c) => c?.toARGB32();

  group('#167 CNPopupMenuButton right to left', () {
    Widget host(ValueListenable<TextDirection> direction) {
      return CupertinoApp(
        home: Center(
          child: ValueListenableBuilder<TextDirection>(
            valueListenable: direction,
            builder: (_, d, _) => Directionality(
              textDirection: d,
              child: CNPopupMenuButton(
                buttonLabel: 'ترتيب',
                shrinkWrap: true,
                items: const [CNPopupMenuItem(label: 'الأحدث', checked: true)],
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the ambient Directionality is sent when the view is created', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      await tester.pumpWidget(host(ValueNotifier(TextDirection.rtl)));
      await settle(tester);
      expect(creationParams(named('create').single)['rtl'], isTrue);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('a change of direction reaches the button on screen', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      final direction = ValueNotifier(TextDirection.ltr);
      await tester.pumpWidget(host(direction));
      await settle(tester);
      expect(creationParams(named('create').single)['rtl'], isFalse);
      calls.clear();

      direction.value = TextDirection.rtl;
      await settle(tester);
      expect(named('create'), isEmpty);
      expect(
        (named('setLayoutDirection').single.arguments as Map)['rtl'],
        isTrue,
      );
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('textDirection overrides the ambient direction', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNPopupMenuButton.icon(
              buttonIcon: const CNSymbol('ellipsis'),
              textDirection: TextDirection.rtl,
              items: const [CNPopupMenuItem(label: 'One')],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await settle(tester);
      expect(creationParams(named('create').single)['rtl'], isTrue);
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#168 checkedIcon', () {
    const purple = CNSymbol(
      'checkmark.circle.fill',
      size: 18,
      color: Color(0xFF8E44AD),
    );

    test('a checked item shows the checked symbol as its image, flagged', () {
      final encoded = encodePopupMenuEntries(
        const [
          CNPopupMenuItem(label: 'Newest', checked: true),
          CNPopupMenuItem(label: 'Oldest', icon: CNSymbol('clock')),
        ],
        resolveColor: resolve,
        checkedIcon: purple,
      );
      expect(encoded['sfSymbols'], ['checkmark.circle.fill', 'clock']);
      expect(encoded['sfSymbolSizes'], [18.0, 24.0]);
      expect(encoded['sfSymbolColors'], [0xFF8E44AD, null]);
      expect(encoded['checked'], [true, false]);
      expect(encoded['checkedImage'], [true, false]);
    });

    test('an item checkedIcon wins over the button one, and takes the place '
        'of the item icon', () {
      final encoded = encodePopupMenuEntries(
        const [
          CNPopupMenuItem(
            label: 'Newest',
            icon: CNSymbol('clock'),
            checked: true,
            checkedIcon: CNSymbol('checkmark.seal.fill'),
          ),
        ],
        resolveColor: resolve,
        checkedIcon: purple,
      );
      expect(encoded['sfSymbols'], ['checkmark.seal.fill']);
      expect(encoded['checkedImage'], [true]);
    });

    test('submenus get the checked symbol too', () {
      final encoded = encodePopupMenuEntries(
        const [
          CNPopupMenuSubmenu(
            label: 'More',
            items: [CNPopupMenuItem(label: 'Distance', checked: true)],
          ),
        ],
        resolveColor: resolve,
        checkedIcon: purple,
      );
      final sub = (encoded['submenus'] as List).single as Map;
      expect(sub['sfSymbols'], ['checkmark.circle.fill']);
      expect(sub['checkedImage'], [true]);
    });

    test('without a checkedIcon, nothing changes', () {
      final encoded = encodePopupMenuEntries(const [
        CNPopupMenuItem(label: 'Newest', checked: true),
      ], resolveColor: resolve);
      expect(encoded['sfSymbols'], ['']);
      expect(encoded.containsKey('checkedImage'), isFalse);
    });

    testWidgets("the button's checkedIcon reaches the native menu", (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNPopupMenuButton(
              buttonLabel: 'Sort',
              checkedIcon: purple,
              items: const [
                CNPopupMenuItem(label: 'Newest', checked: true),
                CNPopupMenuItem(label: 'Oldest'),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await settle(tester);
      final params = creationParams(named('create').single);
      expect(params['checkedImage'], [true, false]);
      expect(params['sfSymbols'], ['checkmark.circle.fill', '']);
      await tearDownView(tester);
    }, skip: skip);

    test('a CNPopover row sends its checked symbol', () {
      final content = debugEncodePopoverContent(
        const CNPopoverContent(
          rows: [
            CNPopoverRow(
              id: 'a',
              item: CNListItem(title: 'Newest'),
              checked: true,
              checkedIcon: purple,
            ),
            CNPopoverRow(
              id: 'b',
              item: CNListItem(title: 'Oldest'),
            ),
          ],
        ),
      );
      final rows = content['rows'] as List;
      final a = rows[0] as Map;
      expect(a['checkedSymbol'], 'checkmark.circle.fill');
      expect(a['checkedSymbolSize'], 18.0);
      expect(a['checkedSymbolColor'], 0xFF8E44AD);
      expect((rows[1] as Map).containsKey('checkedSymbol'), isFalse);
    });
  });

  group('#169 contentPadding', () {
    testWidgets('CNPopupMenuButton sends its content insets, zeros included', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNPopupMenuButton(
              buttonLabel: 'Sort 169',
              shrinkWrap: true,
              contentPadding: const EdgeInsetsDirectional.only(end: 2),
              items: const [CNPopupMenuItem(label: 'One')],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await settle(tester);
      final params = creationParams(named('create').single);
      expect(params['contentInsets'], [0.0, 0.0, 0.0, 2.0]);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('without contentPadding, no insets are sent', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CupertinoNativePopupMenuButton_');
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNPopupMenuButton(
              buttonLabel: 'Sort 169 b',
              items: const [CNPopupMenuItem(label: 'One')],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await settle(tester);
      expect(
        creationParams(named('create').single).containsKey('contentInsets'),
        isFalse,
      );
      await tearDownView(tester);
    }, skip: skip);

    testWidgets(
      'CNButton sends contentPadding at creation and sets a new one in place',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, 'CupertinoNativeButton_');
        final padding = ValueNotifier<EdgeInsetsDirectional>(
          EdgeInsetsDirectional.zero,
        );
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: ValueListenableBuilder<EdgeInsetsDirectional>(
                valueListenable: padding,
                builder: (_, p, _) => CNButton(
                  label: 'Filter 169',
                  onPressed: () {},
                  config: CNButtonConfig(shrinkWrap: true, contentPadding: p),
                ),
              ),
            ),
          ),
        );
        await settle(tester);
        expect(creationParams(named('create').single)['contentInsets'], [
          0.0,
          0.0,
          0.0,
          0.0,
        ]);
        calls.clear();

        padding.value = const EdgeInsetsDirectional.symmetric(horizontal: 6);
        await settle(tester);
        expect(named('create'), isEmpty);
        expect((named('setContentInsets').single.arguments as Map)['insets'], [
          0.0,
          6.0,
          0.0,
          6.0,
        ]);
        await tearDownView(tester);
      },
      skip: skip,
    );
  });
}
