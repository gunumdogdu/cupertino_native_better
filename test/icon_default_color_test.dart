import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({super.key, required this.icon});

  final CNIcon icon;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Brightness brightness = Brightness.light;

  void setBrightness(Brightness value) => setState(() => brightness = value);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    theme: CupertinoThemeData(brightness: brightness),
    home: Center(child: widget.icon),
  );
}

const _black = 0xFF000000;
const _white = 0xFFFFFFFF;
const _red = 0xFFFF0000;

void main() {
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
        MethodChannel('CupertinoNativeIcon_$id'),
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
          MethodChannel('CupertinoNativeIcon_$id'),
          null,
        );
      }
    });
  }

  Future<GlobalKey<_HostState>> pumpHost(
    WidgetTester tester,
    CNIcon icon, {
    Brightness brightness = Brightness.light,
  }) async {
    mockNative(tester);
    final host = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: host, icon: icon));
    host.currentState!.setBrightness(brightness);
    // Let PlatformViewGuard's debug delay pass so the UiKitView is built.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    return host;
  }

  Object? createdColor() =>
      (created.single['style'] as Map<Object?, Object?>)['iconColor'];

  List<Object?> sentColors() => [
    for (final c in calls)
      if (c.method == 'setStyle' &&
          (c.arguments as Map).containsKey('iconColor'))
        (c.arguments as Map)['iconColor'],
  ];

  setUp(() {
    created.clear();
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  group('CNIcon without a colour', () {
    testWidgets('is created in the theme label colour', (tester) async {
      await pumpHost(
        tester,
        const CNIcon(symbol: CNSymbol('heart')),
        brightness: Brightness.dark,
      );
      expect(createdColor(), _white);
      debugDefaultTargetPlatformOverride = null;
    }, skip: !(Platform.isMacOS || Platform.isIOS));

    testWidgets('follows a runtime theme change', (tester) async {
      final host = await pumpHost(
        tester,
        const CNIcon(symbol: CNSymbol('heart')),
      );
      expect(createdColor(), _black);

      host.currentState!.setBrightness(Brightness.dark);
      await tester.pumpAndSettle();
      expect(sentColors(), [_white]);

      host.currentState!.setBrightness(Brightness.light);
      await tester.pumpAndSettle();
      expect(sentColors(), [_white, _black]);
      debugDefaultTargetPlatformOverride = null;
    }, skip: !(Platform.isMacOS || Platform.isIOS));

    testWidgets('leaves hierarchical mode to the native default', (
      tester,
    ) async {
      await pumpHost(
        tester,
        const CNIcon(
          symbol: CNSymbol('heart'),
          mode: CNSymbolRenderingMode.hierarchical,
        ),
        brightness: Brightness.dark,
      );
      expect(createdColor(), isNull);
      debugDefaultTargetPlatformOverride = null;
    }, skip: !(Platform.isMacOS || Platform.isIOS));
  });

  testWidgets('a given colour wins over the theme', (tester) async {
    final host = await pumpHost(
      tester,
      const CNIcon(symbol: CNSymbol('heart'), color: Color(_red)),
      brightness: Brightness.dark,
    );
    expect(createdColor(), _red);

    host.currentState!.setBrightness(Brightness.light);
    await tester.pumpAndSettle();
    expect(sentColors(), isEmpty);
    debugDefaultTargetPlatformOverride = null;
  }, skip: !(Platform.isMacOS || Platform.isIOS));
}
