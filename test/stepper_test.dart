import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a [CNStepper] whose value follows its own onChanged, like an app.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.initial = 5,
    this.max = 10,
    this.step = 1,
    this.wraps = false,
    this.autorepeat = true,
    this.enabled = true,
  });

  final double initial;
  final double max;
  final double step;
  final bool wraps;
  final bool autorepeat;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double value = widget.initial;
  double min = 0;
  late double max = widget.max;
  Color? color;
  Brightness brightness = Brightness.light;
  final changes = <double>[];

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    theme: CupertinoThemeData(brightness: brightness),
    home: Center(
      child: CNStepper(
        value: value,
        min: min,
        max: max,
        step: widget.step,
        wraps: widget.wraps,
        autorepeat: widget.autorepeat,
        enabled: widget.enabled,
        color: color,
        semanticLabel: 'Guests',
        onChanged: (v) {
          changes.add(v);
          setState(() => value = v);
        },
      ),
    ),
  );
}

void main() {
  group('CNStepper fallback', () {
    // The test host takes the Flutter fallback on Android.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    Finder half(bool plus) => find
        .descendant(
          of: find.byType(CNStepper),
          matching: find.byType(GestureDetector),
        )
        .at(plus ? 1 : 0);

    testWidgets('reads as one adjustable node with its label and value', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const _Host(initial: 1.5, step: 0.5));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Guests')),
        isSemantics(
          label: 'Guests',
          value: '1.5',
          increasedValue: '2.0',
          decreasedValue: '1.0',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      semantics.dispose();
    }, variant: android);

    testWidgets('the increase action steps the value', (tester) async {
      final semantics = tester.ensureSemantics();
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));

      tester.semantics.increase(find.semantics.byLabel('Guests'));
      await tester.pump();
      expect(key.currentState!.changes, [6]);
      semantics.dispose();
    }, variant: android);

    testWidgets('has no increase action at the maximum unless it wraps', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const _Host(initial: 10));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Guests')),
        isSemantics(
          label: 'Guests',
          hasIncreaseAction: false,
          hasDecreaseAction: true,
        ),
      );
      semantics.dispose();
    }, variant: android);

    testWidgets('+ at the maximum wraps to the minimum when wraps is set', (
      tester,
    ) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, initial: 10, wraps: true));

      await tester.tap(half(true));
      await tester.pump();
      expect(key.currentState!.changes, [0]);
    }, variant: android);

    testWidgets('− and + step by step, and stop at the limits', (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, initial: 1, step: 0.1, max: 2));

      await tester.tap(half(false));
      await tester.pump();
      await tester.tap(half(true));
      await tester.pump();
      await tester.tap(half(true));
      await tester.pump();
      // 1 - 0.1 + 0.1 + 0.1, without floating-point noise.
      expect(key.currentState!.changes, [0.9, 1.0, 1.1]);

      key.currentState!.update(() => key.currentState!.value = 2);
      await tester.pump();
      await tester.tap(half(true));
      await tester.pump();
      expect(key.currentState!.changes, [0.9, 1.0, 1.1]);
    }, variant: android);

    testWidgets('holding + repeats with autorepeat, once without', (
      tester,
    ) async {
      for (final autorepeat in [true, false]) {
        final key = GlobalKey<_HostState>();
        await tester.pumpWidget(
          _Host(key: key, initial: 0, max: 100, autorepeat: autorepeat),
        );
        final gesture = await tester.startGesture(tester.getCenter(half(true)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        await gesture.up();
        await tester.pump();
        if (autorepeat) {
          expect(key.currentState!.changes.length, greaterThan(3));
        } else {
          expect(key.currentState!.changes, [1]);
        }
        await tester.pumpWidget(const SizedBox());
      }
    }, variant: android);

    testWidgets('a disabled stepper ignores taps', (tester) async {
      final semantics = tester.ensureSemantics();
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, enabled: false));

      await tester.tap(half(true));
      await tester.pump();
      expect(key.currentState!.changes, isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Guests')),
        isSemantics(
          label: 'Guests',
          hasEnabledState: true,
          isEnabled: false,
          hasIncreaseAction: false,
          hasDecreaseAction: false,
        ),
      );
      semantics.dispose();
    }, variant: android);
  });

  group('CNStepper native', () {
    late List<MethodCall> calls;
    late int viewId;

    Future<GlobalKey<_HostState>> pumpNative(WidgetTester tester) async {
      calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          viewId = (call.arguments as Map)['id'] as int;
          calls.add(call);
        }
        return null;
      });
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeStepper_$id'),
          (call) async {
            calls.add(call);
            return null;
          },
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (var id = 0; id < 20; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('CupertinoNativeStepper_$id'),
            null,
          );
        }
      });
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      await tester.pumpAndSettle();
      return key;
    }

    Map<Object?, Object?> creationParams() {
      final create = calls.firstWhere((c) => c.method == 'create');
      final bytes = (create.arguments as Map)['params'] as Uint8List;
      return const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(bytes),
          )
          as Map<Object?, Object?>;
    }

    /// Removes the view and the platform override inside the test body, as
    /// the binding checks the override is unset when the body returns.
    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }

    List<MethodCall> sent() =>
        calls.where((c) => c.method != 'create').toList();

    testWidgets(
      'creates a fixed-size view with every option',
      (tester) async {
        await pumpNative(tester);
        expect(creationParams(), {
          'value': 5.0,
          'min': 0.0,
          'max': 10.0,
          'step': 1.0,
          'wraps': false,
          'autorepeat': true,
          'enabled': true,
          'semanticLabel': 'Guests',
          'isDark': false,
          'style': <Object?, Object?>{},
        });
        expect(tester.getSize(find.byType(UiKitView)), const Size(94, 32));
        expect(sent(), isEmpty, reason: 'nothing changed since creation');
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'sends the range before the value it clamps',
      (tester) async {
        final key = await pumpNative(tester);
        key.currentState!.update(() {
          key.currentState!
            ..min = 20
            ..max = 30
            ..value = 25;
        });
        await tester.pumpAndSettle();
        expect(sent().map((c) => c.method), ['setRange', 'setValue']);
        expect(sent().first.arguments, {'min': 20.0, 'max': 30.0});
        expect(sent().last.arguments, {'value': 25.0});
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'reports a native step without sending it back',
      (tester) async {
        final key = await pumpNative(tester);
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'CupertinoNativeStepper_$viewId',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('valueChanged', {'value': 6.0}),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
        expect(key.currentState!.changes, [6.0]);
        expect(sent(), isEmpty);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'follows the theme and clears a removed tint',
      (tester) async {
        final key = await pumpNative(tester);
        key.currentState!.update(
          () => key.currentState!.color = const Color(0xFFFF2D55),
        );
        await tester.pumpAndSettle();
        key.currentState!.update(() => key.currentState!.color = null);
        await tester.pumpAndSettle();
        key.currentState!.update(
          () => key.currentState!.brightness = Brightness.dark,
        );
        await tester.pumpAndSettle();
        expect(sent().map((c) => '${c.method} ${c.arguments}'), [
          'setStyle {tint: ${0xFFFF2D55}}',
          'setStyle {tint: null}',
          'setBrightness {isDark: true}',
        ]);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
