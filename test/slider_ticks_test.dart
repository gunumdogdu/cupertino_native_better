import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material, Slider;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({super.key, required this.initial});

  final CNSlider initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late CNSlider slider = widget.initial;

  void show(CNSlider next) => setState(() => slider = next);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    theme: const CupertinoThemeData(primaryColor: Color(0xFF0000FF)),
    home: Center(child: slider),
  );
}

void main() {
  test('numberOfTicks and tickValues cannot be combined', () {
    expect(
      () => CNSlider(
        value: 0,
        onChanged: (_) {},
        numberOfTicks: 3,
        tickValues: const [0, 1],
      ),
      throwsAssertionError,
    );
    expect(
      () => CNSlider(value: 0, onChanged: (_) {}, numberOfTicks: 1),
      throwsAssertionError,
    );
  });

  group('CNSlider iOS 26 options on the channel', () {
    final created = <Map<Object?, Object?>>[];
    final calls = <MethodCall>[];

    void mockNative(WidgetTester tester) {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final params = (call.arguments as Map)['params'] as Uint8List;
          created.add(
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(params),
                )
                as Map<Object?, Object?>,
          );
        }
        return null;
      });
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeSlider_$id'),
          (call) async {
            calls.add(call);
            return null;
          },
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (var id = 0; id < 40; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('CupertinoNativeSlider_$id'),
            null,
          );
        }
      });
    }

    Future<GlobalKey<_HostState>> pumpHost(
      WidgetTester tester,
      CNSlider slider,
    ) async {
      created.clear();
      calls.clear();
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: host, initial: slider));
      await tester.pumpAndSettle();
      return host;
    }

    Future<List<MethodCall>> show(
      WidgetTester tester,
      GlobalKey<_HostState> host,
      CNSlider slider,
    ) async {
      calls.clear();
      host.currentState!.show(slider);
      await tester.pumpAndSettle();
      return [
        for (final c in calls)
          if (c.method == 'setTrackConfiguration' ||
              c.method == 'setSliderStyle')
            c,
      ];
    }

    void noop(double _) {}

    testWidgets(
      'creation params are unchanged when no option is used',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await pumpHost(
          tester,
          CNSlider(value: 0.5, onChanged: noop, step: 0.1),
        );
        expect(created.single, {
          'min': 0.0,
          'max': 1.0,
          'value': 0.5,
          'enabled': true,
          'isDark': false,
          'style': {'trackTint': 0xFF0000FF},
          'step': 0.1,
        });
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'creation params carry the style, ticks and neutral value',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await pumpHost(
          tester,
          CNSlider(
            value: 0,
            min: -10,
            max: 10,
            onChanged: noop,
            style: CNSliderStyle.thumbless,
            numberOfTicks: 5,
            neutralValue: 0,
          ),
        );
        final params = created.single;
        expect(params['sliderStyle'], 'thumbless');
        expect(params['numberOfTicks'], 5);
        expect(params['allowsTickValuesOnly'], true);
        expect(params['neutralValue'], 0.0);
        expect(params.containsKey('tickValues'), isFalse);
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'a neutral value alone sends no tick options',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await pumpHost(
          tester,
          CNSlider(value: 0, onChanged: noop, neutralValue: 0.5),
        );
        expect(created.single['neutralValue'], 0.5);
        expect(created.single.containsKey('allowsTickValuesOnly'), isFalse);
        expect(created.single.containsKey('sliderStyle'), isFalse);
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'updates send the whole track configuration once',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final host = await pumpHost(
          tester,
          CNSlider(value: 0, max: 100, onChanged: noop),
        );

        var sent = await show(
          tester,
          host,
          CNSlider(value: 0, max: 100, onChanged: noop),
        );
        expect(sent, isEmpty, reason: 'no option, no call');

        sent = await show(
          tester,
          host,
          CNSlider(
            value: 0,
            max: 100,
            onChanged: noop,
            tickValues: [0, 10, 50],
            allowsTickValuesOnly: false,
          ),
        );
        expect(sent.map((c) => c.method), ['setTrackConfiguration']);
        expect(sent.single.arguments, {
          'tickValues': [0.0, 10.0, 50.0],
          'allowsTickValuesOnly': false,
        });

        sent = await show(
          tester,
          host,
          CNSlider(
            value: 0,
            max: 100,
            onChanged: noop,
            // A new list with the same values.
            tickValues: [0, 10, 50],
            allowsTickValuesOnly: false,
          ),
        );
        expect(sent, isEmpty);

        sent = await show(
          tester,
          host,
          CNSlider(
            value: 0,
            max: 100,
            onChanged: noop,
            style: CNSliderStyle.thumbless,
          ),
        );
        expect(sent.map((c) => c.method), [
          'setSliderStyle',
          'setTrackConfiguration',
        ]);
        expect(sent.first.arguments, {'sliderStyle': 'thumbless'});
        expect(sent.last.arguments, <String, Object>{});
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });

  group('CNSlider tick fallback', () {
    Future<Slider> fallback(WidgetTester tester, CNSlider slider) async {
      await tester.pumpWidget(_MaterialHost(child: Center(child: slider)));
      return tester.widget<Slider>(find.byType(Slider));
    }

    testWidgets('evenly spaced ticks become divisions', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var slider = await fallback(
        tester,
        CNSlider(value: 50, max: 100, numberOfTicks: 5, onChanged: (_) {}),
      );
      expect(slider.divisions, 4);

      slider = await fallback(
        tester,
        CNSlider(
          value: 50,
          max: 100,
          tickValues: const [100, 0, 50],
          onChanged: (_) {},
        ),
      );
      expect(slider.divisions, 2);

      slider = await fallback(
        tester,
        CNSlider(
          value: 50,
          max: 100,
          numberOfTicks: 5,
          allowsTickValuesOnly: false,
          onChanged: (_) {},
        ),
      );
      expect(slider.divisions, isNull, reason: 'no snapping, no divisions');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('uneven tick values snap in onChanged', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final values = <double>[];
      final slider = await fallback(
        tester,
        CNSlider(
          value: 0,
          max: 100,
          tickValues: const [0, 10, 25, 50, 100],
          onChanged: values.add,
        ),
      );
      expect(slider.divisions, isNull);
      slider.onChanged!(30);
      slider.onChanged!(80);
      expect(values, [25, 100]);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

/// Hosts a Material [Slider] fallback without a full MaterialApp.
class _MaterialHost extends StatelessWidget {
  const _MaterialHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CupertinoApp(home: Material(child: child));
}
