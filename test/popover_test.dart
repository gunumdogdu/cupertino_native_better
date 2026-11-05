import 'dart:async';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn_popover');

  /// Every call the plugin sent, and the open popover's answer, completed
  /// as the native side does: by `dismiss`, by a newer `show`, or by the
  /// test (a tap on a row).
  late List<MethodCall> calls;
  Completer<String?>? open;
  var mode = 'native';

  void answer(String? id) {
    final c = open;
    open = null;
    if (c != null && !c.isCompleted) c.complete(id);
  }

  setUp(() {
    calls = [];
    open = null;
    mode = 'native';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (mode == 'missing') throw MissingPluginException();
          if (mode == 'error') throw PlatformException(code: 'no_view');
          switch (call.method) {
            case 'show':
              answer(null); // A newer show replaces the open popover.
              final c = Completer<String?>();
              open = c;
              return c.future;
            case 'dismiss':
              answer(null);
          }
          return null;
        });
  });

  tearDown(() {
    answer(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> fromNative(String method, Object? args) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method, args)),
          (_) {},
        );
  }

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

  Map<Object?, Object?> showArgs([int i = 0]) =>
      named('show')[i].arguments as Map<Object?, Object?>;

  const content = CNPopoverContent(
    title: 'Sort By',
    message: 'Pick one',
    rows: [
      CNPopoverRow(
        id: 'name',
        item: CNListItem(
          title: 'Name',
          subtitle: 'A to Z',
          leadingSymbol: CNSymbol('textformat'),
          trailingText: '12',
          showChevron: true,
        ),
        checked: true,
      ),
      CNPopoverRow(
        id: 'size',
        item: CNListItem(title: 'Size'),
        enabled: false,
      ),
    ],
    toggles: [
      CNPopoverToggle(
        id: 'folders',
        label: 'Folders on top',
        subtitle: 'Always',
        symbol: CNSymbol('folder'),
        value: true,
      ),
    ],
    actions: [
      CNPopoverAction.cancel(label: 'Cancel'),
      CNPopoverAction(
        id: 'apply',
        label: 'Apply',
        style: CNPopoverActionStyle.defaultAction,
      ),
      CNPopoverAction(
        id: 'delete',
        label: 'Delete',
        style: CNPopoverActionStyle.destructive,
      ),
      CNPopoverAction(id: 'more', label: 'More'),
    ],
  );

  group('payload', () {
    test('carries the anchor, the edge, the options and the content', () {
      final payload = debugBuildPopoverPayload(
        session: 7,
        content: content,
        anchor: const Rect.fromLTWH(10, 20, 30, 40),
        edge: 'top',
        width: 260,
        tint: 0xFF112233,
        isDark: true,
      );
      expect(payload['session'], 7);
      expect(payload['anchor'], {
        'x': 10.0,
        'y': 20.0,
        'width': 30.0,
        'height': 40.0,
      });
      expect(payload['edge'], 'top');
      expect(payload['width'], 260.0);
      expect(payload['tint'], 0xFF112233);
      expect(payload['isDark'], true);

      final c = payload['content']! as Map<String, Object?>;
      expect(c['title'], 'Sort By');
      expect(c['message'], 'Pick one');
      expect(c['rows'], [
        {
          'title': 'Name',
          'subtitle': 'A to Z',
          'trailingText': '12',
          'leadingSfSymbol': 'textformat',
          'showChevron': true,
          'id': 'name',
          'checked': true,
          'enabled': true,
        },
        {
          'title': 'Size',
          'showChevron': false,
          'id': 'size',
          'checked': false,
          'enabled': false,
        },
      ]);
      expect(c['toggles'], [
        {
          'id': 'folders',
          'label': 'Folders on top',
          'value': true,
          'enabled': true,
          'subtitle': 'Always',
          'sfSymbol': 'folder',
        },
      ]);
      expect(c['actions'], [
        {'label': 'Cancel', 'style': 'cancel'},
        {'id': 'apply', 'label': 'Apply', 'style': 'default'},
        {'id': 'delete', 'label': 'Delete', 'style': 'destructive'},
        {'id': 'more', 'label': 'More', 'style': 'plain'},
      ]);
    });

    test('leaves out what is not set', () {
      final payload = debugBuildPopoverPayload(
        session: 1,
        content: const CNPopoverContent(title: 'Hi'),
        anchor: Rect.zero,
        edge: 'bottom',
      );
      expect(payload.containsKey('width'), isFalse);
      expect(payload.containsKey('tint'), isFalse);
      expect(payload.containsKey('isDark'), isFalse);
      final c = payload['content']! as Map<String, Object?>;
      expect(c.containsKey('message'), isFalse);
      expect(c['rows'], isEmpty);
      expect(c['toggles'], isEmpty);
      expect(c['actions'], isEmpty);
    });

    test('a cancel action has no id', () {
      const cancel = CNPopoverAction.cancel(label: 'Close');
      expect(cancel.id, isNull);
      expect(cancel.style, CNPopoverActionStyle.cancel);
    });
  });

  const anchorKey = Key('anchor');
  const pageKey = Key('page');

  /// A page with a 100x40 box at (50, 300) as the anchor.
  Widget page({
    GlobalKey? key,
    TextDirection direction = TextDirection.ltr,
    bool showAnchor = true,
    Brightness? brightness,
    List<NavigatorObserver> observers = const [],
  }) {
    return CupertinoApp(
      navigatorObservers: observers,
      theme: CupertinoThemeData(brightness: brightness),
      home: Directionality(
        textDirection: direction,
        child: Stack(
          key: pageKey,
          children: [
            if (showAnchor)
              Positioned(
                left: 50,
                top: 300,
                child: SizedBox(key: key ?? anchorKey, width: 100, height: 40),
              ),
          ],
        ),
      ),
    );
  }

  BuildContext contextOf(WidgetTester tester) =>
      tester.element(find.byKey(pageKey));

  group('on iOS and macOS', () {
    final platforms = TargetPlatformVariant(const {
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    });

    testWidgets('opens at the anchor and returns the chosen row', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(page(key: key, brightness: Brightness.dark));
      final result = CNPopover.show(
        context: contextOf(tester),
        anchorKey: key,
        content: content,
        width: 280,
        tint: const Color(0xFFFF0000),
      );
      await tester.pump();

      expect(CNPopover.isShown, isTrue);
      final args = showArgs();
      expect(args['anchor'], {
        'x': 50.0,
        'y': 300.0,
        'width': 100.0,
        'height': 40.0,
      });
      expect(args['edge'], 'bottom');
      expect(args['width'], 280.0);
      expect(args['tint'], 0xFFFF0000);
      expect(args['isDark'], true);
      expect((args['content']! as Map)['title'], 'Sort By');

      answer('name');
      expect(await result, 'name');
      expect(CNPopover.isShown, isFalse);
    }, variant: platforms);

    testWidgets('anchors to a rect, or to the widget of the context', (
      tester,
    ) async {
      await tester.pumpWidget(page());
      final byRect = CNPopover.show(
        context: contextOf(tester),
        anchorRect: const Rect.fromLTWH(5, 6, 7, 8),
        content: content,
      );
      await tester.pump();
      expect(showArgs()['anchor'], {
        'x': 5.0,
        'y': 6.0,
        'width': 7.0,
        'height': 8.0,
      });
      answer(null);
      expect(await byRect, isNull);

      final byContext = CNPopover.show(
        context: tester.element(find.byKey(anchorKey)),
        content: content,
      );
      await tester.pump();
      expect(showArgs(1)['anchor'], {
        'x': 50.0,
        'y': 300.0,
        'width': 100.0,
        'height': 40.0,
      });
      answer('apply');
      expect(await byContext, 'apply');
    }, variant: platforms);

    testWidgets('resolves leading and trailing for the text direction', (
      tester,
    ) async {
      for (final (direction, edge, expected) in const [
        (TextDirection.ltr, CNPopoverEdge.leading, 'left'),
        (TextDirection.ltr, CNPopoverEdge.trailing, 'right'),
        (TextDirection.rtl, CNPopoverEdge.leading, 'right'),
        (TextDirection.rtl, CNPopoverEdge.trailing, 'left'),
        (TextDirection.rtl, CNPopoverEdge.top, 'top'),
      ]) {
        await tester.pumpWidget(page(direction: direction));
        final result = CNPopover.show(
          context: tester.element(find.byKey(anchorKey)),
          preferredEdge: edge,
          content: content,
        );
        await tester.pump();
        expect(named('show').last.arguments['edge'], expected);
        answer(null);
        await result;
      }
    }, variant: platforms);

    testWidgets('reports switch changes of its own session only', (
      tester,
    ) async {
      await tester.pumpWidget(page());
      final changes = <String>[];
      final result = CNPopover.show(
        context: contextOf(tester),
        content: content,
        onToggleChanged: (id, value) => changes.add('$id=$value'),
      );
      await tester.pump();
      final session = showArgs()['session'];

      await fromNative('onToggleChanged', {
        'session': session,
        'id': 'folders',
        'value': false,
      });
      await fromNative('onToggleChanged', {
        'session': -1,
        'id': 'folders',
        'value': true,
      });
      expect(changes, ['folders=false']);
      answer(null);
      await result;
    }, variant: platforms);

    testWidgets('a second show closes the first, which returns null', (
      tester,
    ) async {
      await tester.pumpWidget(page());
      final first = CNPopover.show(
        context: contextOf(tester),
        content: content,
        onToggleChanged: (_, _) => fail('the first popover is closed'),
      );
      await tester.pump();
      final second = CNPopover.show(
        context: contextOf(tester),
        content: const CNPopoverContent(title: 'Second'),
      );
      await tester.pump();
      expect(await first, isNull);
      expect(CNPopover.isShown, isTrue);
      expect(showArgs(1)['session'], isNot(showArgs()['session']));

      // An event of the first session is dropped.
      await fromNative('onToggleChanged', {
        'session': showArgs()['session'],
        'id': 'folders',
        'value': true,
      });
      answer('ok');
      expect(await second, 'ok');
    }, variant: platforms);

    testWidgets('dismiss and update reach the open popover', (tester) async {
      await tester.pumpWidget(page());
      final result = CNPopover.show(
        context: contextOf(tester),
        content: content,
      );
      await tester.pump();
      final session = showArgs()['session'];

      await CNPopover.update(
        const CNPopoverContent(title: 'New', message: 'Updated'),
      );
      final update = named('update').single.arguments as Map;
      expect(update['session'], session);
      expect((update['content'] as Map)['message'], 'Updated');

      await CNPopover.dismiss();
      expect(named('dismiss').single.arguments, {'session': session});
      expect(await result, isNull);
      expect(CNPopover.isShown, isFalse);

      // Nothing is sent once it is closed.
      await CNPopover.dismiss();
      await CNPopover.update(const CNPopoverContent(title: 'Late'));
      expect(named('dismiss'), hasLength(1));
      expect(named('update'), hasLength(1));
    }, variant: platforms);

    testWidgets('closes when a route is pushed over its anchor', (
      tester,
    ) async {
      await tester.pumpWidget(page());
      final result = CNPopover.show(
        context: tester.element(find.byKey(anchorKey)),
        content: content,
      );
      await tester.pump();
      Navigator.of(
        contextOf(tester),
      ).push(CupertinoPageRoute<void>(builder: (_) => const SizedBox()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(named('dismiss'), hasLength(1));
      expect(await result, isNull);
      await tester.pumpAndSettle();
    }, variant: platforms);

    testWidgets('closes on a route change seen by the package observers', (
      tester,
    ) async {
      // The anchor's page is the current route of a nested navigator, which
      // a route pushed on the root navigator leaves current: only the
      // observer on the root navigator sees it.
      final root = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: root,
          navigatorObservers: [CNTabBarRouteObserver()],
          home: Navigator(
            onGenerateRoute: (_) => CupertinoPageRoute<void>(
              builder: (_) => const Center(
                child: SizedBox(key: anchorKey, width: 80, height: 30),
              ),
            ),
          ),
        ),
      );
      final result = CNPopover.show(
        context: tester.element(find.byKey(anchorKey)),
        content: content,
      );
      await tester.pump();
      root.currentState!.push(
        CupertinoPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pump();
      expect(named('dismiss'), hasLength(1));
      expect(await result, isNull);
      await tester.pumpAndSettle();
    }, variant: platforms);

    testWidgets('closes when its anchor goes away, and follows it while it '
        'moves', (tester) async {
      var left = 50.0;
      var showAnchor = true;
      late StateSetter setOuter;
      await tester.pumpWidget(
        CupertinoApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return Stack(
                children: [
                  if (showAnchor)
                    Positioned(
                      left: left,
                      top: 100,
                      child: const SizedBox(
                        key: anchorKey,
                        width: 60,
                        height: 30,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
      final result = CNPopover.show(
        context: tester.element(find.byKey(anchorKey)),
        content: content,
      );
      await tester.pump();

      setOuter(() => left = 120);
      await tester.pump();
      final move = named('setAnchor').single.arguments as Map;
      expect(move['session'], showArgs()['session']);
      expect(move['anchor'], {
        'x': 120.0,
        'y': 100.0,
        'width': 60.0,
        'height': 30.0,
      });

      setOuter(() => showAnchor = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(named('dismiss'), hasLength(1));
      expect(await result, isNull);
    }, variant: platforms);

    testWidgets('returns null when the native side fails', (tester) async {
      mode = 'error';
      await tester.pumpWidget(page());
      final result = CNPopover.show(
        context: contextOf(tester),
        content: content,
      );
      expect(await result, isNull);
      expect(CNPopover.isShown, isFalse);
    }, variant: platforms);

    testWidgets(
      'falls back to the Cupertino popup without a native side',
      (tester) async {
        mode = 'missing';
        await tester.pumpWidget(page());
        final result = CNPopover.show(
          context: contextOf(tester),
          content: content,
        );
        await tester.pumpAndSettle();
        expect(find.text('Sort By'), findsOneWidget);
        await tester.tap(find.text('Name'));
        await tester.pumpAndSettle();
        expect(await result, 'name');
      },
      variant: platforms,
    );
  });

  group('elsewhere (Cupertino popup)', () {
    final platforms = TargetPlatformVariant(const {
      TargetPlatform.android,
      TargetPlatform.linux,
      TargetPlatform.windows,
    });

    testWidgets('shows the content without the native channel', (tester) async {
      await tester.pumpWidget(page());
      final changes = <String>[];
      final result = CNPopover.show(
        context: contextOf(tester),
        content: content,
        onToggleChanged: (id, value) => changes.add('$id=$value'),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(CNPopover.isShown, isTrue);
      for (final text in ['Sort By', 'Pick one', 'Name', 'Size', 'Apply']) {
        expect(find.text(text), findsOneWidget);
      }

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(changes, ['folders=false']);

      // A disabled row does nothing.
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      expect(find.text('Sort By'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(await result, 'apply');
      expect(CNPopover.isShown, isFalse);
    }, variant: platforms);

    testWidgets('cancel, dismiss and update', (tester) async {
      await tester.pumpWidget(page());
      var result = CNPopover.show(context: contextOf(tester), content: content);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isNull);

      result = CNPopover.show(context: contextOf(tester), content: content);
      await tester.pumpAndSettle();
      await CNPopover.update(const CNPopoverContent(title: 'Updated'));
      await tester.pump();
      expect(find.text('Updated'), findsOneWidget);
      await CNPopover.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('Updated'), findsNothing);
      expect(await result, isNull);
    }, variant: platforms);
  });
}
