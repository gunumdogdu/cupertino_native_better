import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cn_action_sheet');

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }

  group('CNActionSheetAction', () {
    test('defaults to non-destructive and enabled', () {
      const action = CNActionSheetAction<String>(
        label: 'Delete',
        value: 'delete',
      );

      expect(action.label, 'Delete');
      expect(action.value, 'delete');
      expect(action.isDestructive, false);
      expect(action.enabled, true);
    });
  });

  group('debugBuildActionSheetPayload', () {
    test('encodes actions in order with flags', () {
      final payload = debugBuildActionSheetPayload(
        title: 'Delete photo?',
        message: 'This cannot be undone.',
        actions: const [
          CNActionSheetAction<String>(
            label: 'Delete',
            value: 'delete',
            isDestructive: true,
          ),
          CNActionSheetAction<String>(
            label: 'Duplicate',
            value: 'dup',
            enabled: false,
          ),
        ],
        cancelLabel: 'Cancel',
      );

      expect(payload['title'], 'Delete photo?');
      expect(payload['message'], 'This cannot be undone.');
      expect(payload['cancelLabel'], 'Cancel');
      expect(payload.containsKey('anchorRect'), false);
      expect(payload['actions'], <Map<String, Object?>>[
        {'label': 'Delete', 'destructive': true, 'enabled': true},
        {'label': 'Duplicate', 'destructive': false, 'enabled': false},
      ]);
    });

    test('encodes anchorRect when supplied', () {
      final payload = debugBuildActionSheetPayload(
        actions: const [CNActionSheetAction<String>(label: 'Only', value: 'a')],
        anchorRect: const Rect.fromLTWH(10, 20, 30, 40),
      );

      expect(payload['anchorRect'], <String, double>{
        'x': 10.0,
        'y': 20.0,
        'width': 30.0,
        'height': 40.0,
      });
      expect(payload['title'], isNull);
      expect(payload['message'], isNull);
      expect(payload['cancelLabel'], isNull);
    });
  });

  group('CNActionSheet.show on iOS', () {
    testWidgets('returns the value of the selected action', (tester) async {
      mockChannel((call) async {
        expect(call.method, 'show');
        return 1;
      });

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final selected = await CNActionSheet.show<String>(
          context: context,
          actions: const [
            CNActionSheetAction<String>(label: 'First', value: 'first'),
            CNActionSheetAction<String>(label: 'Second', value: 'second'),
          ],
        );

        expect(selected, 'second');
      });
    });

    testWidgets('returns null when the sheet is cancelled', (tester) async {
      mockChannel((call) async => null);

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final selected = await CNActionSheet.show<String>(
          context: context,
          cancelLabel: 'Cancel',
          actions: const [
            CNActionSheetAction<String>(label: 'First', value: 'first'),
          ],
        );

        expect(selected, isNull);
      });
    });

    testWidgets('returns null for an out-of-range index', (tester) async {
      mockChannel((call) async => 7);

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final selected = await CNActionSheet.show<String>(
          context: context,
          actions: const [
            CNActionSheetAction<String>(label: 'First', value: 'first'),
          ],
        );

        expect(selected, isNull);
      });
    });

    testWidgets('sends the built payload over the channel', (tester) async {
      MethodCall? received;
      mockChannel((call) async {
        received = call;
        return null;
      });

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        await CNActionSheet.show<String>(
          context: context,
          title: 'Title',
          actions: const [
            CNActionSheetAction<String>(
              label: 'Delete',
              value: 'delete',
              isDestructive: true,
            ),
          ],
          cancelLabel: 'Cancel',
          anchorRect: const Rect.fromLTWH(1, 2, 3, 4),
        );
      });

      expect(received?.method, 'show');
      final args = received?.arguments as Map<Object?, Object?>?;
      expect(args?['title'], 'Title');
      expect(args?['cancelLabel'], 'Cancel');
      expect((args?['actions']! as List<Object?>).length, 1);
      expect(args?['anchorRect'], isA<Map<Object?, Object?>>());
    });

    testWidgets('refuses a sheet with no action and no cancel', (tester) async {
      final calls = <MethodCall>[];
      mockChannel((call) async {
        calls.add(call);
        return null;
      });

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);

        // Such a sheet has no button, so none of the native paths back to Dart
        // can run and the call would never complete. It is refused before it
        // reaches the channel.
        expect(
          () => CNActionSheet.show<String>(context: context, actions: const []),
          throwsAssertionError,
        );
        expect(calls, isEmpty);
      });
    });
  });

  group('CNActionSheet.show on non-iOS', () {
    testWidgets('does not call the channel and shows the fallback', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      mockChannel((call) async {
        calls.add(call);
        return null;
      });

      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        // The fallback pushes a Flutter route, so the future only completes
        // once that route is popped -- do not await it here.
        unawaited(
          CNActionSheet.show<String>(
            context: context,
            actions: const [
              CNActionSheetAction<String>(label: 'First', value: 'first'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(calls, isEmpty);
        expect(find.text('First'), findsOneWidget);
      });
    });

    testWidgets('fallback resolves to the tapped action', (tester) async {
      mockChannel((call) async => null);

      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNActionSheet.show<String>(
          context: context,
          cancelLabel: 'Cancel',
          actions: const [
            CNActionSheetAction<String>(label: 'First', value: 'first'),
            CNActionSheetAction<String>(label: 'Second', value: 'second'),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Second'));
        await tester.pumpAndSettle();

        expect(await future, 'second');
      });
    });

    testWidgets('fallback ignores a disabled action', (tester) async {
      mockChannel((call) async => null);

      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNActionSheet.show<String>(
          context: context,
          cancelLabel: 'Cancel',
          actions: const [
            CNActionSheetAction<String>(label: 'On', value: 'on'),
            CNActionSheetAction<String>(
              label: 'Off',
              value: 'off',
              enabled: false,
            ),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Off'));
        await tester.pumpAndSettle();

        // Still up: a disabled row must not resolve the call.
        expect(find.text('On'), findsOneWidget);

        await tester.tap(find.text('On'));
        await tester.pumpAndSettle();

        expect(await future, 'on');
      });
    });

    testWidgets('fallback cancel resolves to null', (tester) async {
      mockChannel((call) async => null);

      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNActionSheet.show<String>(
          context: context,
          cancelLabel: 'Cancel',
          actions: const [
            CNActionSheetAction<String>(label: 'First', value: 'first'),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(await future, isNull);
      });
    });
  });
}

/// Runs [body] with [debugDefaultTargetPlatformOverride] set, clearing it even
/// when an expectation fails.
///
/// `testWidgets` asserts every foundation debug variable is unset at the end of
/// the test body, which runs before `tearDown` -- so the reset has to happen
/// inside the body, not after it.
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

/// Pumps a minimal Cupertino app and returns a [BuildContext] below a
/// [Navigator], which the fallback path needs to push its route.
Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    CupertinoApp(
      home: Builder(
        builder: (context) {
          captured = context;
          return const CupertinoPageScaffold(child: SizedBox.shrink());
        },
      ),
    ),
  );
  return captured;
}
