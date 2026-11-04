import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Issue #76: the CNPopupGesture menu stayed invisible until a hot reload, and
// every item reported the same out-of-range index.
void main() {
  Future<List<int>> openMenu(WidgetTester tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CNPopupGesture(
              enableHapticFeedback: false,
              items: const [
                CNPopupMenuItem(label: 'Copy'),
                CNPopupMenuItem(label: 'Share'),
                CNPopupMenuDivider(),
                CNPopupMenuItem(label: 'Delete'),
              ],
              onSelected: selected.add,
              child: const Text('Long press me'),
            ),
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Long press me'));
    await tester.pumpAndSettle();
    return selected;
  }

  testWidgets('menu is visible once the open animation has finished', (
    tester,
  ) async {
    await openMenu(tester);

    expect(find.text('Share'), findsOneWidget);
    // On the old code the menu sat under an Opacity frozen at 0.
    expect(
      find.ancestor(
        of: find.text('Share'),
        matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
      ),
      findsNothing,
    );
  });

  testWidgets('each item reports its own index, dividers excluded', (
    tester,
  ) async {
    final selected = await openMenu(tester);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(selected, [1]);

    await tester.longPress(find.text('Long press me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(selected, [1, 2]);
  });

  group('CNPopupGesture on macOS', () {
    const channel = MethodChannel('cn_context_menu');
    const childKey = Key('child');

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

    Future<void> secondaryClick(WidgetTester tester, Offset at) async {
      final gesture = await tester.startGesture(
        at,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('a secondary click opens the native menu and reports the '
        'item index without dividers', (tester) async {
      final calls = mockChannel((call) async => <int>[2]);
      await _withPlatform(TargetPlatform.macOS, () async {
        final selected = <int>[];
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: CNPopupGesture(
                enableHapticFeedback: false,
                items: const [
                  CNPopupMenuItem(label: 'Copy'),
                  CNPopupMenuDivider(),
                  CNPopupMenuItem(label: 'Share'),
                ],
                onSelected: selected.add,
                child: const ColoredBox(
                  color: Color(0xFF34C759),
                  child: SizedBox(key: childKey, width: 120, height: 60),
                ),
              ),
            ),
          ),
        );
        await secondaryClick(tester, tester.getCenter(find.byKey(childKey)));

        final menu =
            (calls.single.arguments as Map<Object?, Object?>)['menu']!
                as Map<Object?, Object?>;
        expect(menu['labels'], ['Copy', '', 'Share']);
        expect(selected, [1]);
      });
    });

    testWidgets('elsewhere a secondary click opens nothing', (tester) async {
      final calls = mockChannel((call) async => null);
      await _withPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: CNPopupGesture(
                enableHapticFeedback: false,
                items: const [CNPopupMenuItem(label: 'Copy')],
                onSelected: (_) {},
                child: const ColoredBox(
                  color: Color(0xFF34C759),
                  child: SizedBox(key: childKey, width: 120, height: 60),
                ),
              ),
            ),
          ),
        );
        await secondaryClick(tester, tester.getCenter(find.byKey(childKey)));
        expect(calls, isEmpty);
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
