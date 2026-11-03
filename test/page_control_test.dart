import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a controlled [CNPageControl] whose page follows its onChanged.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    this.pages = 5,
    this.initial = 2,
    this.enabled = true,
    this.continuous = true,
    this.hidesForSinglePage = false,
  });

  final int pages;
  final int initial;
  final bool enabled;
  final bool continuous;
  final bool hidesForSinglePage;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int page = widget.initial;
  late int pages = widget.pages;
  final picks = <int>[];

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: Center(
      child: SizedBox(
        width: 300,
        child: CNPageControl(
          numberOfPages: pages,
          currentPage: page,
          enabled: widget.enabled,
          allowsContinuousInteraction: widget.continuous,
          hidesForSinglePage: widget.hidesForSinglePage,
          semanticLabel: 'Slides',
          onChanged: (p) {
            picks.add(p);
            setState(() => page = p);
          },
        ),
      ),
    ),
  );
}

/// A PageView with a CNPageControl driving it through its controller.
class _PagerHost extends StatelessWidget {
  const _PagerHost({required this.controller, required this.picks});

  final PageController controller;
  final List<int> picks;

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView(
            controller: controller,
            children: [
              for (var i = 0; i < 5; i++) Center(child: Text('Slide $i')),
            ],
          ),
        ),
        SizedBox(
          width: 300,
          child: CNPageControl(
            numberOfPages: 5,
            controller: controller,
            semanticLabel: 'Slides',
            onChanged: picks.add,
          ),
        ),
      ],
    ),
  );
}

