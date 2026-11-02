import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/icon_renderer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Items built in `build()`: new objects on every build, as items that
/// depend on state are.
List<CNPopupMenuEntry> _items(int build) => [
  CNPopupMenuItem(
    label: 'Mail',
    subtitle: 'build $build',
    customIcon: CupertinoIcons.mail,
  ),
  CNPopupMenuSubmenu(
    label: 'Share',
    items: [
      CNPopupMenuItem(
        label: 'Phone',
        subtitle: 'build $build',
        customIcon: CupertinoIcons.phone,
      ),
    ],
  ),
];

class _Host extends StatefulWidget {
  const _Host({super.key, required this.labelFollowsBuild});

  /// Puts the build count in `buttonLabel`, which recreates the native view.
  final bool labelFollowsBuild;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int builds = 0;

  void rebuild() => setState(() => builds++);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: Center(
      child: CNPopupMenuButton(
        buttonLabel: widget.labelFollowsBuild ? 'Menu $builds' : 'Menu',
        items: _items(builds),
        onPathSelected: (_) {},
      ),
    ),
  );
}

void main() {
  group('CNPopupMenuButton custom icons after a rebuild', () {
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
          MethodChannel('CupertinoNativePopupMenuButton_$id'),
          (call) async {
            calls.add(call);
            if (call.method == 'getIntrinsicSize') {
              return {'width': 100.0, 'height': 32.0};
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

    // Icons render through real image codecs, so let real time pass.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 25; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    setUp(() {
      // A render cached by an earlier test belongs to that test's zone.
      clearIconImageCache();
      created.clear();
      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    testWidgets(
      'setItems keeps the submenu icons',
      (tester) async {
        mockNative(tester);
        final host = GlobalKey<_HostState>();
        await tester.pumpWidget(_Host(key: host, labelFollowsBuild: false));
        await settle(tester);
        expect(created, hasLength(1));

        calls.clear();
        host.currentState!.rebuild();
        await settle(tester);

        final setItems = calls.lastWhere((c) => c.method == 'setItems');
        final share =
            ((setItems.arguments as Map)['submenus'] as List)[1] as Map;
        expect(share['customIconBytes'], [isA<Uint8List>()]);
        expect(created, hasLength(1), reason: 'the view was not recreated');
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );

    testWidgets(
      'a recreated view keeps its icons',
      (tester) async {
        mockNative(tester);
        final host = GlobalKey<_HostState>();
        await tester.pumpWidget(_Host(key: host, labelFollowsBuild: true));
        await settle(tester);
        expect(created, hasLength(1));

        host.currentState!.rebuild();
        await settle(tester);

        expect(created, hasLength(2), reason: 'buttonLabel recreates the view');
        final params = created.last;
        expect(params['customIconBytes'], [isA<Uint8List>(), null]);
        final share = (params['submenus'] as List)[1] as Map;
        expect(share['customIconBytes'], [isA<Uint8List>()]);
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );
  });

  testWidgets(
    'the fallback sheet does not open a disabled submenu or pick a disabled '
    'item',
    (tester) async {
      final paths = <List<int>>[];
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNPopupMenuButton(
              buttonLabel: 'Menu',
              items: const [
                CNPopupMenuItem(label: 'Off item', enabled: false),
                CNPopupMenuSubmenu(
                  label: 'Off submenu',
                  enabled: false,
                  items: [CNPopupMenuItem(label: 'Inside')],
                ),
                CNPopupMenuItem(label: 'On item'),
              ],
              onPathSelected: paths.add,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Off submenu'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Inside'), findsNothing);
      await tester.tap(find.text('Off item'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(paths, isEmpty);

      await tester.tap(find.text('On item'));
      await tester.pumpAndSettle();
      expect(paths, [
        [2],
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
