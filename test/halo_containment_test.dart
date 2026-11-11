import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Halo containment (`setTransitioning`) of the iOS 26 glass widgets.
///
/// #29: on while the host route animates. #124: also on while a modal route
/// over a mounted widget animates, and while its dialog or sheet is up over
/// the widget, from the push until the exit animation has finished. #149:
/// with the sheet elsewhere, the widget keeps its full glass while the sheet
/// is at rest, and a widget with the default `autoHideOnModal: true` stays
/// mounted (a sheet over it removes it).

/// The method channel prefix of each glass widget's native view.
const List<String> _prefixes = <String>[
  'CupertinoNativeButton_',
  'CupertinoNativePopupMenuButton_',
  'CupertinoNativeGlassButtonGroup_',
  'CupertinoNativeLiquidGlassContainer_',
  'CNSearchBar_',
  'CNFloatingIsland_',
];

/// The widgets under test, built with the given `autoHideOnModal`.
final Map<String, Widget Function(bool autoHide)> _widgets =
    <String, Widget Function(bool autoHide)>{
      'CNButton.icon': (autoHide) => CNButton.icon(
        icon: const CNSymbol('plus'),
        autoHideOnModal: autoHide,
        onPressed: () {},
      ),
      'CNButton': (autoHide) =>
          CNButton(label: 'Add', autoHideOnModal: autoHide, onPressed: () {}),
      'CNPopupMenuButton.icon': (autoHide) => CNPopupMenuButton.icon(
        buttonIcon: const CNSymbol('ellipsis'),
        items: const <CNPopupMenuEntry>[CNPopupMenuItem(label: 'One')],
        autoHideOnModal: autoHide,
        onSelected: (_) {},
      ),
      'CNGlassButtonGroup': (autoHide) => CNGlassButtonGroup(
        buttons: <CNButtonData>[
          CNButtonData.icon(icon: const CNSymbol('bold'), onPressed: () {}),
          CNButtonData.icon(icon: const CNSymbol('italic'), onPressed: () {}),
        ],
        autoHideOnModal: autoHide,
      ),
      'LiquidGlassContainer': (autoHide) => LiquidGlassContainer(
        config: const LiquidGlassConfig(),
        autoHideOnModal: autoHide,
        child: const SizedBox(width: 120, height: 44),
      ),
      'CNSearchBar': (autoHide) =>
          CNSearchBar(placeholder: 'Search', autoHideOnModal: autoHide),
      'CNFloatingIsland': (autoHide) => CNFloatingIsland(
        collapsed: const Text('Island'),
        autoHideOnModal: autoHide,
      ),
    };

