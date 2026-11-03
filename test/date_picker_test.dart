import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channelPrefix = 'CupertinoNativeDatePicker_';

/// Rebuilds the picker with whatever [build] returns, so tests can change
/// its properties and feed values back the way an app does.
class _Host extends StatefulWidget {
  const _Host({super.key, required this.build, this.brightness});

  final Widget Function(_HostState state) build;
  final Brightness? brightness;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  DateTime value = DateTime(2026, 11, 3, 9, 41, 27);
  final changes = <DateTime>[];

  void set(DateTime v) => setState(() {
    value = v;
    changes.add(v);
  });

  void rebuild(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    theme: CupertinoThemeData(brightness: widget.brightness),
    home: Center(child: widget.build(this)),
  );
}

/// A widget test on the native iOS path, which needs native glass on the
/// test host. The platform override is cleared in the body, before the
/// framework checks that the test left it unset.
void nativeTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: !PlatformVersion.shouldUseNativeGlass);
}

void main() {
  group('CNDatePicker fallback', () {
    // Android, so the picker takes its Flutter fallback in the test host.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('the compact pill shows the date, Material formatted', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CNDatePicker(
                value: DateTime(2026, 11, 3, 9, 41),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Nov 3, 2026'), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);
    }, variant: android);

    testWidgets('date and time are two pills, Cupertino formatted', (
      tester,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNDatePicker(
              value: DateTime(2026, 11, 3, 21, 5),
              mode: CNDatePickerMode.dateAndTime,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('November 3, 2026'), findsOneWidget);
      expect(find.text('9:05 PM'), findsOneWidget);
    }, variant: android);

    testWidgets('a pill fits in a Row and opens a picker of its part', (
      tester,
    ) async {
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) => Row(
            children: [
              const Expanded(child: Text('When')),
              CNDatePicker(
                value: s.value,
                mode: CNDatePickerMode.dateAndTime,
                onChanged: s.set,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('9:41 AM'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.mode, CupertinoDatePickerMode.time);

      // The time pill keeps the day; seconds are cleared.
      picker.onDateTimeChanged(DateTime(2026, 11, 3, 14, 20));
      await tester.pump();
      expect(host.currentState!.changes.single, DateTime(2026, 11, 3, 14, 20));
      expect(find.text('2:20 PM'), findsOneWidget);
    }, variant: android);

    testWidgets('a disabled pill does not open', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNDatePicker(
              value: DateTime(2026, 11, 3),
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('November 3, 2026'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);
    }, variant: android);

    testWidgets('wheels and inline are wheels; year and month always is', (
      tester,
    ) async {
      for (final (mode, style, expected) in [
        (
          CNDatePickerMode.date,
          CNDatePickerStyle.wheels,
          CupertinoDatePickerMode.date,
        ),
        (
          CNDatePickerMode.dateAndTime,
          CNDatePickerStyle.inline,
          CupertinoDatePickerMode.dateAndTime,
        ),
        (
          CNDatePickerMode.yearAndMonth,
          CNDatePickerStyle.compact,
          CupertinoDatePickerMode.monthYear,
        ),
      ]) {
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: CNDatePicker(
                value: DateTime(2026, 11, 3),
                mode: mode,
                style: style,
                onChanged: (_) {},
              ),
            ),
          ),
        );
        final picker = tester.widget<CupertinoDatePicker>(
          find.byType(CupertinoDatePicker),
        );
        expect(picker.mode, expected, reason: '$mode / $style');
        expect(tester.getSize(find.byType(CupertinoDatePicker)).height, 216);
      }
    }, variant: android);

    testWidgets('date mode keeps the time of day of the value', (tester) async {
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) => CNDatePicker(
            value: s.value,
            style: CNDatePickerStyle.wheels,
            onChanged: s.set,
          ),
        ),
      );
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2026, 12, 25));
      expect(
        host.currentState!.changes.single,
        DateTime(2026, 12, 25, 9, 41, 27),
      );
    }, variant: android);

    testWidgets('a UTC value is shown and reported in UTC', (tester) async {
      DateTime? reported;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNDatePicker(
              value: DateTime.utc(2026, 11, 3, 23, 30),
              mode: CNDatePickerMode.dateAndTime,
              style: CNDatePickerStyle.wheels,
              onChanged: (v) => reported = v,
            ),
          ),
        ),
      );
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      // The wheels show the UTC wall clock, whatever the host's zone.
      expect(picker.initialDateTime, DateTime(2026, 11, 3, 23, 30));

      picker.onDateTimeChanged(DateTime(2026, 11, 4, 6, 15));
      expect(reported, DateTime.utc(2026, 11, 4, 6, 15));
      expect(reported!.isUtc, isTrue);
    }, variant: android);

    testWidgets('the start value is put inside the limits and on the step', (
      tester,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNDatePicker(
              value: DateTime(2026, 11, 3, 9, 41),
              mode: CNDatePickerMode.time,
              style: CNDatePickerStyle.wheels,
              minuteInterval: 15,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .initialDateTime,
        DateTime(2026, 11, 3, 9, 30),
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNDatePicker(
              key: UniqueKey(),
              value: DateTime(2026, 1, 1),
              style: CNDatePickerStyle.wheels,
              minimumDate: DateTime(2026, 11, 1),
              maximumDate: DateTime(2026, 11, 30),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .initialDateTime,
        DateTime(2026, 11, 1),
      );
    }, variant: android);

    testWidgets('an outside value change moves the wheels', (tester) async {
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) => CNDatePicker(
            value: s.value,
            style: CNDatePickerStyle.wheels,
            onChanged: s.set,
          ),
        ),
      );
      final first = tester.state(find.byType(CupertinoDatePicker));

      // A change the picker reported itself keeps its state.
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2026, 11, 4));
      await tester.pump();
      expect(tester.state(find.byType(CupertinoDatePicker)), same(first));

      host.currentState!.rebuild(
        () => host.currentState!.value = DateTime(2027, 3, 1),
      );
      await tester.pump();
      final moved = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(tester.state(find.byType(CupertinoDatePicker)), isNot(first));
      expect(moved.initialDateTime, DateTime(2027, 3, 1));
    }, variant: android);

    testWidgets('semanticLabel names the fallback', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNDatePicker(
              value: DateTime(2026, 11, 3),
              semanticLabel: 'Birthday',
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Birthday'), findsOneWidget);
      expect(
        find.semantics.byValue('November 3, 2026'),
        findsOneWidget,
        reason: 'the pill reads the value as a button',
      );
      semantics.dispose();
    }, variant: android);

    test('minuteInterval must divide 60', () {
      expect(
        () => CNDatePicker(
          value: DateTime(2026),
          minuteInterval: 7,
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
      expect(
        () => CNDatePicker(
          value: DateTime(2026),
          minuteInterval: 60,
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
      CNDatePicker(
        value: DateTime(2026),
        minuteInterval: 30,
        onChanged: (_) {},
      );
    });
  });

  group('CNDatePicker native', () {
    final created = <Map<Object?, Object?>>[];
    final ids = <int>[];
    final calls = <MethodCall>[];
    var intrinsic = <String, double>{'width': 120.0, 'height': 34.0};

    void mockNative(WidgetTester tester) {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          ids.add(args['id'] as int);
          final params = args['params'] as Uint8List;
          created.add(
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(params),
                )
                as Map<Object?, Object?>,
          );
        }
        return null;
      });
      for (var id = 0; id < 200; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('$_channelPrefix$id'),
          (call) async {
            calls.add(call);
            if (call.method == 'getIntrinsicSize') return intrinsic;
            return null;
          },
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (var id = 0; id < 200; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('$_channelPrefix$id'),
            null,
          );
        }
      });
    }

    /// A call from the native view to Dart.
    Future<void> fromNative(
      WidgetTester tester,
      String method,
      Object? args,
    ) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        '$_channelPrefix${ids.last}',
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
      await tester.pump();
    }

    List<MethodCall> sent(String method) =>
        calls.where((c) => c.method == method).toList();

    setUp(() {
      created.clear();
      ids.clear();
      calls.clear();
      intrinsic = {'width': 120.0, 'height': 34.0};
    });

    nativeTest('creation params carry the value as an instant', (tester) async {
      mockNative(tester);
      final value = DateTime.utc(2026, 11, 3, 12);
      await tester.pumpWidget(
        _Host(
          build: (_) => CNDatePicker(
            value: value,
            mode: CNDatePickerMode.dateAndTime,
            minimumDate: DateTime.utc(2026, 1, 1),
            maximumDate: DateTime.utc(2026, 12, 31),
            minuteInterval: 5,
            tint: const Color(0xFFFF2D55),
            locale: const Locale('de', 'DE'),
            semanticLabel: 'Meeting',
            onChanged: (_) {},
          ),
        ),
      );
      final p = created.single;
      expect(p['value'], value.millisecondsSinceEpoch);
      expect(p['utc'], isTrue);
      expect(p['mode'], 'dateAndTime');
      // `automatic` is resolved here, the way UIKit resolves it.
      expect(p['pickerStyle'], 'compact');
      expect(p['minimumDate'], DateTime.utc(2026).millisecondsSinceEpoch);
      expect(
        p['maximumDate'],
        DateTime.utc(2026, 12, 31).millisecondsSinceEpoch,
      );
      expect(p['minuteInterval'], 5);
      expect(p['enabled'], isTrue);
      expect(p['isDark'], isFalse);
      expect(p['locale'], 'de-DE');
      expect(p['semanticLabel'], 'Meeting');
      expect((p['style'] as Map)['tint'], 0xFFFF2D55);
    });

    nativeTest('year and month is always created as wheels', (tester) async {
      mockNative(tester);
      await tester.pumpWidget(
        _Host(
          build: (s) => CNDatePicker(
            value: s.value,
            mode: CNDatePickerMode.yearAndMonth,
            style: CNDatePickerStyle.inline,
            onChanged: s.set,
          ),
        ),
      );
      expect(created.single['pickerStyle'], 'wheels');
    });

    nativeTest('native values come back in the zone of the value', (
      tester,
    ) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      var mode = CNDatePickerMode.date;
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) =>
              CNDatePicker(value: s.value, mode: mode, onChanged: s.set),
        ),
      );
      final changes = host.currentState!.changes;

      // Date mode keeps the time of day of the value.
      await fromNative(tester, 'valueChanged', {
        'value': DateTime(2026, 12, 25, 18).millisecondsSinceEpoch,
      });
      expect(changes.last, DateTime(2026, 12, 25, 9, 41, 27));
      expect(changes.last.isUtc, isFalse);

      // Time mode keeps the day and clears the seconds.
      host.currentState!.rebuild(() => mode = CNDatePickerMode.time);
      await tester.pump();
      await fromNative(tester, 'valueChanged', {
        'value': DateTime(2030, 1, 1, 7, 15, 59).millisecondsSinceEpoch,
      });
      expect(changes.last, DateTime(2026, 12, 25, 7, 15));

      // Year and month reports the first day of the month.
      host.currentState!.rebuild(() => mode = CNDatePickerMode.yearAndMonth);
      await tester.pump();
      await fromNative(tester, 'valueChanged', {
        'value': DateTime(2027, 4, 17, 7, 15).millisecondsSinceEpoch,
      });
      expect(changes.last, DateTime(2027, 4));

      // A UTC value gets UTC values back.
      host.currentState!.rebuild(() {
        mode = CNDatePickerMode.dateAndTime;
        host.currentState!.value = DateTime.utc(2026, 11, 3);
      });
      await tester.pump();
      await fromNative(tester, 'valueChanged', {
        'value': DateTime.utc(2026, 11, 20, 15, 30, 12).millisecondsSinceEpoch,
      });
      expect(changes.last, DateTime.utc(2026, 11, 20, 15, 30));
      expect(changes.last.isUtc, isTrue);
    });

    nativeTest('a reported value is not sent back; an outside one is', (
      tester,
    ) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) => CNDatePicker(
            value: s.value,
            mode: CNDatePickerMode.dateAndTime,
            onChanged: s.set,
          ),
        ),
      );
      await fromNative(tester, 'valueChanged', {
        'value': DateTime(2026, 11, 4, 10).millisecondsSinceEpoch,
      });
      await tester.pump();
      expect(sent('setValue'), isEmpty);

      final outside = DateTime(2027, 2, 1, 8);
      host.currentState!.rebuild(() => host.currentState!.value = outside);
      await tester.pump();
      expect(sent('setValue').single.arguments, {
        'value': outside.millisecondsSinceEpoch,
        'utc': false,
        'animated': true,
      });

      host.currentState!.rebuild(() {});
      await tester.pump();
      expect(sent('setValue'), hasLength(1), reason: 'same value, no call');
    });

    nativeTest('the range is sent before the value', (tester) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      DateTime? min;
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) =>
              CNDatePicker(value: s.value, minimumDate: min, onChanged: s.set),
        ),
      );
      host.currentState!.rebuild(() {
        min = DateTime(2027);
        host.currentState!.value = DateTime(2027, 6, 1);
      });
      await tester.pump();
      final order = calls
          .map((c) => c.method)
          .where((m) => m == 'setRange' || m == 'setValue')
          .toList();
      expect(order, ['setRange', 'setValue']);
      expect(sent('setRange').single.arguments, {
        'minimumDate': DateTime(2027).millisecondsSinceEpoch,
        'maximumDate': null,
      });
    });

    nativeTest('the view takes the size the native picker reports', (
      tester,
    ) async {
      mockNative(tester);
      intrinsic = {'width': 131.0, 'height': 36.0};
      await tester.pumpWidget(
        _Host(
          build: (s) => Row(
            children: [
              const Expanded(child: Text('Date')),
              CNDatePicker(value: s.value, onChanged: s.set),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(sent('getIntrinsicSize'), hasLength(1));
      expect(tester.getSize(find.byType(UiKitView)), const Size(131, 36));

      // The pill widens with a longer date.
      await fromNative(tester, 'sizeChanged', {'width': 142.0, 'height': 36.0});
      expect(tester.getSize(find.byType(UiKitView)), const Size(142, 36));
    });

    nativeTest('an inline calendar fills the width; its height is reported', (
      tester,
    ) async {
      mockNative(tester);
      intrinsic = {'width': 320.0, 'height': 340.0};
      await tester.pumpWidget(
        _Host(
          build: (s) => SizedBox(
            width: 380,
            child: CNDatePicker(
              value: s.value,
              style: CNDatePickerStyle.inline,
              onChanged: s.set,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(UiKitView)), const Size(380, 340));

      // A month with six week rows.
      await fromNative(tester, 'sizeChanged', {
        'width': 320.0,
        'height': 384.0,
      });
      expect(tester.getSize(find.byType(UiKitView)), const Size(380, 384));
    });

    nativeTest('wheels in a Row take the width the native view reports', (
      tester,
    ) async {
      mockNative(tester);
      intrinsic = {'width': 300.0, 'height': 216.0};
      await tester.pumpWidget(
        _Host(
          build: (s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CNDatePicker(
                value: s.value,
                style: CNDatePickerStyle.wheels,
                onChanged: s.set,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(UiKitView)), const Size(300, 216));
    });

    nativeTest('a new style is a new native view', (tester) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      var style = CNDatePickerStyle.compact;
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) =>
              CNDatePicker(value: s.value, style: style, onChanged: s.set),
        ),
      );
      host.currentState!.rebuild(() => style = CNDatePickerStyle.wheels);
      await tester.pump();
      expect(created.map((p) => p['pickerStyle']), ['compact', 'wheels']);
    });

    nativeTest('year and month replaces a compact view without a setMode', (
      tester,
    ) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      var mode = CNDatePickerMode.date;
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) =>
              CNDatePicker(value: s.value, mode: mode, onChanged: s.set),
        ),
      );
      host.currentState!.rebuild(() => mode = CNDatePickerMode.yearAndMonth);
      await tester.pump();
      // UIKit allows year and month only as wheels, so the compact view is
      // replaced rather than switched.
      expect(created.map((p) => (p['pickerStyle'], p['mode'])), [
        ('compact', 'date'),
        ('wheels', 'yearAndMonth'),
      ]);
      expect(sent('setMode'), isEmpty);
    });

    nativeTest('property changes are sent once', (tester) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      var enabled = true;
      var label = 'One';
      var mode = CNDatePickerMode.date;
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) => CNDatePicker(
            value: s.value,
            enabled: enabled,
            semanticLabel: label,
            mode: mode,
            minuteInterval: mode == CNDatePickerMode.time ? 10 : 1,
            tint: mode == CNDatePickerMode.time
                ? const Color(0xFF34C759)
                : null,
            onChanged: s.set,
          ),
        ),
      );
      host.currentState!.rebuild(() {
        enabled = false;
        label = 'Two';
        mode = CNDatePickerMode.time;
      });
      await tester.pump();
      host.currentState!.rebuild(() {});
      await tester.pump();
      expect(sent('setEnabled').single.arguments, {'enabled': false});
      expect(sent('setSemanticLabel').single.arguments, {'label': 'Two'});
      expect(sent('setMode').single.arguments, {'mode': 'time'});
      expect(sent('setMinuteInterval').single.arguments, {
        'minuteInterval': 10,
      });
      expect(sent('setStyle').single.arguments, {'tint': 0xFF34C759});
    });

    nativeTest('a theme change sends setBrightness once', (tester) async {
      mockNative(tester);
      Widget app(Brightness b) => _Host(
        key: const ValueKey('host'),
        brightness: b,
        build: (s) => CNDatePicker(value: s.value, onChanged: s.set),
      );
      await tester.pumpWidget(app(Brightness.light));
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pumpAndSettle();
      expect(sent('setBrightness').map((c) => c.arguments), [
        {'isDark': true},
      ]);
    });

    nativeTest('a call to a destroyed view does not throw', (tester) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(
        _Host(
          key: host,
          build: (s) => CNDatePicker(value: s.value, onChanged: s.set),
        ),
      );
      // No handler: what a view hidden under a sheet answers.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('$_channelPrefix${ids.last}'),
        null,
      );
      host.currentState!.rebuild(
        () => host.currentState!.value = DateTime(2030),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