void main() {
  group('CNPageControl drawn in Flutter', () {
    // The test host takes the Flutter page control on Android, as on macOS.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    Offset dotsCenter(WidgetTester tester) =>
        tester.getCenter(find.byType(CNPageControl));

    testWidgets('reads its label and page, and pages with swipes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Slides')),
        isSemantics(
          label: 'Slides',
          value: 'Page 3 of 5',
          increasedValue: 'Page 4 of 5',
          decreasedValue: 'Page 2 of 5',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Slides'));
      await tester.pump();
      expect(key.currentState!.picks, [3]);
      semantics.dispose();
    }, variant: android);

    testWidgets('a tap beside the current dot moves one page that way', (
      tester,
    ) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final center = dotsCenter(tester);
      // Page 2 of 5 is the middle dot.
      await tester.tapAt(center + const Offset(100, 0));
      await tester.pump();
      await tester.tapAt(center - const Offset(100, 0));
      await tester.pump();
      await tester.tapAt(center - const Offset(100, 0));
      await tester.pump();
      expect(key.currentState!.picks, [3, 2, 1]);
    }, variant: android);

    testWidgets('a drag scrubs to the dot under the finger', (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final center = dotsCenter(tester);
      final gesture = await tester.startGesture(center);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      // Two dots to the left of the middle one, one at a time.
      expect(key.currentState!.picks, [1, 0]);
    }, variant: android);

    testWidgets('without continuous interaction a drag does nothing', (
      tester,
    ) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, continuous: false));
      await tester.dragFrom(dotsCenter(tester), const Offset(-60, 0));
      await tester.pump();
      expect(key.currentState!.picks, isEmpty);
    }, variant: android);

    testWidgets('a disabled control ignores taps and has no actions', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, enabled: false));
      await tester.tapAt(dotsCenter(tester) + const Offset(100, 0));
      await tester.pump();
      expect(key.currentState!.picks, isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Slides')),
        isSemantics(
          label: 'Slides',
          value: 'Page 3 of 5',
          hasEnabledState: true,
          isEnabled: false,
          hasIncreaseAction: false,
          hasDecreaseAction: false,
        ),
      );
      semantics.dispose();
    }, variant: android);

    testWidgets(
      'shows at most ten dots, and none for a hidden single page',
      (tester) async {
        final key = GlobalKey<_HostState>();
        await tester.pumpWidget(_Host(key: key, pages: 30, initial: 17));
        Iterable<AnimatedContainer> dots() => tester
            .widgetList<AnimatedContainer>(
              find.descendant(
                of: find.byType(CNPageControl),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .where((c) => c.decoration is BoxDecoration)
            .where(
              (c) => (c.decoration! as BoxDecoration).shape == BoxShape.circle,
            );
        expect(dots().length, 10);

        await tester.pumpWidget(
          const _Host(pages: 1, initial: 0, hidesForSinglePage: true),
        );
        expect(dots(), isEmpty);
      },
      variant: android,
    );

    testWidgets('follows a PageView and animates it on a tap', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = PageController();
      addTearDown(controller.dispose);
      final picks = <int>[];
      await tester.pumpWidget(_PagerHost(controller: controller, picks: picks));

      // A swipe on the PageView moves the dots.
      await tester.fling(find.text('Slide 0'), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Slides')),
        isSemantics(label: 'Slides', value: 'Page 2 of 5'),
      );
      expect(picks, isEmpty, reason: 'a swipe is not a pick on the dots');

      // A tap on the dots animates the PageView.
      await tester.tapAt(
        tester.getCenter(find.byType(CNPageControl)) + const Offset(100, 0),
      );
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Slides')),
        isSemantics(label: 'Slides', value: 'Page 3 of 5'),
        reason: 'the dot moves at once, not page by page behind the PageView',
      );
      await tester.pumpAndSettle();
      expect(controller.page, 2);
      expect(picks, [2]);
      semantics.dispose();
    }, variant: android);
  });

  group('CNPageControl native', () {
    late List<MethodCall> calls;
    late int viewId;

    void mockNative(WidgetTester tester) {
      calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
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
          MethodChannel('CupertinoNativePageControl_$id'),
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
            MethodChannel('CupertinoNativePageControl_$id'),
            null,
          );
        }
      });
    }

    /// Removes the view and the platform override inside the test body, as
    /// the binding checks the override is unset when the body returns.
    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }

    Map<Object?, Object?> creationParams() {
      final create = calls.lastWhere((c) => c.method == 'create');
      final bytes = (create.arguments as Map)['params'] as Uint8List;
      return const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(bytes),
          )
          as Map<Object?, Object?>;
    }

    List<String> sent() => [
      for (final c in calls)
        if (c.method != 'create') '${c.method} ${c.arguments}',
    ];

    Future<void> nativePick(
      WidgetTester tester,
      int page, {
      bool continuous = false,
    }) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'CupertinoNativePageControl_$viewId',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('pageChanged', {'page': page, 'continuous': continuous}),
      ),
      (_) {},
    );

    testWidgets(
      'creates the view with every option and the theme dot colours',
      (tester) async {
        mockNative(tester);
        await tester.pumpWidget(const _Host());
        await tester.pumpAndSettle();
        expect(creationParams(), {
          'numberOfPages': 5,
          'currentPage': 2,
          'backgroundStyle': 'automatic',
          'hidesForSinglePage': false,
          'allowsContinuousInteraction': true,
          'enabled': true,
          'semanticLabel': 'Slides',
          'isDark': false,
          'style': {
            // CupertinoColors.tertiaryLabel and label, light.
            'pageIndicatorTint': 0x4C3C3C43,
            'currentPageIndicatorTint': 0xFF000000,
          },
        });
        expect(tester.getSize(find.byType(UiKitView)).width, 300);
        expect(sent(), isEmpty, reason: 'nothing changed since creation');
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'has a finite width in a Row, and sends the count before the page',
      (tester) async {
        mockNative(tester);
        final count = ValueNotifier<int>(3);
        await tester.pumpWidget(
          CupertinoApp(
            home: Row(
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: count,
                  builder: (_, n, _) => CNPageControl(
                    numberOfPages: n,
                    currentPage: n - 1,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final width = tester.getSize(find.byType(UiKitView)).width;
        expect(width, greaterThan(3 * 16));
        expect(width, lessThan(120));

        count.value = 6;
        await tester.pumpAndSettle();
        expect(sent(), [
          'setNumberOfPages {numberOfPages: 6}',
          'setCurrentPage {currentPage: 5}',
        ]);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'a native tap animates the PageView without stepping the dots back',
      (tester) async {
        mockNative(tester);
        final controller = PageController();
        addTearDown(controller.dispose);
        final picks = <int>[];
        await tester.pumpWidget(
          _PagerHost(controller: controller, picks: picks),
        );
        await tester.pumpAndSettle();

        await nativePick(tester, 3);
        await tester.pumpAndSettle();
        expect(controller.page, 3);
        expect(picks, [3]);
        expect(
          sent(),
          isEmpty,
          reason: 'the pages the animation passes are not sent to the dots',
        );

        // A scrub jumps the PageView.
        await nativePick(tester, 1, continuous: true);
        await tester.pump();
        expect(controller.page, 1);

        // A swipe on the PageView moves the native dots.
        await tester.fling(find.text('Slide 1'), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
        expect(sent(), ['setCurrentPage {currentPage: 2}']);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
