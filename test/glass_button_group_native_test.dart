import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a [CNGlassButtonGroup] of an icon button with a badge and a menu
/// button, and records the presses.
class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final presses = <String>[];
  int badge = 3;

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: Center(
      child: CNGlassButtonGroup(
        buttons: [
          CNButtonData.icon(
            icon: const CNSymbol('tray'),
            badgeCount: badge,
            onPressed: () => presses.add('tray'),
            config: const CNButtonDataConfig(glassEffectUnionId: 'bar'),
          ),
          CNButtonData.popup(
            icon: const CNSymbol('arrow.up.arrow.down'),
            popupItems: const [
              CNButtonDataPopupItem(label: 'Date', sfSymbol: 'calendar'),
              CNButtonDataPopupItem(label: 'Name'),
            ],
            onMenuSelected: (i) => presses.add('menu $i'),
            config: const CNButtonDataConfig(glassEffectUnionId: 'bar'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late List<MethodCall> calls;
  late int viewId;

  Future<GlobalKey<_HostState>> pumpNative(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    calls = <MethodCall>[];
    debugDefaultTargetPlatformOverride = platform;
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
        MethodChannel('CupertinoNativeGlassButtonGroup_$id'),
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
          MethodChannel('CupertinoNativeGlassButtonGroup_$id'),
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

  Future<void> press(WidgetTester tester, Map<String, int> args) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'CupertinoNativeGlassButtonGroup_$viewId',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('buttonPressed', args),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  // macOS 26+ draws the group natively, as iOS 26+ does; the test host is
  // the Mac this runs on.
  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    testWidgets(
      '${platform.name}: one native group with the buttons and their presses',
      (tester) async {
        final key = await pumpNative(tester, platform);
        expect(
          find.byType(
            platform == TargetPlatform.macOS ? AppKitView : UiKitView,
          ),
          findsOneWidget,
        );
        final buttons = creationParams()['buttons'] as List<Object?>;
        expect(buttons, hasLength(2));
        expect((buttons[0] as Map)['iconName'], 'tray');
        expect((buttons[0] as Map)['badgeCount'], 3);
        expect((buttons[0] as Map)['glassEffectUnionId'], 'bar');
        expect((buttons[1] as Map)['menuLabels'], ['Date', 'Name']);
        expect((buttons[1] as Map)['menuSfSymbols'], ['calendar', '']);

        await press(tester, {'index': 0});
        await press(tester, {'index': 1, 'selectedIndex': 1});
        expect(key.currentState!.presses, ['tray', 'menu 1']);

        // A new count goes to that button only.
        key.currentState!.update(() => key.currentState!.badge = 7);
        await tester.pumpAndSettle();
        final update = calls.lastWhere((c) => c.method == 'updateButton');
        expect((update.arguments as Map)['index'], 0);
        expect(((update.arguments as Map)['button'] as Map)['badgeCount'], 7);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  }
}
