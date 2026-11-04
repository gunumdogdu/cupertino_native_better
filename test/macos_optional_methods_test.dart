// #47: the macOS views do not implement every method the iOS views do. A
// widget update that sends one of those must not end in an uncaught
// MissingPluginException: a debugger that breaks on uncaught exceptions pauses
// the UI isolate on it, which on macOS (merged platform and UI threads) is the
// main thread, so the app hangs.

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/optional_method_call.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Methods the macOS views answer with FlutterMethodNotImplemented.
const _notOnMacOS = {'setSemanticLabel', 'setTransitioning'};

class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool dark = false;

  void toggle() => setState(() => dark = !dark);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: CupertinoPageScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CNButton.icon(
                icon: CNSymbol(dark ? 'sun.max' : 'moon'),
                semanticLabel: dark ? 'Switch to light' : 'Switch to dark',
                onPressed: () {},
              ),
            ),
            CNSwitch(
              value: dark,
              semanticLabel: dark ? 'Dark' : 'Light',
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  final calls = <String>[];

  void mockMacOSNative(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    for (final type in ['CupertinoNativeButton', 'CupertinoNativeSwitch']) {
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(MethodChannel('${type}_$id'), (
          call,
        ) async {
          calls.add(call.method);
          if (_notOnMacOS.contains(call.method)) {
            throw MissingPluginException();
          }
          return null;
        });
      }
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final type in ['CupertinoNativeButton', 'CupertinoNativeSwitch']) {
        for (var id = 0; id < 20; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('${type}_$id'),
            null,
          );
        }
      }
    });
  }

  setUp(calls.clear);

  testWidgets(
    'an update that sends a method macOS lacks does not throw',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      mockMacOSNative(tester);
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: host));
      await tester.pumpAndSettle();

      host.currentState!.toggle();
      await tester.pumpAndSettle();
      host.currentState!.toggle();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The calls are still made, so iOS keeps getting them.
      expect(calls, contains('setSemanticLabel'));
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  group('invokeOptionalMethod', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('optional_method_test');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('ignores a method the native side does not implement', () async {
      await expectLater(channel.invokeOptionalMethod('missing'), completes);
    });

    test('still reports other errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'bad_args'),
          );
      await expectLater(
        channel.invokeOptionalMethod('broken'),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
