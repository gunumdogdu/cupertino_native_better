import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cn_alert');

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
  }

  group('CNAlertAction', () {
    test('defaults to a plain, enabled action', () {
      const action = CNAlertAction<String>(label: 'OK', value: 'ok');

      expect(action.label, 'OK');
      expect(action.value, 'ok');
      expect(action.isDefault, false);
      expect(action.isCancel, false);
      expect(action.isDestructive, false);
      expect(action.enabled, true);
    });
  });

  group('CNAlertTextField', () {
    test('defaults to a visible field with no text', () {
      const field = CNAlertTextField(placeholder: 'Name');

      expect(field.placeholder, 'Name');
      expect(field.initialText, isNull);
      expect(field.obscureText, false);
    });
  });

  group('debugBuildAlertPayload', () {
    test('encodes actions in order with their style and flags', () {
      final payload = debugBuildAlertPayload(
        title: 'Delete photo?',
        message: 'This cannot be undone.',
        actions: const [
          CNAlertAction<String>(label: 'Cancel', isCancel: true),
          CNAlertAction<String>(
            label: 'Delete',
            value: 'delete',
            isDestructive: true,
            isDefault: true,
          ),
          CNAlertAction<String>(label: 'Later', value: 'later', enabled: false),
        ],
      );

      expect(payload['title'], 'Delete photo?');
      expect(payload['message'], 'This cannot be undone.');
      expect(payload['actions'], <Map<String, Object?>>[
        {
          'label': 'Cancel',
          'style': 'cancel',
          'enabled': true,
          'preferred': false,
        },
        {
          'label': 'Delete',
          'style': 'destructive',
          'enabled': true,
          'preferred': true,
        },
        {
          'label': 'Later',
          'style': 'default',
          'enabled': false,
          'preferred': false,
        },
      ]);
    });

    test('emits an empty text field list when none are supplied', () {
      final payload = debugBuildAlertPayload(
        actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
      );

      expect(payload['textFields'], isEmpty);
      expect(payload['title'], isNull);
      expect(payload['message'], isNull);
    });

    test('encodes text fields in order', () {
      final payload = debugBuildAlertPayload(
        actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        textFields: const [
          CNAlertTextField(placeholder: 'Username'),
          CNAlertTextField(
            placeholder: 'Password',
            initialText: 'hunter2',
            obscureText: true,
          ),
        ],
      );

      expect(payload['textFields'], <Map<String, Object?>>[
        {'placeholder': 'Username', 'initialText': null, 'obscure': false},
        {'placeholder': 'Password', 'initialText': 'hunter2', 'obscure': true},
      ]);
    });
  });

  group('CNAlert.show argument rules', () {
    testWidgets('refuses an alert with no actions', (tester) async {
      final calls = <MethodCall>[];
      mockChannel((call) async {
        calls.add(call);
        return null;
      });

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);

        // A `.alert` UIAlertController cannot be dismissed by tapping outside,
        // so an alert with no buttons can never be dismissed and its await
        // would never complete. Refused before it reaches the channel.
        expect(
          () => CNAlert.show<String>(context: context, actions: const []),
          throwsAssertionError,
        );
        expect(calls, isEmpty);
      });
    });

    testWidgets('refuses an alert whose every action is disabled', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      mockChannel((call) async {
        calls.add(call);
        return null;
      });

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);

        // Same dead end as the no-actions case: every exit from a `.alert`
        // runs an action handler, so an alert whose buttons all refuse taps
        // blocks the app with no way to answer the call.
        expect(
          () => CNAlert.show<String>(
            context: context,
            actions: const [
              CNAlertAction<String>(
                label: 'Retry',
                value: 'retry',
                enabled: false,
              ),
              CNAlertAction<String>(
                label: 'Cancel',
                isCancel: true,
                enabled: false,
              ),
            ],
          ),
          throwsAssertionError,
        );
        expect(calls, isEmpty);
      });
    });

    testWidgets('refuses two cancel actions', (tester) async {
      mockChannel((call) async => null);

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);

        // UIKit raises NSInternalInconsistencyException on a second
        // UIAlertAction with .cancel style.
        expect(
          () => CNAlert.show<String>(
            context: context,
            actions: const [
              CNAlertAction<String>(label: 'Cancel', isCancel: true),
              CNAlertAction<String>(label: 'Dismiss', isCancel: true),
            ],
          ),
          throwsAssertionError,
        );
      });
    });

    testWidgets('refuses two default actions', (tester) async {
      mockChannel((call) async => null);

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);

        expect(
          () => CNAlert.show<String>(
            context: context,
            actions: const [
              CNAlertAction<String>(label: 'Save', value: 'a', isDefault: true),
              CNAlertAction<String>(label: 'Keep', value: 'b', isDefault: true),
            ],
          ),
          throwsAssertionError,
        );
      });
    });

    testWidgets('refuses an action that is both cancel and destructive', (
      tester,
    ) async {
      mockChannel((call) async => null);

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);

        expect(
          () => CNAlert.show<String>(
            context: context,
            actions: const [
              CNAlertAction<String>(
                label: 'Discard',
                isCancel: true,
                isDestructive: true,
              ),
            ],
          ),
          throwsAssertionError,
        );
      });
    });
  });

  group('CNAlert.show follows the app theme', () {
    Future<Object?> sentIsDark(
      WidgetTester tester, {
      Brightness? theme,
      Brightness system = Brightness.light,
    }) async {
      MethodCall? received;
      mockChannel((call) async {
        received = call;
        return <String, Object?>{'index': 0, 'textFields': <String>[]};
      });
      tester.platformDispatcher.platformBrightnessTestValue = system;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester, brightness: theme);
        await CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        );
      });
      return (received!.arguments as Map)['isDark'];
    }

    testWidgets('light theme on a dark system sends false', (tester) async {
      expect(
        await sentIsDark(
          tester,
          theme: Brightness.light,
          system: Brightness.dark,
        ),
        false,
      );
    });

    testWidgets('dark theme on a light system sends true', (tester) async {
      expect(await sentIsDark(tester, theme: Brightness.dark), true);
    });

    testWidgets('no theme brightness leaves the style to the system', (
      tester,
    ) async {
      expect(await sentIsDark(tester, system: Brightness.dark), isNull);
    });
  });

  group('CNAlert.show on iOS', () {
    testWidgets('returns the selected action value and the text fields', (
      tester,
    ) async {
      mockChannel((call) async {
        expect(call.method, 'show');
        return <String, Object?>{
          'index': 1,
          'textFields': <String>['abc'],
        };
      });

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          actions: const [
            CNAlertAction<String>(label: 'Cancel', isCancel: true),
            CNAlertAction<String>(label: 'Save', value: 'save'),
          ],
          textFields: const [CNAlertTextField(placeholder: 'Name')],
        );

        expect(result?.value, 'save');
        expect(result?.textFields, <String>['abc']);
      });
    });

    testWidgets('returns an empty text list when native sends none', (
      tester,
    ) async {
      mockChannel((call) async => <String, Object?>{'index': 0});

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        );

        expect(result?.value, 'ok');
        expect(result?.textFields, isEmpty);
      });
    });

    testWidgets('returns null when the native side reports no selection', (
      tester,
    ) async {
      mockChannel((call) async => null);

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        );

        expect(result, isNull);
      });
    });

    testWidgets('returns null for an out-of-range index', (tester) async {
      // `index == actions.length` is the boundary: it is what separates the
      // `>=` guard from an off-by-one `>`.
      mockChannel((call) async => <String, Object?>{'index': 1});

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        );

        expect(result, isNull);
      });
    });

    testWidgets('returns null when the native side throws', (tester) async {
      mockChannel((call) async {
        throw PlatformException(code: 'no_presenter');
      });

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        );

        expect(result, isNull);
      });
    });

    testWidgets('returns null when the plugin is not registered', (
      tester,
    ) async {
      // A handler that throws MissingPluginException is how the test harness
      // reproduces an unregistered platform side: the codec turns it into a
      // "not implemented" envelope and the caller sees the same exception a
      // real missing plugin raises. Leaving the channel unmocked instead hangs
      // the call in `flutter test` rather than completing it.
      mockChannel((call) async => throw MissingPluginException('no impl'));

      await _withPlatform(TargetPlatform.iOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        );

        expect(result, isNull);
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
        await CNAlert.show<String>(
          context: context,
          title: 'Rename',
          message: 'Pick a new name.',
          actions: const [
            CNAlertAction<String>(label: 'Cancel', isCancel: true),
            CNAlertAction<String>(
              label: 'Save',
              value: 'save',
              isDefault: true,
            ),
          ],
          textFields: const [
            CNAlertTextField(placeholder: 'Name', initialText: 'Untitled'),
          ],
        );
      });

      // Asserted against the builder rather than key by key, so the
      // `debugBuildAlertPayload` tests above transitively cover what `show`
      // actually puts on the wire. A count would survive a dropped `style` key
      // or a reordered action list; `Config.init` defaults every missing key,
      // so that corruption is silent on the native side.
      expect(received?.method, 'show');
      expect(
        received?.arguments,
        debugBuildAlertPayload(
          // The app's Directionality (#144).
          rtl: false,
          title: 'Rename',
          message: 'Pick a new name.',
          actions: const [
            CNAlertAction<String>(label: 'Cancel', isCancel: true),
            CNAlertAction<String>(
              label: 'Save',
              value: 'save',
              isDefault: true,
            ),
          ],
          textFields: const [
            CNAlertTextField(placeholder: 'Name', initialText: 'Untitled'),
          ],
        ),
      );
    });
  });

  group('CNAlert.show on non-iOS', () {
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
          CNAlert.show<String>(
            context: context,
            title: 'Delete photo?',
            actions: const [
              CNAlertAction<String>(label: 'Cancel', isCancel: true),
              CNAlertAction<String>(label: 'Delete', value: 'delete'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(calls, isEmpty);
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);
        expect(find.byType(CupertinoDialogAction), findsNWidgets(2));
        expect(find.text('Delete photo?'), findsOneWidget);
      });
    });

    testWidgets('fallback marks destructive and default actions', (
      tester,
    ) async {
      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        unawaited(
          CNAlert.show<String>(
            context: context,
            actions: const [
              CNAlertAction<String>(
                label: 'Delete',
                value: 'delete',
                isDestructive: true,
              ),
              CNAlertAction<String>(
                label: 'Cancel',
                isCancel: true,
                isDefault: true,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final delete = tester.widget<CupertinoDialogAction>(
          find.widgetWithText(CupertinoDialogAction, 'Delete'),
        );
        final cancel = tester.widget<CupertinoDialogAction>(
          find.widgetWithText(CupertinoDialogAction, 'Cancel'),
        );

        expect(delete.isDestructiveAction, true);
        expect(delete.isDefaultAction, false);
        expect(cancel.isDestructiveAction, false);
        expect(cancel.isDefaultAction, true);
      });
    });

    testWidgets('fallback resolves to the tapped action', (tester) async {
      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNAlert.show<String>(
          context: context,
          actions: const [
            CNAlertAction<String>(label: 'First', value: 'first'),
            CNAlertAction<String>(label: 'Second', value: 'second'),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Second'));
        await tester.pumpAndSettle();

        final result = await future;
        expect(result?.value, 'second');
        expect(result?.textFields, isEmpty);
      });
    });

    testWidgets('fallback ignores a disabled action', (tester) async {
      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNAlert.show<String>(
          context: context,
          actions: const [
            CNAlertAction<String>(label: 'On', value: 'on'),
            CNAlertAction<String>(label: 'Off', value: 'off', enabled: false),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Off'));
        await tester.pumpAndSettle();

        // Still up: a disabled action must not resolve the call.
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);

        await tester.tap(find.text('On'));
        await tester.pumpAndSettle();

        expect((await future)?.value, 'on');
      });
    });

    testWidgets('fallback returns the value of a cancel action', (
      tester,
    ) async {
      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNAlert.show<String>(
          context: context,
          actions: const [
            CNAlertAction<String>(
              label: 'Cancel',
              value: 'cancelled',
              isCancel: true,
            ),
            CNAlertAction<String>(label: 'OK', value: 'ok'),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect((await future)?.value, 'cancelled');
      });
    });

    testWidgets('fallback renders text fields and returns what was typed', (
      tester,
    ) async {
      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNAlert.show<String>(
          context: context,
          title: 'Sign in',
          actions: const [
            CNAlertAction<String>(label: 'Cancel', isCancel: true),
            CNAlertAction<String>(label: 'Go', value: 'go'),
          ],
          textFields: const [
            CNAlertTextField(placeholder: 'Username'),
            CNAlertTextField(placeholder: 'Password', obscureText: true),
          ],
        );
        await tester.pumpAndSettle();

        final fields = find.byType(CupertinoTextField);
        expect(fields, findsNWidgets(2));
        expect(
          tester.widget<CupertinoTextField>(fields.at(1)).obscureText,
          true,
        );

        await tester.enterText(fields.at(0), 'ada');
        await tester.enterText(fields.at(1), 's3cret');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        final result = await future;
        expect(result?.value, 'go');
        expect(result?.textFields, <String>['ada', 's3cret']);
      });
    });

    testWidgets('fallback survives a barrier tap and resolves null on pop', (
      tester,
    ) async {
      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        );
        await tester.pumpAndSettle();

        // UIKit parity: `barrierDismissible: false`, so a tap outside the
        // dialog does nothing.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoAlertDialog), findsOneWidget);

        // A system back press on Android reaches this path in normal use.
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        expect(await future, isNull);
      });
    });

    testWidgets('fallback seeds a text field from initialText', (tester) async {
      await _withPlatform(TargetPlatform.android, () async {
        final context = await _pumpContext(tester);
        final future = CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'Save', value: 'save')],
          textFields: const [
            CNAlertTextField(placeholder: 'Name', initialText: 'Untitled'),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.text('Untitled'), findsOneWidget);

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect((await future)?.textFields, <String>['Untitled']);
      });
    });
  });

  group('CNAlert.show on macOS', () {
    testWidgets('presents the native NSAlert, not the Flutter fallback', (
      tester,
    ) async {
      MethodCall? received;
      mockChannel((call) async {
        received = call;
        return <String, Object?>{
          'index': 1,
          'textFields': <String>['Holiday'],
        };
      });

      await _withPlatform(TargetPlatform.macOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          title: 'Rename',
          actions: const [
            CNAlertAction<String>(label: 'Cancel', isCancel: true),
            CNAlertAction<String>(
              label: 'Save',
              value: 'save',
              isDefault: true,
            ),
          ],
          textFields: const [
            CNAlertTextField(placeholder: 'Name', initialText: 'Untitled'),
          ],
        );
        await tester.pump();

        expect(result?.value, 'save');
        expect(result?.textFields, <String>['Holiday']);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
      });

      // The iOS payload, unchanged: one Dart API for both platforms.
      expect(received?.method, 'show');
      expect(
        received?.arguments,
        debugBuildAlertPayload(
          // The app's Directionality (#144).
          rtl: false,
          title: 'Rename',
          actions: const [
            CNAlertAction<String>(label: 'Cancel', isCancel: true),
            CNAlertAction<String>(
              label: 'Save',
              value: 'save',
              isDefault: true,
            ),
          ],
          textFields: const [
            CNAlertTextField(placeholder: 'Name', initialText: 'Untitled'),
          ],
        ),
      );
    });

    testWidgets('sends isDark only when the theme sets a brightness (#118)', (
      tester,
    ) async {
      final sent = <Object?>[];
      mockChannel((call) async {
        final args = call.arguments as Map<Object?, Object?>;
        sent.add(args.containsKey('isDark') ? args['isDark'] : 'absent');
        return null;
      });

      await _withPlatform(TargetPlatform.macOS, () async {
        for (final theme in [Brightness.dark, Brightness.light, null]) {
          final context = await _pumpContext(tester, brightness: theme);
          await CNAlert.show<String>(
            context: context,
            actions: const [CNAlertAction<String>(label: 'OK')],
          );
        }
      });

      expect(sent, <Object?>[true, false, 'absent']);
    });

    testWidgets('a cancel answer still reports its value', (tester) async {
      mockChannel(
        (call) async => <String, Object?>{'index': 0, 'textFields': <String>[]},
      );

      await _withPlatform(TargetPlatform.macOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          actions: const [
            CNAlertAction<String>(
              label: 'Cancel',
              value: 'cancel',
              isCancel: true,
            ),
            CNAlertAction<String>(
              label: 'Delete',
              value: 'delete',
              isDestructive: true,
            ),
          ],
        );
        expect(result?.value, 'cancel');
      });
    });

    testWidgets('no window to attach the sheet to resolves to null', (
      tester,
    ) async {
      mockChannel((call) async => throw PlatformException(code: 'no_window'));

      await _withPlatform(TargetPlatform.macOS, () async {
        final context = await _pumpContext(tester);
        final result = await CNAlert.show<String>(
          context: context,
          actions: const [CNAlertAction<String>(label: 'OK', value: 'ok')],
        );
        expect(result, isNull);
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
Future<BuildContext> _pumpContext(
  WidgetTester tester, {
  Brightness? brightness,
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness),
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
