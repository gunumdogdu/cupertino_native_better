import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart side of #134 to #144. The native-path tests run on a macOS 26+
/// host with the target platform set to iOS.
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

  Map<Object?, Object?> creationParams([String? viewType]) {
    final create = calls.lastWhere(
      (c) =>
          c.method == 'create' &&
          (viewType == null || (c.arguments as Map)['viewType'] == viewType),
    );
    final bytes = (create.arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  int viewId([String? viewType]) =>
      ((calls
                      .lastWhere(
                        (c) =>
                            c.method == 'create' &&
                            (viewType == null ||
                                (c.arguments as Map)['viewType'] == viewType),
                      )
                      .arguments
                  as Map)['id']
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

  group('#139 PlatformVersion.debugForceFallbacks', () {
    testWidgets('forces the Flutter fallback on a macOS host', (tester) async {
      PlatformVersion.debugForceFallbacks = true;
      addTearDown(PlatformVersion.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                items: const [
                  CNTabBarItem(label: 'One', icon: CNSymbol('1.circle')),
                  CNTabBarItem(label: 'Two', icon: CNSymbol('2.circle')),
                ],
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(PlatformVersion.shouldUseNativeControls, isFalse);
      expect(PlatformVersion.shouldUseNativeGlass, isFalse);
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      await tearDownView(tester);
    });

    test('reset turns it off', () {
      PlatformVersion.debugForceFallbacks = true;
      PlatformVersion.reset();
      expect(PlatformVersion.debugForceFallbacks, isFalse);
    });
  });

  group('#137 CNSlider', () {
    testWidgets(
      'a repeated value is not reported, and start/end reach the callbacks',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester, 'CupertinoNativeSlider');
        final changes = <double>[];
        final starts = <double>[];
        final ends = <double>[];
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: CNSlider(
                value: 0.2,
                seekOnTap: true,
                onChanged: changes.add,
                onChangeStart: starts.add,
                onChangeEnd: ends.add,
              ),
            ),
          ),
        );
        await settle(tester);
        expect(creationParams()['seekOnTap'], isTrue);
        final channel = 'CupertinoNativeSlider_${viewId()}';
        await fromNative(tester, channel, 'changeStart', {'value': 0.2});
        await fromNative(tester, channel, 'valueChanged', {'value': 0.8});
        // UIKit's `.valueChanged` at the end of a touch that didn't move.
        await fromNative(tester, channel, 'valueChanged', {'value': 0.8});
        await fromNative(tester, channel, 'changeEnd', {'value': 0.8});
        expect(starts, [0.2]);
        expect(changes, [0.8]);
        expect(ends, [0.8]);
        // The value the slider was created with is not a change either.
        await tearDownView(tester);
      },
      skip: skip,
    );
  });

  group('#136 CNTabBar height', () {
    testWidgets('measures itself again when height goes back to null', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(
        tester,
        'CupertinoNativeTabBar',
        reply: (call) => call.method == 'getIntrinsicSize'
            ? {'width': 300.0, 'height': 97.0}
            : null,
      );
      final height = ValueNotifier<double?>(60);
      await tester.pumpWidget(
        CupertinoApp(
          navigatorObservers: [CNTabBarRouteObserver()],
          home: ValueListenableBuilder<double?>(
            valueListenable: height,
            builder: (_, h, _) => Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                height: h,
                items: const [
                  CNTabBarItem(label: 'Inbox', icon: CNSymbol('tray')),
                  CNTabBarItem(label: 'Archive', icon: CNSymbol('archivebox')),
                ],
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      final before = named('getIntrinsicSize').length;
      height.value = null;
      await settle(tester);
      expect(named('getIntrinsicSize').length, greaterThan(before));
      expect(
        tester.getSize(find.byType(CNTabBar)).height,
        97.0,
        reason: 'the measured height, not the 50 pt fallback',
      );
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#134 CNSearchBar', () {
    testWidgets('keyboard options and the clear label are sent', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNSearchBar');
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: CNSearchBar(
              expandable: false,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.words,
              searchIcon: CNSymbol('magnifyingglass', size: 22),
              clearButtonSemanticLabel: 'Clear text',
            ),
          ),
        ),
      );
      await settle(tester);
      final params = creationParams();
      expect(params['autocorrect'], isFalse);
      expect(params['textCapitalization'], 'words');
      expect(params['keyboardType'], 'TextInputType.emailAddress');
      expect(params['searchIconSize'], 22.0);
      expect(params['clearButtonLabel'], 'Clear text');
      expect(params['expanded'], isTrue);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('a view created again starts with the text and expansion', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNSearchBar');
      final autocorrect = ValueNotifier(true);
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: autocorrect,
              builder: (_, a, _) => CNSearchBar(autocorrect: a),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(creationParams()['expanded'], isFalse);
      final channel = 'CNSearchBar_${viewId()}';
      await fromNative(tester, channel, 'expanded', null);
      await fromNative(tester, channel, 'textChanged', {'text': 'kite'});
      await settle(tester);
      // A new keyboard option creates the native view again.
      autocorrect.value = false;
      await settle(tester);
      final params = creationParams();
      expect(params['text'], 'kite');
      expect(params['expanded'], isTrue);
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#135 CNPopover', () {
    test('gauges are encoded as fractions of the bar', () {
      final c = debugEncodePopoverContent(
        const CNPopoverContent(
          gauges: [
            CNPopoverGauge(
              label: 'Storage',
              value: 42,
              max: 128,
              valueText: '42 GB',
            ),
            CNPopoverGauge(label: 'Over', value: 2),
          ],
        ),
      );
      final gauges = c['gauges']! as List;
      expect((gauges[0] as Map)['fraction'], closeTo(42 / 128, 1e-9));
      expect((gauges[0] as Map)['valueText'], '42 GB');
      expect((gauges[1] as Map)['fraction'], 1.0);
      expect(
        debugEncodePopoverContent(const CNPopoverContent(title: 'x')),
        isNot(contains('gauges')),
      );
    });

    testWidgets('a failure throws only with throwOnFailure', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('cn_popover'), (
        call,
      ) async {
        if (call.method == 'show') {
          throw PlatformException(code: 'refused');
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('cn_popover'),
          null,
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      const content = CNPopoverContent(title: 'Hi');
      expect(await CNPopover.show(context: context, content: content), isNull);
      await expectLater(
        CNPopover.show(
          context: context,
          content: content,
          throwOnFailure: true,
        ),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'refused'),
        ),
      );
      debugDefaultTargetPlatformOverride = null;
    }, skip: skip);
  });

  group('#144 CNAlert / CNActionSheet', () {
    test('the payloads carry the text style and the direction', () {
      final alert = debugBuildAlertPayload(
        actions: const [CNAlertAction(label: 'OK')],
        textStyle: const {'fontFamily': 'Tajawal'},
        rtl: true,
      );
      expect(alert['textStyle'], {'fontFamily': 'Tajawal'});
      expect(alert['rtl'], isTrue);
      final plain = debugBuildAlertPayload(
        actions: const [CNAlertAction(label: 'OK')],
      );
      expect(plain.containsKey('textStyle'), isFalse);
      expect(plain.containsKey('rtl'), isFalse);
      final sheet = debugBuildActionSheetPayload(
        actions: const [CNActionSheetAction(label: 'Share')],
        textStyle: const {'fontFamily': 'Tajawal'},
        rtl: false,
      );
      expect(sheet['textStyle'], {'fontFamily': 'Tajawal'});
      expect(sheet['rtl'], isFalse);
    });

    testWidgets('show sends the family, part styles and ambient direction', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final sent = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('cn_alert'), (
        call,
      ) async {
        sent.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('cn_alert'),
          null,
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        CupertinoApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await CNAlert.show<void>(
        context: context,
        title: 'T',
        fontFamily: 'Tajawal',
        titleStyle: const CNDialogTextStyle(fontWeight: FontWeight.w800),
        actions: const [CNAlertAction(label: 'OK')],
      );
      final args = sent.single.arguments as Map;
      expect(args['rtl'], isTrue);
      final style = args['textStyle'] as Map;
      expect(style['fontFamily'], 'Tajawal');
      expect((style['title'] as Map)['fontWeight'], 800);
      debugDefaultTargetPlatformOverride = null;
    }, skip: skip);
  });

  group('#143 CNSegmentedControl', () {
    testWidgets('new labels and a new label style reach the control', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(
        tester,
        'CupertinoNativeSegmentedControl',
        reply: (call) => call.method == 'getIntrinsicSize'
            ? {'width': 200.0, 'height': 32.0}
            : null,
      );
      final arabic = ValueNotifier(false);
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: arabic,
              builder: (_, a, _) => Directionality(
                textDirection: a ? TextDirection.rtl : TextDirection.ltr,
                child: CNSegmentedControl(
                  labels: a ? const ['الكل', 'مقروء'] : const ['All', 'Read'],
                  selectedIndex: 1,
                  onValueChanged: (_) {},
                  labelFontFamily: 'Tajawal',
                  selectedLabelFontWeight: a
                      ? FontWeight.w800
                      : FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      final params = creationParams();
      expect((params['labelStyle'] as Map)['fontFamily'], 'Tajawal');
      expect(params['rtl'], isFalse);
      calls.clear();
      arabic.value = true;
      await settle(tester);
      final setItems = named('setItems').single.arguments as Map;
      expect(setItems['labels'], ['الكل', 'مقروء']);
      expect(setItems['selectedIndex'], 1);
      expect(
        (named('setLabelStyle').single.arguments as Map)['selectedFontWeight'],
        800,
      );
      expect(
        (named('setLayoutDirection').single.arguments as Map)['rtl'],
        true,
      );
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#142 CNTabBar weights and direction', () {
    testWidgets('weights and rtl are sent at creation', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(
        tester,
        'CupertinoNativeTabBar',
        reply: (call) => call.method == 'getIntrinsicSize'
            ? {'width': 300.0, 'height': 63.0}
            : null,
      );
      await tester.pumpWidget(
        CupertinoApp(
          navigatorObservers: [CNTabBarRouteObserver()],
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                labelFontFamily: 'Tajawal',
                labelFontWeight: FontWeight.w500,
                selectedLabelFontWeight: FontWeight.w700,
                items: const [
                  CNTabBarItem(label: 'One', icon: CNSymbol('1.circle')),
                  CNTabBarItem(label: 'Two', icon: CNSymbol('2.circle')),
                ],
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      final params = creationParams();
      expect(params['labelFontWeight'], 500);
      expect(params['selectedLabelFontWeight'], 700);
      expect(params['rtl'], isTrue);
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#141 CNPopupMenuButton', () {
    testWidgets('a label with an icon, and the open/close callbacks', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(
        tester,
        'CupertinoNativePopupMenuButton',
        reply: (call) => call.method == 'getIntrinsicSize'
            ? {'width': 80.0, 'height': 32.0}
            : null,
      );
      var opened = 0;
      var closed = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNPopupMenuButton(
              buttonLabel: 'Sort',
              buttonIcon: const CNSymbol('chevron.down'),
              imagePlacement: CNImagePlacement.trailing,
              labelFontFamily: 'Tajawal',
              labelFontWeight: FontWeight.w700,
              keepsSourceVisible: true,
              shrinkWrap: true,
              items: const [CNPopupMenuItem(label: 'Name')],
              onSelected: (_) {},
              onOpened: () => opened++,
              onClosed: () => closed++,
            ),
          ),
        ),
      );
      await settle(tester);
      final params = creationParams();
      expect(params['buttonTitle'], 'Sort');
      expect(params['buttonIconName'], 'chevron.down');
      expect(params['imagePlacement'], 'trailing');
      expect(params['labelFontFamily'], 'Tajawal');
      expect(params['labelFontWeight'], 700);
      expect(params['keepsSourceVisible'], isTrue);
      expect(params.containsKey('round'), isFalse);
      expect(
        params.containsKey('buttonIconSize'),
        isFalse,
        reason: 'a default-size symbol takes the label size',
      );
      final channel = 'CupertinoNativePopupMenuButton_${viewId()}';
      await fromNative(tester, channel, 'menuOpened', null);
      await fromNative(tester, channel, 'menuClosed', null);
      expect(opened, 1);
      expect(closed, 1);
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#138 CNContextMenu preview', () {
    testWidgets('showsPreview lays a native view over the child', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNContextMenuPreview');
      final chosen = <List<int>>[];
      var taps = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNContextMenu(
              showsPreview: true,
              previewCornerRadius: 16,
              items: const [CNPopupMenuItem(label: 'Copy')],
              onSelected: chosen.add,
              child: GestureDetector(
                onTap: () => taps++,
                child: const SizedBox(
                  width: 200,
                  height: 100,
                  child: ColoredBox(color: Color(0xFF5856D6)),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(UiKitView), findsOneWidget);
      expect(creationParams()['cornerRadius'], 16.0);
      expect(named('setMenu'), hasLength(1));
      // The child under the native view still gets a tap.
      await tester.tap(find.byType(GestureDetector).last);
      expect(taps, 1);
      await fromNative(tester, 'CNContextMenuPreview_${viewId()}', 'selected', {
        'path': [0],
      });
      expect(chosen, [
        [0],
      ]);
      await tearDownView(tester);
    }, skip: skip);
  });
}
