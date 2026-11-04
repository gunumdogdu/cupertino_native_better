import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/native_context_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cn_context_menu');

  /// Records every call and answers [reply] (a path, null, or a throw).
  List<MethodCall> mockChannel(Future<Object?> Function(MethodCall) reply) {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return reply(call);
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    return calls;
  }

  const items = <CNPopupMenuEntry>[
    CNPopupMenuItem(label: 'Copy', icon: CNSymbol('doc.on.doc')),
    CNPopupMenuItem(label: 'Share', subtitle: 'AirDrop, Mail'),
    CNPopupMenuDivider(),
    CNPopupMenuSubmenu(
      label: 'Move to',
      items: [
        CNPopupMenuItem(label: 'Travel'),
        CNPopupMenuItem(label: 'Family'),
      ],
    ),
    CNPopupMenuItem(label: 'Delete', isDestructive: true),
  ];

  const childKey = Key('child');

  Future<List<List<int>>> pumpMenu(
    WidgetTester tester, {
    bool enabled = true,
    VoidCallback? onChildTap,
    Brightness? brightness,
  }) async {
    final selected = <List<int>>[];
    await tester.pumpWidget(
      CupertinoApp(
        theme: CupertinoThemeData(brightness: brightness),
        home: CupertinoPageScaffold(
          child: Center(
            child: CNContextMenu(
              enabled: enabled,
              enableHapticFeedback: false,
              items: items,
              onSelected: selected.add,
              child: GestureDetector(
                onTap: onChildTap,
                child: Container(
                  key: childKey,
                  width: 200,
                  height: 100,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return selected;
  }

  Future<void> secondaryClick(WidgetTester tester, Offset at) async {
    final gesture = await tester.startGesture(
      at,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('debugBuildContextMenuPayload', () {
    test('carries the encoded menu, the position and isDark', () {
      final payload = debugBuildContextMenuPayload(
        items: items,
        position: const Offset(12.5, 40),
        resolveColor: (c) => c?.toARGB32(),
        isDark: true,
      );
      final menu = payload['menu']! as Map<String, Object?>;

      expect(payload['x'], 12.5);
      expect(payload['y'], 40.0);
      expect(payload['isDark'], true);
      expect(menu['labels'], ['Copy', 'Share', '', 'Move to', 'Delete']);
      expect(menu['isDivider'], [false, false, true, false, false]);
      expect(menu['isDestructive'], [false, false, false, false, true]);
      expect(menu['isSubmenu'], [false, false, false, true, false]);
      expect(menu['subtitles'], ['', 'AirDrop, Mail', '', '', '']);
      final submenus = menu['submenus']! as List<Object?>;
      expect((submenus[3]! as Map)['labels'], ['Travel', 'Family']);
    });

    test('leaves isDark out when the theme follows the system (#118)', () {
      final payload = debugBuildContextMenuPayload(
        items: items,
        position: Offset.zero,
        resolveColor: (c) => c?.toARGB32(),
      );
      expect(payload.containsKey('isDark'), isFalse);
    });
  });

  group('CNContextMenu on macOS', () {
    testWidgets('a secondary click opens the native menu at the pointer and '
        'reports the chosen path', (tester) async {
      final calls = mockChannel((call) async => <int>[3, 1]);
      await _withPlatform(TargetPlatform.macOS, () async {
        final selected = await pumpMenu(tester, brightness: Brightness.dark);
        final at =
            tester.getTopLeft(find.byKey(childKey)) + const Offset(30, 20);
        await secondaryClick(tester, at);

        expect(calls, hasLength(1));
        expect(calls.single.method, 'show');
        final args = calls.single.arguments as Map<Object?, Object?>;
        expect(args['x'], at.dx);
        expect(args['y'], at.dy);
        expect(args['isDark'], true);
        expect((args['menu']! as Map<Object?, Object?>)['labels'], [
          'Copy',
          'Share',
          '',
          'Move to',
          'Delete',
        ]);
        expect(selected, [
          [3, 1],
        ]);
      });
    });

    testWidgets('a menu closed without a choice calls nothing', (tester) async {
      mockChannel((call) async => null);
      await _withPlatform(TargetPlatform.macOS, () async {
        final selected = await pumpMenu(tester);
        await secondaryClick(tester, tester.getCenter(find.byKey(childKey)));
        expect(selected, isEmpty);
      });
    });

    testWidgets('a Control-click opens the menu and does not tap the child', (
      tester,
    ) async {
      final calls = mockChannel((call) async => <int>[0]);
      await _withPlatform(TargetPlatform.macOS, () async {
        var taps = 0;
        final selected = await pumpMenu(tester, onChildTap: () => taps++);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(childKey)),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.up();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(calls, hasLength(1));
        expect(selected, [
          [0],
        ]);
        expect(taps, 0);

        // A plain click is still the child's.
        await tester.tap(find.byKey(childKey), kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(calls, hasLength(1));
      });
    });

    testWidgets('a long press with the mouse is left to the child', (
      tester,
    ) async {
      final calls = mockChannel((call) async => null);
      await _withPlatform(TargetPlatform.macOS, () async {
        await pumpMenu(tester);
        await tester.longPress(
          find.byKey(childKey),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
      });
    });

    testWidgets('enabled: false opens nothing', (tester) async {
      final calls = mockChannel((call) async => null);
      await _withPlatform(TargetPlatform.macOS, () async {
        await pumpMenu(tester, enabled: false);
        await secondaryClick(tester, tester.getCenter(find.byKey(childKey)));
        expect(calls, isEmpty);
      });
    });

    testWidgets('showMenu opens it at the centre of the child', (tester) async {
      final calls = mockChannel((call) async => null);
      await _withPlatform(TargetPlatform.macOS, () async {
        final key = GlobalKey<CNContextMenuState>();
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: CNContextMenu(
                key: key,
                items: items,
                onSelected: (_) {},
                child: const SizedBox(key: childKey, width: 100, height: 50),
              ),
            ),
          ),
        );
        await key.currentState!.showMenu();
        final centre = tester.getCenter(find.byKey(childKey));
        final args = calls.single.arguments as Map<Object?, Object?>;
        expect(args['x'], centre.dx);
        expect(args['y'], centre.dy);
      });
    });
  });

  group('CNContextMenu on iOS', () {
    testWidgets('a long press opens the native menu where it was pressed', (
      tester,
    ) async {
      final calls = mockChannel((call) async => <int>[4]);
      await _withPlatform(TargetPlatform.iOS, () async {
        final selected = await pumpMenu(tester);
        final at = tester.getCenter(find.byKey(childKey));
        await tester.longPressAt(at);
        await tester.pumpAndSettle();

        final args = calls.single.arguments as Map<Object?, Object?>;
        expect(args['x'], at.dx);
        expect(args['y'], at.dy);
        expect(selected, [
          [4],
        ]);
      });
    });

    testWidgets('below iOS 17.4 the menu falls back to an action sheet', (
      tester,
    ) async {
      mockChannel((call) async => throw PlatformException(code: 'unavailable'));
      await _withPlatform(TargetPlatform.iOS, () async {
        final selected = await pumpMenu(tester);
        await tester.longPress(find.byKey(childKey));
        await tester.pumpAndSettle();

        expect(find.byType(CupertinoActionSheet), findsOneWidget);
        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();
        expect(selected, [
          [1],
        ]);
      });
    });

    testWidgets('the semantics long press opens the menu', (tester) async {
      final calls = mockChannel((call) async => null);
      await _withPlatform(TargetPlatform.iOS, () async {
        final handle = tester.ensureSemantics();
        await pumpMenu(tester);
        expect(
          tester.getSemantics(find.byKey(childKey)),
          matchesSemantics(hasLongPressAction: true),
        );
        tester.semantics.longPress(
          find.semantics.byAction(SemanticsAction.longPress),
        );
        await tester.pumpAndSettle();
        expect(calls, hasLength(1));
        handle.dispose();
      });
    });
  });

  group('CNContextMenu elsewhere', () {
    testWidgets('a long press shows the action sheet fallback', (tester) async {
      final calls = mockChannel((call) async => null);
      await _withPlatform(TargetPlatform.android, () async {
        final selected = await pumpMenu(tester);
        await tester.longPress(find.byKey(childKey));
        await tester.pumpAndSettle();

        expect(calls, isEmpty);
        expect(find.byType(CupertinoActionSheet), findsOneWidget);
        // The submenu opens a second sheet with its own items.
        await tester.tap(find.text('Move to'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Family'));
        await tester.pumpAndSettle();
        expect(selected, [
          [3, 1],
        ]);
      });
    });
  });
}

/// Runs [body] with [debugDefaultTargetPlatformOverride] set, clearing it
/// inside the test body, where `testWidgets` checks it.
Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}
