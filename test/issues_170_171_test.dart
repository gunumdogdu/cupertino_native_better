import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #170: the iOS 26 glass casts its shadow past an unclipped view that keeps
/// its box (`showShadow`), `initialText` opens the bar with text without
/// `onChanged`, and a `setText` made before the native view exists is
/// applied once it does. The controller drives the bar drawn in Flutter too.
///
/// #171: `placeholderColor` and the new `clearButtonColor` reach every bar.

/// Records what a [CNSearchBar] reports.
final List<String> _events = <String>[];

Widget _app(Widget bar, {GlobalKey<NavigatorState>? navigator}) => CupertinoApp(
  navigatorKey: navigator,
  navigatorObservers: <NavigatorObserver>[
    if (navigator != null) CNTabBarRouteObserver(),
  ],
  home: CupertinoPageScaffold(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [bar],
      ),
    ),
  ),
);

void main() {
  late List<MethodCall> calls;
  final viewIds = <int>[];

  void mockNative(WidgetTester tester, TargetPlatform platform) {
    calls = <MethodCall>[];
    viewIds.clear();
    _events.clear();
    debugDefaultTargetPlatformOverride = platform;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        viewIds.add((call.arguments as Map)['id'] as int);
        calls.add(call);
      }
      return null;
    });
    for (var id = 0; id < 40; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('CNSearchBar_$id'), (
        call,
      ) async {
        calls.add(MethodCall('$id:${call.method}', call.arguments));
        return null;
      });
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CNSearchBar_$id'),
          null,
        );
      }
    });
  }

  Map<Object?, Object?> paramsOf(MethodCall create) {
    final bytes = (create.arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  List<Map<Object?, Object?>> creations() => <Map<Object?, Object?>>[
    for (final c in calls)
      if (c.method == 'create') paramsOf(c),
  ];

  /// What the widget sent the views, as `<view id>:<method>`, without the
  /// containment state it sends every view.
  List<MethodCall> sent() => calls
      .where(
        (c) =>
            c.method != 'create' &&
            !c.method.endsWith(':setTransitioning') &&
            !c.method.endsWith(':setBrightness'),
      )
      .toList();

  Future<void> fromNative(
    WidgetTester tester,
    String method, [
    Object? args,
  ]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'CNSearchBar_${viewIds.last}',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  CNSearchBar bar({
    CNSearchBarController? controller,
    String? initialText,
    bool expandable = false,
    bool showShadow = true,
    Color? placeholderColor,
    Color? clearButtonColor,
  }) => CNSearchBar(
    controller: controller,
    expandable: expandable,
    showCancelButton: false,
    initialText: initialText,
    showShadow: showShadow,
    placeholderColor: placeholderColor,
    clearButtonColor: clearButtonColor,
    onChanged: (t) => _events.add('changed $t'),
  );

  group('#170 iOS 26+', () {
    testWidgets(
      'the glass view is not clipped and keeps the bar\'s box',
      (tester) async {
        mockNative(tester, TargetPlatform.iOS);
        await tester.pumpWidget(_app(bar()));
        await tester.pumpAndSettle();
        final view = find.byType(UiKitView);
        expect(view, findsOneWidget);
        for (final clip in <Type>[ClipRRect, ClipRect, ClipPath, ClipOval]) {
          expect(
            find.descendant(
              of: find.byType(CNSearchBar),
              matching: find.byType(clip),
            ),
            findsNothing,
            reason: 'a $clip would cut the shadow (and box the glow, #156)',
          );
        }
        final column = tester.getSize(find.byType(Column)).width;
        expect(tester.getSize(view), Size(column, 36));
        expect(tester.getSize(find.byType(CNSearchBar)), Size(column, 36));
        expect(creations().single['shadow'], true);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'showShadow: false is sent, and a change creates the view again with '
      'its text',
      (tester) async {
        mockNative(tester, TargetPlatform.iOS);
        final shadow = ValueNotifier<bool>(false);
        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<bool>(
              valueListenable: shadow,
              builder: (_, on, _) => bar(initialText: 'kite', showShadow: on),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(creations().single['shadow'], false);
        shadow.value = true;
        await tester.pumpAndSettle();
        expect(creations().map((p) => p['shadow']), [false, true]);
        expect(creations().last['text'], 'kite');
        expect(_events, isEmpty);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'initialText is a creation param and is not reported',
      (tester) async {
        mockNative(tester, TargetPlatform.iOS);
        await tester.pumpWidget(_app(bar(initialText: 'Land Cruiser')));
        await tester.pumpAndSettle();
        expect(creations().single['text'], 'Land Cruiser');
        expect(_events, isEmpty, reason: 'onChanged not called');
        expect(sent(), isEmpty, reason: 'nothing to tell the view');
        // What the user types after it is reported as before.
        await fromNative(tester, 'textChanged', {'text': 'Land Cruiser 300'});
        expect(_events, ['changed Land Cruiser 300']);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets('no initialText sends no text', (tester) async {
      mockNative(tester, TargetPlatform.iOS);
      await tester.pumpWidget(_app(bar()));
      await tester.pumpAndSettle();
      expect(creations().single.containsKey('text'), isFalse);
      await finish(tester);
    }, skip: !PlatformVersion.shouldUseNativeGlass);

    testWidgets(
      'a setText made before the view exists is sent once it does',
      (tester) async {
        mockNative(tester, TargetPlatform.iOS);
        final controller = CNSearchBarController();
        await controller.setText('first');
        await controller.setText('kite');
        expect(calls, isEmpty, reason: 'no view yet');
        await tester.pumpWidget(_app(bar(controller: controller)));
        await tester.pumpAndSettle();
        final id = viewIds.single;
        expect(sent().map((c) => c.method), ['$id:setText']);
        expect(sent().single.arguments, {'text': 'kite'}, reason: 'the last');
        // The view reports it, as it does for a setText (notify: true).
        await fromNative(tester, 'textChanged', {'text': 'kite'});
        expect(_events, ['changed kite']);

        // Once the view exists, setText goes straight to it.
        calls.clear();
        await controller.setText('owl');
        expect(sent().map((c) => c.method), ['$id:setText']);
        expect(sent().single.arguments, {'text': 'owl'});
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'a clear made before the view exists empties the initial text',
      (tester) async {
        mockNative(tester, TargetPlatform.iOS);
        final controller = CNSearchBarController();
        await controller.clear();
        await tester.pumpWidget(
          _app(bar(controller: controller, initialText: 'kite')),
        );
        await tester.pumpAndSettle();
        expect(sent().single.method, '${viewIds.single}:setText');
        expect(sent().single.arguments, {'text': ''});
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'a setText while the view is removed under a modal reaches the view '
      'created after it',
      (tester) async {
        mockNative(tester, TargetPlatform.iOS);
        final navigator = GlobalKey<NavigatorState>();
        final controller = CNSearchBarController();
        await tester.pumpWidget(
          _app(bar(controller: controller), navigator: navigator),
        );
        await tester.pumpAndSettle();
        final first = viewIds.single;

        showCupertinoModalPopup<void>(
          context: navigator.currentContext!,
          builder: (_) =>
              Container(height: 600, color: const Color(0xFFFFFFFF)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsNothing, reason: 'removed');
        calls.clear();
        await controller.setText('owl');
        expect(sent(), isEmpty, reason: 'not sent to the removed view');

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        final second = viewIds.last;
        expect(second, isNot(first));
        expect(sent().map((c) => c.method), ['$second:setText']);
        expect(sent().single.arguments, {'text': 'owl'});
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });

  group('#171 iOS 26+', () {
    testWidgets(
      'sends placeholderColor and clearButtonColor',
      (tester) async {
        mockNative(tester, TargetPlatform.iOS);
        await tester.pumpWidget(
          _app(
            bar(
              placeholderColor: const Color(0xFFFF3B30),
              clearButtonColor: const Color(0xFF34C759),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(creations().single['placeholderColor'], 0xFFFF3B30);
        expect(creations().single['clearButtonColor'], 0xFF34C759);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets('without clearButtonColor none is sent, so the view uses '
        'placeholderColor', (tester) async {
      mockNative(tester, TargetPlatform.iOS);
      await tester.pumpWidget(
        _app(bar(placeholderColor: const Color(0xFFFF3B30))),
      );
      await tester.pumpAndSettle();
      expect(creations().single['clearButtonColor'], isNull);
      await finish(tester);
    }, skip: !PlatformVersion.shouldUseNativeGlass);
  });

  group('macOS', () {
    testWidgets(
      'initialText is a creation param and is not reported',
      (tester) async {
        mockNative(tester, TargetPlatform.macOS);
        await tester.pumpWidget(_app(bar(initialText: 'Land Cruiser')));
        await tester.pumpAndSettle();
        expect(find.byType(AppKitView), findsOneWidget);
        expect(creations().single['text'], 'Land Cruiser');
        expect(_events, isEmpty);
        expect(sent(), isEmpty);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'a setText made before the view exists is sent once it does',
      (tester) async {
        mockNative(tester, TargetPlatform.macOS);
        final controller = CNSearchBarController();
        await controller.setText('kite');
        await tester.pumpWidget(_app(bar(controller: controller)));
        await tester.pumpAndSettle();
        expect(sent().map((c) => c.method), ['${viewIds.single}:setText']);
        expect(sent().single.arguments, {'text': 'kite'});
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'sends clearButtonColor at creation and when it changes',
      (tester) async {
        mockNative(tester, TargetPlatform.macOS);
        final color = ValueNotifier<Color?>(null);
        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<Color?>(
              valueListenable: color,
              builder: (_, c, _) => bar(clearButtonColor: c),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(creations().single['clearButtonColor'], isNull);
        color.value = const Color(0xFF34C759);
        await tester.pumpAndSettle();
        expect(sent().map((c) => c.method), ['${viewIds.single}:setConfig']);
        expect(
          (sent().single.arguments as Map)['clearButtonColor'],
          0xFF34C759,
        );
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );
  });

  group('the bar drawn in Flutter', () {
    Future<void> pumpFallback(WidgetTester tester, Widget bar) async {
      _events.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(_app(bar));
      // The bar's LiquidGlassContainer starts PlatformViewGuard's 500 ms
      // timer.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    Icon clearIcon(WidgetTester tester) => tester.widget<Icon>(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == CupertinoIcons.xmark_circle_fill,
      ),
    );

    testWidgets('initialText shows in the field and is not reported', (
      tester,
    ) async {
      await pumpFallback(tester, bar(initialText: 'Land Cruiser'));
      expect(find.byType(UiKitView), findsNothing);
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.controller!.text, 'Land Cruiser');
      expect(_events, isEmpty);
      await tester.enterText(find.byType(CupertinoTextField), 'Hilux');
      expect(_events, ['changed Hilux']);
      await finish(tester);
    });

    testWidgets('the clear button takes clearButtonColor, else '
        'placeholderColor', (tester) async {
      await pumpFallback(
        tester,
        bar(initialText: 'a', placeholderColor: const Color(0xFFFF3B30)),
      );
      expect(clearIcon(tester).color, const Color(0xFFFF3B30));
      await pumpFallback(
        tester,
        bar(
          initialText: 'a',
          placeholderColor: const Color(0xFFFF3B30),
          clearButtonColor: const Color(0xFF34C759),
        ),
      );
      expect(clearIcon(tester).color, const Color(0xFF34C759));
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.placeholderStyle!.color, const Color(0xFFFF3B30));
      await finish(tester);
    });

    testWidgets('the controller drives it', (tester) async {
      final controller = CNSearchBarController();
      await pumpFallback(tester, bar(controller: controller));
      String text() => tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text;

      await controller.setText('kite');
      await tester.pump();
      expect(text(), 'kite');
      await controller.clear();
      await tester.pump();
      expect(text(), '');
      expect(_events, ['changed kite', 'changed ']);

      await controller.focus();
      await tester.pump();
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.focusNode!.hasFocus, isTrue);
      await controller.unfocus();
      await tester.pump();
      expect(field.focusNode!.hasFocus, isFalse);
      await finish(tester);
    });

    testWidgets('a setText made before the bar is built is applied after '
        'its first frame', (tester) async {
      final controller = CNSearchBarController();
      await controller.setText('kite');
      await pumpFallback(tester, bar(controller: controller));
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.controller!.text, 'kite');
      expect(_events, ['changed kite']);
      await finish(tester);
    });

    testWidgets('expand and collapse an expandable bar', (tester) async {
      final controller = CNSearchBarController();
      await pumpFallback(
        tester,
        bar(controller: controller, expandable: true, initialText: 'kite'),
      );
      expect(controller.isExpanded, isFalse);
      expect(find.byType(CupertinoTextField), findsNothing);

      await controller.expand(animated: false);
      await tester.pump();
      expect(controller.isExpanded, isTrue);
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.controller!.text, 'kite', reason: 'the initial text');
      expect(_events, isEmpty);

      await controller.collapse();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isFalse);
      expect(_events, ['changed '], reason: 'collapsing clears the text');
      await finish(tester);
    });
  });
}
