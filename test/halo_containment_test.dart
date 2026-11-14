import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Halo containment (`setTransitioning`) of the iOS 26 glass widgets.
///
/// Each value sent is recorded as `full` (no containment), `cut` (full
/// glass, the glow under what covers it masked out) or `contained` (clipped
/// to its bounds, flat).
///
/// #29 and #159: while the host route animates, the glow the moving page
/// covers is cut; without a `CNTabBarRouteObserver` the widget is contained.
/// #124 and #156: while a modal route's dialog or sheet is within reach of a
/// mounted widget's glow, from the push until the exit animation has
/// finished, the glow it covers is cut. #149 and #156: with the sheet
/// elsewhere, the widget keeps its full glass while the sheet is up and
/// while it moves, and a widget with the default `autoHideOnModal: true`
/// stays mounted (a sheet over it removes it).

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
  final sent = <String, List<String>>{};

  /// The `cuts` of the last `setTransitioning` call, by channel name.
  final lastCuts = <String, List<Rect>>{};
  final navigator = GlobalKey<NavigatorState>();

  void mockNative(WidgetTester tester) {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    for (final prefix in _prefixes) {
      for (var id = 0; id < 200; id++) {
        final name = '$prefix$id';
        messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
          if (call.method == 'setTransitioning') {
            final args = call.arguments as Map;
            final cuts = <Rect>[
              for (final c in (args['cuts'] as List?) ?? const <Object>[])
                Rect.fromLTRB(
                  (c as List)[0] as double,
                  c[1] as double,
                  c[2] as double,
                  c[3] as double,
                ),
            ];
            lastCuts[name] = cuts;
            (sent[name] ??= <String>[]).add(
              args['active'] as bool
                  ? 'contained'
                  : cuts.isEmpty
                  ? 'full'
                  : 'cut',
            );
          }
          return null;
        });
      }
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final prefix in _prefixes) {
        for (var id = 0; id < 200; id++) {
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
    bool pageRouteBuilder = false,
  }) async {
    final page = CupertinoPageScaffold(
      child: Align(
        alignment: alignment,
        child: SizedBox(width: 200, height: 60, child: child),
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        navigatorObservers: <NavigatorObserver>[
          if (observer) CNTabBarRouteObserver(),
        ],
        home: pageRouteBuilder ? null : page,
        // A page in a `PageRouteBuilder` transitions to any page route over
        // it, a sheet package's sheet route too (#161).
        onGenerateRoute: pageRouteBuilder
            ? (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => page,
                transitionDuration: Duration.zero,
              )
            : null,
      ),
    );
    // LiquidGlassContainer waits 500 ms before its first platform view in
    // debug builds (PlatformViewGuard).
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  /// Every value sent to any view since the last [clear].
  List<String> all() => <String>[for (final v in sent.values) ...v];

  /// The last value sent to each view that is still on screen. Views
  /// removed under a modal stay in [sent]; [names] narrows it down.
  String? last(String name) => sent[name]?.last;

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

  setUp(() {
    sent.clear();
    lastCuts.clear();
  });

  for (final entry in _widgets.entries) {
    group(entry.key, () {
      testWidgets(
        'autoHideOnModal: false: the dialog over it cuts the glow it covers '
        'from its first frame until its exit animation ends (#124, #156)',
        (tester) async {
          mockNative(tester);
          await pumpHost(tester, entry.value(false));
          final names = sent.keys.toList();
          expect(names, hasLength(1), reason: 'one native view');
          final name = names.single;
          expect(last(name), 'full', reason: 'at rest: no containment');
          clear();

          await openDialog(tester);
          await tester.pump();
          expect(sent[name], isNotEmpty, reason: 'cut after its first frame');
          expect(sent[name], everyElement('cut'));

          await tester.pumpAndSettle();
          expect(sent[name], everyElement('cut'), reason: 'cut while up');

          navigator.currentState!.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            sent[name],
            everyElement('cut'),
            reason: 'still cut during the exit fade',
          );

          await tester.pumpAndSettle();
          expect(last(name), 'full', reason: 'full once gone');
          expect(
            sent[name]!.sublist(0, sent[name]!.length - 1),
            everyElement('cut'),
            reason: 'never clipped flat',
          );
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
          expect(sent[sent.keys.last]!.last, 'full');
          await finish(tester);
        },
        skip: !PlatformVersion.shouldUseNativeGlass,
      );

      for (final autoHide in <bool>[true, false]) {
        testWidgets(
          'autoHideOnModal: $autoHide, a sheet away from it: stays mounted, '
          'never contained (#149, #156)',
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
            expect(
              sent[name],
              isNull,
              reason:
                  'its first frame paints next to nothing, and it is '
                  'measured elsewhere after it',
            );
            await tester.pumpAndSettle();
            expect(
              sent[name],
              isNull,
              reason: 'full glass while the sheet slides in and is up',
            );
            expect(
              find.byType(UiKitView),
              findsOneWidget,
              reason: 'not removed',
            );

            navigator.currentState!.pop();
            await tester.pumpAndSettle();
            expect(sent[name], isNull, reason: 'and while it leaves');
            expect(
              sent.keys,
              isEmpty,
              reason: 'a new view would have been sent its state',
            );
            await finish(tester);
          },
          skip: !PlatformVersion.shouldUseNativeGlass,
        );
      }

      testWidgets('a page pushed over it and popped off it cuts the glow it '
          'covers, and never clips it flat (#29, #159)', (tester) async {
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
        expect(sent[name], isNull, reason: 'the page has painted nothing yet');
        await tester.pumpAndSettle();
        expect(sent[name], contains('cut'), reason: 'cut as the page comes');
        expect(sent[name], isNot(contains('contained')));
        expect(last(name), 'full', reason: 'full once it stops');
        clear();

        navigator.currentState!.pop();
        expect(
          sent[name],
          <String>['cut'],
          reason: 'the page covers it where it stands when the pop starts',
        );
        await tester.pumpAndSettle();
        expect(sent[name], isNot(contains('contained')));
        expect(last(name), 'full', reason: 'full once the page has gone');
        expect(
          sent[name]!.sublist(0, sent[name]!.length - 1),
          everyElement('cut'),
        );
        await finish(tester);
      }, skip: !PlatformVersion.shouldUseNativeGlass);

      testWidgets('on a page in a PageRouteBuilder, a sheet route away from '
          'it leaves its full glass while it opens, is held mid-drag and '
          'closes (#161)', (tester) async {
        mockNative(tester);
        await pumpHost(
          tester,
          entry.value(false),
          alignment: Alignment.topCenter,
          pageRouteBuilder: true,
        );
        final name = sent.keys.single;
        clear();

        final sheet = _SheetPageRoute();
        navigator.currentState!.push(sheet);
        await tester.pumpAndSettle();
        expect(
          sent[name],
          isNull,
          reason: 'full glass while the sheet slides in and is up',
        );

        // A finger holding the sheet part-way down, as sheet packages drive
        // their route's animation.
        sheet.drag(0.6);
        await tester.pump();
        await tester.pump();
        sheet.drag(0.5);
        await tester.pump();
        await tester.pump();
        expect(sent[name], isNull, reason: 'and while it is held mid-drag');
        sheet.drag(1);
        await tester.pumpAndSettle();

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(sent[name], isNull, reason: 'and while it leaves');
        await finish(tester);
      }, skip: !PlatformVersion.shouldUseNativeGlass);

      testWidgets('without a route observer, a page pushed over it contains '
          'it while it animates (#29)', (tester) async {
        mockNative(tester);
        await pumpHost(tester, entry.value(false), observer: false);
        final name = sent.keys.single;
        clear();

        navigator.currentState!.push(
          CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(child: SizedBox()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(sent[name], <String>['contained']);
        await tester.pumpAndSettle();
        expect(sent[name], <String>['contained', 'full']);

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
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
      expect(all(), everyElement('full'));

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'a dialog over a dialog cuts the glow it covers of the button in the '
    'first one',
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
      expect(last(name), 'full');

      await openDialog(tester);
      await tester.pumpAndSettle();
      expect(last(name), 'cut');

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(last(name), 'full');

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'a sheet whose edge is just below the button cuts the glow under the '
    'sheet only, in the native view\'s coordinates (#156)',
    (tester) async {
      mockNative(tester);
      // The 60 pt host ends 8 pt above the 200 pt sheet's top edge (400).
      await pumpHost(
        tester,
        CNButton.icon(
          icon: const CNSymbol('xmark'),
          autoHideOnModal: false,
          onPressed: () {},
        ),
        alignment: const Alignment(0, 0.1925),
      );
      final name = sent.keys.single;
      final view = tester.getRect(find.byType(UiKitView));
      expect(400 - view.bottom, inExclusiveRange(0, 24), reason: 'in reach');
      clear();

      openBottomSheet();
      await tester.pumpAndSettle();
      expect(last(name), 'cut');
      expect(sent[name], isNot(contains('contained')));
      final bounds = Offset.zero & view.size;
      final sheet = const Rect.fromLTRB(
        0,
        400,
        800,
        600,
      ).shift(-view.topLeft).intersect(bounds.inflate(160));
      expect(lastCuts[name], hasLength(1), reason: 'below its bounds only');
      expect(_rounded(lastCuts[name]!.single), _rounded(sheet));

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(last(name), 'full');
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'on a page in a PageRouteBuilder, a sheet route whose edge is just below '
    'the button cuts the glow under the sheet only, not all round it (#161)',
    (tester) async {
      mockNative(tester);
      // The 60 pt host ends 8 pt above the 200 pt sheet's top edge (400).
      await pumpHost(
        tester,
        CNButton.icon(
          icon: const CNSymbol('heart'),
          autoHideOnModal: false,
          onPressed: () {},
        ),
        alignment: const Alignment(0, 0.1925),
        pageRouteBuilder: true,
      );
      final name = sent.keys.single;
      final view = tester.getRect(find.byType(UiKitView));
      clear();

      final route = _SheetPageRoute();
      navigator.currentState!.push(route);
      await tester.pumpAndSettle();
      expect(last(name), 'cut');
      expect(sent[name], isNot(contains('contained')));
      final bounds = Offset.zero & view.size;
      final sheet = const Rect.fromLTRB(
        0,
        400,
        800,
        600,
      ).shift(-view.topLeft).intersect(bounds.inflate(160));
      expect(lastCuts[name], hasLength(1), reason: 'below its bounds only');
      expect(_rounded(lastCuts[name]!.single), _rounded(sheet));

      // Held part-way down, the sheet's edge is well below the button.
      route.drag(0.5);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(last(name), 'full', reason: 'its edge is out of reach');
      expect(sent[name], isNot(contains('contained')));
      expect(lastCuts[name], isEmpty);
      route.drag(1);
      await tester.pumpAndSettle();
      expect(last(name), 'cut');
      expect(lastCuts[name], hasLength(1), reason: 'below its bounds only');

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(last(name), 'full');
      expect(sent[name], isNot(contains('contained')));
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  for (final pageRouteBuilder in <bool>[false, true]) {
    testWidgets(
      'a sheet route that is a page route cuts nothing in the first frame of '
      'its push, when it is offstage and laid out open '
      '(pageRouteBuilder: $pageRouteBuilder, #161)',
      (tester) async {
        mockNative(tester);
        // At the bottom, under where the 200 pt sheet ends up.
        await pumpHost(
          tester,
          CNButton.icon(
            icon: const CNSymbol('heart'),
            autoHideOnModal: false,
            onPressed: () {},
          ),
          alignment: Alignment.bottomCenter,
          pageRouteBuilder: pageRouteBuilder,
        );
        final name = sent.keys.single;
        clear();

        navigator.currentState!.push(_SheetPageRoute());
        await tester.pump();
        expect(sent[name], isNull, reason: 'the sheet has painted nothing yet');
        await tester.pump();
        expect(
          sent[name],
          isNull,
          reason: 'its first painted frame is below the screen',
        );
        await tester.pumpAndSettle();
        expect(last(name), 'cut', reason: 'under the sheet once it is up');
        expect(sent[name], isNot(contains('contained')));

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(last(name), 'full');
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  }

  testWidgets(
    'on a page in a PageRouteBuilder, a page pushed over the button still '
    'cuts the glow it covers as it slides (#159, #161)',
    (tester) async {
      mockNative(tester);
      await pumpHost(
        tester,
        CNButton.icon(
          icon: const CNSymbol('xmark'),
          autoHideOnModal: false,
          onPressed: () {},
        ),
        pageRouteBuilder: true,
      );
      final name = sent.keys.single;
      clear();

      navigator.currentState!.push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(child: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(sent[name], contains('cut'), reason: 'cut as the page comes');
      expect(sent[name], isNot(contains('contained')));
      expect(last(name), 'full', reason: 'full once it stops');

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(last(name), 'full');
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'a page over the button cuts its glow all round its bounds, never '
    'inside them (#159)',
    (tester) async {
      mockNative(tester);
      await pumpHost(
        tester,
        CNButton.icon(
          icon: const CNSymbol('xmark'),
          autoHideOnModal: false,
          onPressed: () {},
        ),
      );
      final name = sent.keys.single;
      final view = tester.getRect(find.byType(UiKitView));
      navigator.currentState!.push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(child: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      clear();

      navigator.currentState!.pop();
      final bounds = Offset.zero & view.size;
      expect(sent[name], <String>['cut']);
      final cuts = lastCuts[name]!;
      expect(cuts, hasLength(4), reason: 'above, below, left and right');
      for (final cut in cuts) {
        expect(cut.overlaps(bounds), isFalse, reason: 'never inside it');
      }
      // Every point of the glow's reach outside the bounds is cut.
      final reach = bounds.inflate(24);
      for (var x = reach.left + 1; x < reach.right; x += 4) {
        for (var y = reach.top + 1; y < reach.bottom; y += 4) {
          final p = Offset(x, y);
          if (bounds.contains(p)) continue;
          expect(cuts.any((c) => c.contains(p)), isTrue, reason: '$p');
        }
      }
      await tester.pumpAndSettle();
      await finish(tester);
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );
}

/// A sheet route that is a `PageRoute`, as sheet packages' are
/// (`modal_bottom_sheet`): its page is the whole screen, and it slides its
/// sheet up from the bottom itself. The type name has `Sheet` in it, so the
/// observer counts it as a modal (#161).
class _SheetPageRoute extends PageRoute<void> {
  _SheetPageRoute();

  /// Sets the route's animation as a finger dragging the sheet does.
  void drag(double value) => controller!.value = value;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation),
        child: Container(height: 200, color: const Color(0xFFFFFFFF)),
      ),
    );
  }
}

/// [r] rounded to the half point the cuts are sent at.
String _rounded(Rect r) {
  String h(double v) => ((v * 2).roundToDouble() / 2).toStringAsFixed(1);
  return '${h(r.left)},${h(r.top)},${h(r.right)},${h(r.bottom)}';
}
