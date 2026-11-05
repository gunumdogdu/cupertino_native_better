import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a [CNGauge] whose options a test can change.
class _Host extends StatefulWidget {
  const _Host({super.key, this.refuse});

  /// A rating the parent does not accept.
  final double? refuse;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double value = 40;
  CNGaugeStyle style = CNGaugeStyle.capacity;
  double max = 100;
  double? warning = 75;
  double? critical = 90;
  Color? tint;
  bool editable = false;
  final List<double> changes = [];

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CNGauge(
            value: value,
            max: max,
            style: style,
            warningValue: warning,
            criticalValue: critical,
            tint: tint,
            label: 'Storage',
            currentValueLabel: style == CNGaugeStyle.rating
                ? null
                : '${value.round()} GB',
            onChanged: editable
                ? (v) {
                    changes.add(v);
                    if (v != widget.refuse) setState(() => value = v);
                  }
                : null,
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('CNGauge fallback', () {
    // The test host takes the Flutter fallback on Android.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('reads its label and current value label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const _Host());
      expect(
        tester.getSemantics(find.byType(CNGauge)),
        matchesSemantics(label: 'Storage', value: '40 GB'),
      );
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('40 GB'), findsOneWidget);
      semantics.dispose();
    }, variant: android);

    testWidgets('without a value label it reads the percentage', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(child: CNGauge(value: 0.25, semanticLabel: 'Upload')),
        ),
      );
      expect(
        tester.getSemantics(find.byType(CNGauge)),
        matchesSemantics(label: 'Upload', value: '25%'),
      );
      semantics.dispose();
    }, variant: android);

    testWidgets('an editable rating takes taps and is adjustable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final host = key.currentState!;
      host.update(() {
        host.style = CNGaugeStyle.rating;
        host.max = 5;
        host.value = 2;
        host.editable = true;
      });
      await tester.pump();
      expect(find.byIcon(CupertinoIcons.star_fill), findsNWidgets(2));
      expect(find.byIcon(CupertinoIcons.star), findsNWidgets(3));
      expect(
        tester.getSemantics(find.byType(CNGauge)),
        matchesSemantics(
          label: 'Storage',
          value: '2 of 5',
          increasedValue: '3',
          decreasedValue: '1',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      // The fourth star.
      final stars = tester.getRect(find.byType(Row).last);
      await tester.tapAt(
        Offset(stars.left + stars.width * 0.7, stars.center.dy),
      );
      await tester.pump();
      expect(host.changes, [4]);
      expect(find.byIcon(CupertinoIcons.star_fill), findsNWidgets(4));
      semantics.dispose();
    }, variant: android);
  });

  group('CNGauge native', () {
    late List<MethodCall> calls;
    late MethodChannel channel;

    Future<GlobalKey<_HostState>> pumpNative(
      WidgetTester tester,
      TargetPlatform platform, {
      double? refuse,
      Map<String, double>? reportedSize,
    }) async {
      calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = platform;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') calls.add(call);
        return null;
      });
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeGauge_$id'),
          (call) async {
            calls.add(call);
            if (call.method == 'getIntrinsicSize') {
              return reportedSize ?? {'width': 300.0, 'height': 54.0};
            }
            return null;
          },
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (var id = 0; id < 20; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('CupertinoNativeGauge_$id'),
            null,
          );
        }
      });
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, refuse: refuse));
      await tester.pumpAndSettle();
      final create = calls.lastWhere((c) => c.method == 'create');
      final id = (create.arguments as Map)['id'] as int;
      channel = MethodChannel('CupertinoNativeGauge_$id');
      return key;
    }

    Map<Object?, Object?> creationParams() {
      final create = calls.lastWhere((c) => c.method == 'create');
      final bytes = (create.arguments as Map)['params'] as Uint8List;
      return const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(bytes),
          )
          as Map<Object?, Object?>;
    }

    List<MethodCall> sent() => calls
        .where((c) => c.method != 'create' && c.method != 'getIntrinsicSize')
        .toList();

    Future<void> fromNative(
      WidgetTester tester,
      String method,
      Object? args,
    ) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    Size viewSize(WidgetTester tester) => tester.getSize(
      find.byWidgetPredicate((w) => w is AppKitView || w is UiKitView),
    );

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets(
      'macOS: every option sent; as wide as the parent, as high as reported',
      (tester) async {
        await pumpNative(tester, TargetPlatform.macOS);
        expect(find.byType(AppKitView), findsOneWidget);
        expect(creationParams(), {
          'style': 'capacity',
          'min': 0.0,
          'max': 100.0,
          'warningValue': 75.0,
          'criticalValue': 90.0,
          'tint': null,
          'warningColor': null,
          'criticalColor': null,
          'label': 'Storage',
          'currentValueLabel': '40 GB',
          'minimumValueLabel': null,
          'maximumValueLabel': null,
          'tickMarkCount': 0,
          'majorTickMarkCount': 0,
          'tickMarkPosition': 'below',
          'editable': false,
          'semanticLabel': 'Storage',
          'semanticValue': '40 GB',
          'value': 40.0,
          'isDark': false,
        });
        final parent = tester.getSize(find.byType(Column)).width;
        expect(viewSize(tester), Size(parent, 54));
        // A gauge that only shows a value lets clicks through.
        expect(
          tester.widget<AppKitView>(find.byType(AppKitView)).hitTestBehavior,
          PlatformViewHitTestBehavior.transparent,
        );
        expect(sent(), isEmpty, reason: 'nothing changed since creation');
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: a new value alone is setValue; other changes setConfig',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.macOS);
        final host = key.currentState!;
        host.update(() => host.value = 150);
        await tester.pumpAndSettle();
        host.update(() => host.tint = const Color(0xFF5856D6));
        await tester.pumpAndSettle();
        final s = sent();
        // The value label changes with the value, so the first update is a
        // config with the value clamped to max.
        expect(s.first.method, 'setConfig');
        expect((s.first.arguments as Map)['value'], 100.0);
        expect((s.first.arguments as Map)['currentValueLabel'], '150 GB');
        expect((s.last.arguments as Map)['tint'], 0xFF5856D6);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: the value without a label change is a bare setValue',
      (tester) async {
        calls = [];
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.method == 'create') calls.add(call);
          return null;
        });
        for (var id = 0; id < 20; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('CupertinoNativeGauge_$id'),
            (call) async {
              calls.add(call);
              return null;
            },
          );
        }
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          for (var id = 0; id < 20; id++) {
            messenger.setMockMethodCallHandler(
              MethodChannel('CupertinoNativeGauge_$id'),
              null,
            );
          }
        });
        Widget gauge(double v) => CupertinoApp(
          home: Center(
            child: CNGauge(
              value: v,
              currentValueLabel: 'Level',
              semanticLabel: 'Level',
            ),
          ),
        );
        await tester.pumpWidget(gauge(0.2));
        await tester.pumpAndSettle();
        await tester.pumpWidget(gauge(0.6));
        await tester.pumpAndSettle();
        expect(sent().map((c) => '${c.method} ${c.arguments}'), [
          'setValue {value: 0.6, animated: true}',
        ]);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: an editable rating takes clicks, reports, and goes back',
      (tester) async {
        final key = await pumpNative(
          tester,
          TargetPlatform.macOS,
          refuse: 1,
          reportedSize: {'width': 60.0, 'height': 30.0},
        );
        final host = key.currentState!;
        host.update(() {
          host.style = CNGaugeStyle.rating;
          host.max = 5;
          host.value = 3;
          host.warning = null;
          host.critical = null;
          host.editable = true;
        });
        await tester.pumpAndSettle();
        expect(
          tester.widget<AppKitView>(find.byType(AppKitView)).hitTestBehavior,
          PlatformViewHitTestBehavior.opaque,
        );
        final config = sent().last.arguments as Map;
        expect(config['style'], 'rating');
        expect(config['editable'], true);
        expect(config['semanticValue'], '3 of 5');
        calls.clear();
        await fromNative(tester, 'valueChanged', {'value': 4.0});
        expect(host.changes, [4]);
        expect(host.value, 4);
        // Only the value text changes with it.
        expect(sent().map((c) => c.method), ['setConfig']);
        calls.clear();
        await fromNative(tester, 'valueChanged', {'value': 1.0});
        expect(host.changes, [4, 1]);
        expect(host.value, 4);
        expect(sent().map((c) => (c.arguments as Map)['value']), [4.0]);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: rings take the size the native view reports',
      (tester) async {
        final key = await pumpNative(
          tester,
          TargetPlatform.macOS,
          reportedSize: {'width': 58.0, 'height': 58.0},
        );
        key.currentState!.update(
          () => key.currentState!.style = CNGaugeStyle.circularCapacity,
        );
        await tester.pumpAndSettle();
        await fromNative(tester, 'sizeChanged', {
          'width': 58.0,
          'height': 58.0,
        });
        expect(viewSize(tester), const Size(58, 58));
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'iOS: a gauge lets touches through; an editable rating takes taps '
      'and horizontal drags',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.iOS);
        var view = tester.widget<UiKitView>(find.byType(UiKitView));
        expect(view.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
        expect(view.gestureRecognizers, isNull);
        final host = key.currentState!;
        host.update(() {
          host.style = CNGaugeStyle.rating;
          host.max = 5;
          host.value = 3;
          host.editable = true;
        });
        await tester.pumpAndSettle();
        view = tester.widget<UiKitView>(find.byType(UiKitView));
        expect(view.hitTestBehavior, PlatformViewHitTestBehavior.opaque);
        final recognizers = view.gestureRecognizers!
            .map((f) => f.constructor())
            .toList();
        expect(recognizers.whereType<TapGestureRecognizer>(), hasLength(1));
        expect(
          recognizers.whereType<HorizontalDragGestureRecognizer>(),
          hasLength(1),
        );
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });

  group('CNGauge in a vertical list (iOS)', () {
    late List<MethodCall> gestures;
    late int rowTaps;

    Future<void> pumpList(WidgetTester tester, {required bool rating}) async {
      gestures = [];
      rowTaps = 0;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'acceptGesture' || call.method == 'rejectGesture') {
          gestures.add(call);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: ListView(
            children: [
              for (var i = 0; i < 30; i++)
                // A tappable row, as CupertinoListTile is: it takes taps on
                // its whole area.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => rowTaps++,
                  child: SizedBox(
                    height: 60,
                    child: Center(
                      child: rating
                          ? CNGauge(
                              value: 2,
                              max: 5,
                              style: CNGaugeStyle.rating,
                              onChanged: (_) {},
                            )
                          : const SizedBox(
                              width: 200,
                              child: CNGauge(value: 0.5),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Offset gaugeCenter(WidgetTester tester) =>
        tester.getCenter(find.byType(UiKitView).first);

    double scrollOffset(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets(
      'a tap on a gauge reaches the row; a drag scrolls',
      (tester) async {
        await pumpList(tester, rating: false);
        await tester.tapAt(gaugeCenter(tester));
        await tester.pump();
        expect(rowTaps, 1);
        await tester.dragFrom(gaugeCenter(tester), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(scrollOffset(tester), greaterThan(100));
        // The engine is only ever told to keep touches from the gauge.
        expect(
          gestures.map((c) => c.method),
          everyElement('rejectGesture'),
          reason: 'the gauge never takes a touch',
        );
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'an editable rating takes a horizontal drag; a vertical one scrolls',
      (tester) async {
        await pumpList(tester, rating: true);
        await tester.dragFrom(gaugeCenter(tester), const Offset(40, 0));
        await tester.pumpAndSettle();
        expect(gestures.map((c) => c.method), ['acceptGesture']);
        expect(scrollOffset(tester), 0);
        gestures.clear();
        await tester.dragFrom(gaugeCenter(tester), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(gestures.map((c) => c.method), ['rejectGesture']);
        expect(scrollOffset(tester), greaterThan(100));
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
