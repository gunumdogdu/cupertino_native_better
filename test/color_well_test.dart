import 'dart:ui' show ColorSpace;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a [CNColorWell] whose colour follows its own onChanged, like an app.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.initial = CupertinoColors.systemIndigo,
    this.supportsAlpha = true,
    this.enabled = true,
  });

  final Color initial;
  final bool supportsAlpha;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Color color = widget.initial;
  String? title = 'Accent Color';
  bool supportsEyedropper = true;
  Brightness brightness = Brightness.light;
  final changes = <Color>[];

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    theme: CupertinoThemeData(brightness: brightness),
    home: Center(
      child: CNColorWell(
        color: color,
        title: title,
        supportsAlpha: widget.supportsAlpha,
        supportsEyedropper: supportsEyedropper,
        enabled: widget.enabled,
        semanticLabel: 'Accent color',
        onChanged: (c) {
          changes.add(c);
          setState(() => color = c);
        },
      ),
    ),
  );
}

void main() {
  group('CNColorWell fallback', () {
    // The test host takes the Flutter fallback on Android.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('is a button named by its label, valued by its colour', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const _Host());
      expect(
        tester.getSemantics(find.bySemanticsLabel('Accent color')),
        isSemantics(
          label: 'Accent color',
          value: 'Indigo',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    }, variant: android);

    testWidgets('opens a palette whose swatches report the colour', (
      tester,
    ) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        _Host(key: key, initial: const Color(0x80FF0000)),
      );
      await tester.tap(find.byType(CNColorWell));
      await tester.pumpAndSettle();

      expect(find.text('Accent Color'), findsOneWidget);
      expect(find.byType(CupertinoSlider), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Teal'));
      await tester.pump();
      // The resolved light system teal, keeping the 50 % opacity.
      expect(key.currentState!.changes.single.toARGB32(), 0x805AC8FA);

      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Accent Color'), findsNothing);
    }, variant: android);

    testWidgets('has no opacity slider without supportsAlpha', (tester) async {
      await tester.pumpWidget(const _Host(supportsAlpha: false));
      await tester.tap(find.byType(CNColorWell));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoSlider), findsNothing);
    }, variant: android);

    testWidgets('a disabled well does not open', (tester) async {
      await tester.pumpWidget(const _Host(enabled: false));
      await tester.tap(find.byType(CNColorWell));
      await tester.pumpAndSettle();
      expect(find.text('Accent Color'), findsNothing);
    }, variant: android);
  });

  group('CNColorWell native', () {
    late List<MethodCall> calls;
    late int viewId;

    Future<GlobalKey<_HostState>> pumpNative(
      WidgetTester tester, {
      Color initial = CupertinoColors.systemIndigo,
    }) async {
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
          MethodChannel('CupertinoNativeColorWell_$id'),
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
            MethodChannel('CupertinoNativeColorWell_$id'),
            null,
          );
        }
      });
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, initial: initial));
      await tester.pumpAndSettle();
      return key;
    }

    /// Removes the view and the platform override inside the test body, as
    /// the binding checks the override is unset when the body returns.
    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }

    Map<Object?, Object?> creationParams() {
      final create = calls.firstWhere((c) => c.method == 'create');
      final bytes = (create.arguments as Map)['params'] as Uint8List;
      return const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(bytes),
          )
          as Map<Object?, Object?>;
    }

    List<String> sent() => [
      for (final c in calls)
        if (c.method != 'create') '${c.method} ${c.arguments}',
    ];

    testWidgets(
      'creates a fixed-size view with the resolved sRGB colour',
      (tester) async {
        await pumpNative(tester);
        expect(creationParams(), {
          'color': 0xFF5856D6,
          'supportsAlpha': true,
          'supportsEyedropper': true,
          'title': 'Accent Color',
          'enabled': true,
          'semanticLabel': 'Accent color',
          'isDark': false,
        });
        expect(tester.getSize(find.byType(UiKitView)), const Size(32, 32));
        expect(sent(), isEmpty, reason: 'nothing changed since creation');
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'converts a Display P3 colour to sRGB, clipped to its gamut',
      (tester) async {
        await pumpNative(
          tester,
          initial: const Color.from(
            alpha: 1,
            red: 0,
            green: 1,
            blue: 0,
            colorSpace: ColorSpace.displayP3,
          ),
        );
        expect(creationParams()['color'], 0xFF00FF00);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'reports a picked colour without sending it back',
      (tester) async {
        final key = await pumpNative(tester);
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'CupertinoNativeColorWell_$viewId',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('colorChanged', {'color': 0x80FF0000}),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
        expect(key.currentState!.changes.single, const Color(0x80FF0000));
        expect(sent(), isEmpty);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'sends option changes, the theme and the re-resolved colour',
      (tester) async {
        final key = await pumpNative(tester);
        key.currentState!.update(() {
          key.currentState!
            ..title = null
            ..supportsEyedropper = false;
        });
        await tester.pumpAndSettle();
        key.currentState!.update(
          () => key.currentState!.brightness = Brightness.dark,
        );
        await tester.pumpAndSettle();
        expect(sent(), [
          'setOptions {supportsAlpha: true, supportsEyedropper: false, '
              'title: null}',
          // systemIndigo's dark variant, sent once.
          'setColor {color: ${0xFF5E5CE6}}',
          'setBrightness {isDark: true}',
        ]);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
