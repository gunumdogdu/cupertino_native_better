import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/reusable_platform_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'native_view_finder.dart';

/// #166: a `CNPopupMenuButton` mounted again (a header swapped for a
/// loading placeholder and back) shows in its first frame.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  void listen(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    for (var id = 0; id < 40; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativePopupMenuButton_$id'),
        (call) async {
          calls.add(call);
          // Each title measures 10 pt per character.
          if (call.method == 'measureTitle') {
            final title = (call.arguments as Map)['title'] as String;
            return {'width': title.length * 10.0, 'height': 24.0};
          }
          if (call.method == 'getIntrinsicSize') {
            return {'width': 60.0, 'height': 24.0};
          }
          return null;
        },
      );
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativePopupMenuButton_$id'),
          null,
        );
      }
    });
  }

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

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

  const labels = ['Newest', 'Price: low to high', 'Price: high to low'];

  Widget host(
    ValueListenable<String> label,
    ValueListenable<bool> shown, {
    CNButtonStyle style = CNButtonStyle.plain,
    List<String> labels = labels,
  }) {
    return CupertinoApp(
      home: Center(
        child: ValueListenableBuilder<bool>(
          valueListenable: shown,
          builder: (_, s, _) => !s
              ? const SizedBox(height: 32)
              : ValueListenableBuilder<String>(
                  valueListenable: label,
                  builder: (_, l, _) => CNPopupMenuButton(
                    buttonLabel: l,
                    shrinkWrap: true,
                    buttonStyle: style,
                    items: [
                      for (final x in labels)
                        CNPopupMenuItem(label: x, checked: x == l),
                    ],
                    onSelected: (_) {},
                  ),
                ),
        ),
      ),
    );
  }

  double width(WidgetTester tester) => tester.getSize(findNativeView()).width;

  testWidgets(
    'the native view is created in the first frame, with no placeholder '
    'frame before it',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        host(ValueNotifier('Newest'), ValueNotifier(true)),
      );
      expect(named('create'), hasLength(1));
      await tearDownView(tester);
    },
    skip: skip,
  );

  testWidgets("the menu's item labels are measured as button titles once it is "
      'created', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    listen(tester);
    // Labels no other test measured: the widths are cached app-wide.
    await tester.pumpWidget(
      host(
        ValueNotifier('Name 166'),
        ValueNotifier(true),
        labels: const ['Name 166', 'Distance 166', 'Rating 166'],
      ),
    );
    await settle(tester);
    expect(
      named('measureTitle').map((c) => (c.arguments as Map)['title']),
      containsAll(['Distance 166', 'Rating 166']),
    );
    await tearDownView(tester);
  }, skip: skip);

  testWidgets(
    'mounted again with a new label, the kept view is shown in the first '
    'frame at the new width, with the new label and menu',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      final label = ValueNotifier('Newest');
      final shown = ValueNotifier(true);
      await tester.pumpWidget(host(label, shown));
      await settle(tester);

      // The reload: the header goes, the sort changes, the header is back.
      shown.value = false;
      label.value = 'Price: low to high';
      await settle(tester);
      expect(ReusablePlatformViews.debugParkedCount, 1);
      calls.clear();

      shown.value = true;
      await tester.pump();
      expect(named('create'), isEmpty, reason: 'the kept view is reused');
      expect(named('dispose'), isEmpty);
      expect(width(tester), 180.0, reason: 'the measured width, first frame');
      final set = named('setButtonTitle').single.arguments as Map;
      expect(set['title'], 'Price: low to high');
      expect(set['atWidth'], 180.0);
      expect(named('reveal'), hasLength(1));
      final items = named('setItems').first.arguments as Map;
      expect(items['checked'], [false, true, false]);
      expect(ReusablePlatformViews.debugParkedCount, 0);
      await tearDownView(tester);
    },
    skip: skip,
  );

  testWidgets(
    'a kept view goes after keepAlive, at the end of the next frame',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      var now = Duration.zero;
      ReusablePlatformViews.debugNow = () => now;
      final shown = ValueNotifier(true);
      await tester.pumpWidget(host(ValueNotifier('Newest'), shown));
      await settle(tester);
      shown.value = false;
      await tester.pump();
      expect(ReusablePlatformViews.debugParkedCount, 1);
      calls.clear();

      // Swept at the end of a frame.
      now = const Duration(seconds: 4);
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(ReusablePlatformViews.debugParkedCount, 1);
      now = const Duration(seconds: 6);
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(ReusablePlatformViews.debugParkedCount, 0);
      expect(named('dispose'), hasLength(1));
      await tearDownView(tester);
    },
    skip: skip,
  );

  testWidgets('a button with another configuration creates its own view', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    listen(tester);
    final shown = ValueNotifier(true);
    await tester.pumpWidget(host(ValueNotifier('Newest'), shown));
    await settle(tester);
    shown.value = false;
    await settle(tester);
    calls.clear();

    await tester.pumpWidget(
      host(
        ValueNotifier('Newest'),
        ValueNotifier(true),
        style: CNButtonStyle.gray,
      ),
    );
    expect(named('create'), hasLength(1));
    expect(ReusablePlatformViews.debugParkedCount, 1);
    await tearDownView(tester);
  }, skip: skip);

  testWidgets(
    'a label never measured gets a new view, hidden until it is sized',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      final label = ValueNotifier('Newest');
      final shown = ValueNotifier(true);
      await tester.pumpWidget(host(label, shown));
      await settle(tester);
      shown.value = false;
      label.value = 'Never seen 166';
      await settle(tester);
      calls.clear();

      shown.value = true;
      await tester.pump();
      final create = named('create').single;
      final bytes = (create.arguments as Map)['params'] as Uint8List;
      final params =
          const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(bytes),
              )
              as Map;
      expect(params['hiddenUntilSized'], isTrue);
      await tearDownView(tester);
    },
    skip: skip,
  );

  testWidgets('with keepAlive zero, a disposed view is disposed of at once', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    listen(tester);
    ReusablePlatformViews.keepAlive = Duration.zero;
    final shown = ValueNotifier(true);
    await tester.pumpWidget(host(ValueNotifier('Newest'), shown));
    await settle(tester);
    calls.clear();
    shown.value = false;
    await tester.pump();
    expect(named('dispose'), hasLength(1));
    expect(ReusablePlatformViews.debugParkedCount, 0);
    await tearDownView(tester);
  }, skip: skip);
}