void main() {
  /// `setTransitioning` values sent, by channel name, in order.
  final sent = <String, List<bool>>{};
  final navigator = GlobalKey<NavigatorState>();

  void mockNative(WidgetTester tester) {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    for (final prefix in _prefixes) {
      for (var id = 0; id < 60; id++) {
        final name = '$prefix$id';
        messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
          if (call.method == 'setTransitioning') {
            final active = (call.arguments as Map)['active'] as bool;
            (sent[name] ??= <bool>[]).add(active);
          }
          return null;
        });
      }
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final prefix in _prefixes) {
        for (var id = 0; id < 60; id++) {
          messenger.setMockMethodCallHandler(MethodChannel('$prefix$id'), null);
        }
      }
    });
  }

  Future<void> pumpHost(
    WidgetTester tester,
    Widget child, {
    bool observer = true,
    Alignment alignment = Alignment.center,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        navigatorObservers: <NavigatorObserver>[
          if (observer) CNTabBarRouteObserver(),
        ],
        home: CupertinoPageScaffold(
          child: Align(
            alignment: alignment,
            child: SizedBox(width: 200, height: 60, child: child),
          ),
        ),
      ),
    );
    // LiquidGlassContainer waits 500 ms before its first platform view in
    // debug builds (PlatformViewGuard).
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  /// Every value sent to any view since the last [clear].
  List<bool> all() => <bool>[for (final v in sent.values) ...v];

  /// The last value sent to each view that is still on screen. Views
  /// removed under a modal stay in [sent]; [names] narrows it down.
  bool? last(String name) => sent[name]?.last;

  void clear() => sent.clear();

  Future<void> openDialog(WidgetTester tester, {Widget? content}) async {
    showCupertinoDialog<void>(
      context: navigator.currentContext!,
      builder: (_) =>
          CupertinoAlertDialog(title: const Text('Dialog'), content: content),
    );
  }

  /// A 200 pt sheet at the bottom of the 800 by 600 test screen.
  void openBottomSheet() {
    showCupertinoModalPopup<void>(
      context: navigator.currentContext!,
      builder: (_) => Container(height: 200, color: const Color(0xFFFFFFFF)),
    );
  }

  /// Removes the views and the platform override inside the test body, as
  /// the binding checks the override is unset when the body returns.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  setUp(sent.clear);

  for (final entry in _widgets.entries) {
    group(entry.key, () {
      testWidgets(
        'autoHideOnModal: false keeps containment on from the dialog push '
        'until its exit animation ends (#124)',
        (tester) async {
          mockNative(tester);
          await pumpHost(tester, entry.value(false));
          final names = sent.keys.toList();
          expect(names, hasLength(1), reason: 'one native view');
          final name = names.single;
          expect(last(name), isFalse, reason: 'at rest: no containment');
          clear();

          await openDialog(tester);
          // The observer bumps the depth inside push, before any frame.
          await tester.pump();
          expect(sent[name], <bool>[true], reason: 'on with the push');

          await tester.pumpAndSettle();
          expect(sent[name], <bool>[true], reason: 'stays on while up');

          navigator.currentState!.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(sent[name], <bool>[
            true,
          ], reason: 'still on during the exit fade');

          await tester.pumpAndSettle();
          expect(sent[name], <bool>[true, false], reason: 'off once gone');
          await finish(tester);
        },
        skip: !PlatformVersion.shouldUseNativeGlass,
      );

      testWidgets(
        'default autoHideOnModal: a dialog over it removes the view, and the '
        'view it gets back is not contained',
        (tester) async {
          mockNative(tester);
          await pumpHost(tester, entry.value(true));
          clear();

          await openDialog(tester);
          await tester.pumpAndSettle();
          expect(
            find.byType(UiKitView),
            findsNothing,
            reason: 'removed under the dialog',
          );
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          // LiquidGlassContainer waits before its platform view.
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pumpAndSettle();

          expect(find.byType(UiKitView), findsOneWidget);
          expect(sent[sent.keys.last]!.last, isFalse);
          await finish(tester);
        },
        skip: !PlatformVersion.shouldUseNativeGlass,
      );

      for (final autoHide in <bool>[true, false]) {
        testWidgets(
          'autoHideOnModal: $autoHide, a sheet away from it: stays mounted, '
          'contained only while the sheet moves (#149)',
          (tester) async {
            mockNative(tester);
            await pumpHost(
              tester,
              entry.value(autoHide),
              alignment: Alignment.topCenter,
            );
            final name = sent.keys.single;
            clear();

            openBottomSheet();
            await tester.pump();
            expect(sent[name], <bool>[true], reason: 'as the sheet slides in');
            await tester.pumpAndSettle();
            expect(sent[name], <bool>[
              true,
              false,
            ], reason: 'full glass while the sheet is up elsewhere');
            expect(
              find.byType(UiKitView),
              findsOneWidget,
              reason: 'not removed',
            );

            navigator.currentState!.pop();
            await tester.pump();
            expect(sent[name], <bool>[true, false, true], reason: 'leaving');
            await tester.pumpAndSettle();
            expect(sent[name], <bool>[true, false, true, false]);
            expect(sent.keys, <String>[name], reason: 'the same view');
            await finish(tester);
          },
          skip: !PlatformVersion.shouldUseNativeGlass,
        );
      }

      testWidgets('a page pushed over it turns containment on only while it '
          'animates (#29)', (tester) async {
        mockNative(tester);
        await pumpHost(tester, entry.value(false));
        final name = sent.keys.single;
        clear();

        navigator.currentState!.push(
          CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(child: SizedBox()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(sent[name], <bool>[true]);
        await tester.pumpAndSettle();
        expect(sent[name], <bool>[true, false]);

        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(sent[name], <bool>[true, false, true]);
        await tester.pumpAndSettle();
        expect(sent[name], <bool>[true, false, true, false]);
        await finish(tester);
      }, skip: !PlatformVersion.shouldUseNativeGlass);
    });
  }

  testWidgets(
    'a button inside the dialog is not contained by its own dialog',
    (tester) async {
      mockNative(tester);
      await pumpHost(tester, const SizedBox());
      clear();

      await openDialog(
        tester,
        content: SizedBox(
          height: 50,
          child: CNButton.icon(
            icon: const CNSymbol('plus'),
            autoHideOnModal: false,
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(all(), isNotEmpty, reason: 'the button inside reported in');
      expect(all(), isNot(contains(true)));

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'a dialog over a dialog contains the button in the first one',
    (tester) async {
      mockNative(tester);
      await pumpHost(tester, const SizedBox());

      await openDialog(
        tester,
        content: SizedBox(
          height: 50,
          child: CNButton.icon(
            icon: const CNSymbol('plus'),
            autoHideOnModal: false,
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final name = sent.keys.single;
      expect(last(name), isFalse);

      await openDialog(tester);
      await tester.pumpAndSettle();
      expect(last(name), isTrue);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(last(name), isFalse);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );
}
