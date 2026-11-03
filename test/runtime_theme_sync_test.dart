import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Channel prefixes of the platform views that take `setBrightness`.
const _prefixes = [
  'CNFloatingIsland_',
  'CNSearchBar_',
  'CupertinoNativeGlassButtonGroup_',
];

final Map<String, Widget Function()> _widgets = {
  'CNFloatingIsland': () => const CNFloatingIsland(collapsed: Text('island')),
  'CNSearchBar': () => const CNSearchBar(),
  'CNGlassButtonGroup': () =>
      const CNGlassButtonGroup(buttons: [CNButtonData(label: 'One')]),
};

class _Host extends StatefulWidget {
  const _Host({super.key, required this.child});

  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Brightness? brightness = Brightness.light;

  void setBrightness(Brightness? value) => setState(() => brightness = value);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    theme: CupertinoThemeData(brightness: brightness),
    home: CupertinoPageScaffold(child: Center(child: widget.child)),
  );
}

void main() {
  final calls = <MethodCall>[];

  void mockNative(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    for (final prefix in _prefixes) {
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(MethodChannel('$prefix$id'), (
          call,
        ) async {
          calls.add(call);
          return null;
        });
      }
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final prefix in _prefixes) {
        for (var id = 0; id < 40; id++) {
          messenger.setMockMethodCallHandler(MethodChannel('$prefix$id'), null);
        }
      }
    });
  }

  List<Object?> brightnessCalls() => [
    for (final c in calls)
      if (c.method == 'setBrightness') (c.arguments as Map)['isDark'],
  ];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  for (final entry in _widgets.entries) {
    group('${entry.key} follows a runtime theme change', () {
      testWidgets(
        'sends setBrightness once per change',
        (tester) async {
          mockNative(tester);
          final host = GlobalKey<_HostState>();
          await tester.pumpWidget(_Host(key: host, child: entry.value()));
          await tester.pumpAndSettle();
          expect(
            brightnessCalls(),
            isEmpty,
            reason: 'creation params already carry the first theme',
          );

          host.currentState!.setBrightness(Brightness.dark);
          await tester.pumpAndSettle();
          expect(brightnessCalls(), [true]);

          host.currentState!.setBrightness(Brightness.dark);
          await tester.pumpAndSettle();
          expect(brightnessCalls(), [true], reason: 'same theme, no call');

          host.currentState!.setBrightness(Brightness.light);
          await tester.pumpAndSettle();
          expect(brightnessCalls(), [true, false]);
          debugDefaultTargetPlatformOverride = null;
        },
        skip: !(Platform.isMacOS || Platform.isIOS),
      );

      testWidgets(
        'follows the system appearance when the theme sets none',
        (tester) async {
          mockNative(tester);
          final dispatcher = tester.platformDispatcher;
          dispatcher.platformBrightnessTestValue = Brightness.light;
          addTearDown(dispatcher.clearPlatformBrightnessTestValue);
          final host = GlobalKey<_HostState>();
          await tester.pumpWidget(_Host(key: host, child: entry.value()));
          host.currentState!.setBrightness(null);
          await tester.pumpAndSettle();
          expect(brightnessCalls(), isEmpty);

          dispatcher.platformBrightnessTestValue = Brightness.dark;
          await tester.pumpAndSettle();
          expect(brightnessCalls(), [true]);
          debugDefaultTargetPlatformOverride = null;
        },
        skip: !(Platform.isMacOS || Platform.isIOS),
      );
    });
  }
}
