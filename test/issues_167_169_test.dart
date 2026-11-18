import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart side of #167 (right to left), #168 (`checkedIcon`) and #169
/// (`contentPadding`) for CNPopupMenuButton. The native-path tests run on a
/// macOS 26+ host with the target platform set to iOS.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  const prefix = 'CupertinoNativePopupMenuButton_';

  void listen(WidgetTester tester) {
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
          return {'width': 80.0, 'height': 32.0};
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

  Map<Object?, Object?> creationParams() {
    final create = named('create').last;
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

  Widget app(Widget child) => CupertinoApp(home: Center(child: child));

  const items = [
    CNPopupMenuItem(label: 'Newest', checked: true),
    CNPopupMenuItem(label: 'Oldest'),
  ];

  group('#167 right to left', () {
    testWidgets('sends rtl from Directionality, and a switch later', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      final dir = ValueNotifier(TextDirection.rtl);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<TextDirection>(
            valueListenable: dir,
            builder: (_, d, _) => Directionality(
              textDirection: d,
              child: CNPopupMenuButton(
                buttonLabel: 'Sort',
                items: items,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(creationParams()['rtl'], isTrue);
      dir.value = TextDirection.ltr;
      await settle(tester);
      final switches = named('setLayoutDirection');
      expect(switches, hasLength(1));
      expect((switches.single.arguments as Map)['rtl'], isFalse);
      // The direction is changed in place, not by a new view.
      expect(named('create'), hasLength(1));
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('textDirection overrides Directionality, on .icon too', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        app(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CNPopupMenuButton.icon(
              buttonIcon: const CNSymbol('ellipsis.circle'),
              textDirection: TextDirection.rtl,
              items: items,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await settle(tester);
      expect(creationParams()['rtl'], isTrue);
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#168 checkedIcon', () {
    testWidgets('is sent with its size, colour and mode', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        app(
          CNPopupMenuButton(
            buttonLabel: 'Sort',
            checkedIcon: const CNSymbol(
              'checkmark.circle.fill',
              size: 18,
              color: Color(0xFF990099),
              mode: CNSymbolRenderingMode.hierarchical,
            ),
            items: items,
            onSelected: (_) {},
          ),
        ),
      );
      await settle(tester);
      final icon = creationParams()['checkedIcon'] as Map;
      expect(icon['name'], 'checkmark.circle.fill');
      expect(icon['size'], 18);
      expect(icon['color'], 0xFF990099);
      expect(icon['mode'], 'hierarchical');
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('the default size (24) leaves the menu its own size', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        app(
          CNPopupMenuButton.icon(
            buttonIcon: const CNSymbol('ellipsis.circle'),
            checkedIcon: const CNSymbol('checkmark.circle.fill'),
            items: items,
            onSelected: (_) {},
          ),
        ),
      );
      await settle(tester);
      final icon = creationParams()['checkedIcon'] as Map;
      expect(icon.containsKey('size'), isFalse);
      expect(icon.containsKey('color'), isFalse);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('nothing is sent without it', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        app(
          CNPopupMenuButton(
            buttonLabel: 'Sort',
            items: items,
            onSelected: (_) {},
          ),
        ),
      );
      await settle(tester);
      final params = creationParams();
      expect(params.containsKey('checkedIcon'), isFalse);
      expect(params.containsKey('contentPadding'), isFalse);
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#169 contentPadding', () {
    testWidgets('is sent as directional insets', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        app(
          CNPopupMenuButton(
            buttonLabel: 'Sort',
            shrinkWrap: true,
            contentPadding: const EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4),
            items: items,
            onSelected: (_) {},
          ),
        ),
      );
      await settle(tester);
      expect(creationParams()['contentPadding'], {
        'top': 2.0,
        'leading': 1.0,
        'bottom': 4.0,
        'trailing': 3.0,
      });
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('a new padding creates the button again, measured again', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      final padding = ValueNotifier<EdgeInsetsDirectional?>(null);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<EdgeInsetsDirectional?>(
            valueListenable: padding,
            builder: (_, p, _) => CNPopupMenuButton(
              buttonLabel: 'Sort 169',
              shrinkWrap: true,
              contentPadding: p,
              items: items,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await settle(tester);
      expect(named('create'), hasLength(1));
      padding.value = EdgeInsetsDirectional.zero;
      await settle(tester);
      expect(named('create'), hasLength(2));
      expect(creationParams()['contentPadding'], {
        'top': 0.0,
        'leading': 0.0,
        'bottom': 0.0,
        'trailing': 0.0,
      });
      // Measured with the new insets, not from the old width's cache.
      expect(named('getIntrinsicSize'), hasLength(2));
      await tearDownView(tester);
    }, skip: skip);
  });
}
