import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the native side sends for an iPhone Duo in the book pose: the device
/// partially open, the fold active and vertical, the camera on the right.
Map<Object?, Object?> _bookPose() => <Object?, Object?>{
  'supported': true,
  'attached': true,
  'width': 669.0,
  'height': 951.0,
  'verticalBarSide': 'none',
  'hinge': <Object?, Object?>{'status': 'partiallyOpen', 'angle': math.pi / 2},
  'regions': <Object?>[
    <Object?, Object?>{
      'kind': 'division',
      'x': 324.0,
      'y': 0.0,
      'width': 20.0,
      'height': 951.0,
      'marginTop': 0.0,
      'marginLeft': 8.0,
      'marginBottom': 0.0,
      'marginRight': 8.0,
      'active': true,
    },
    <Object?, Object?>{
      'kind': 'occlusion',
      'x': 600.0,
      'y': 10.0,
      'width': 40.0,
      'height': 40.0,
      'marginTop': 0.0,
      'marginLeft': 0.0,
      'marginBottom': 0.0,
      'marginRight': 0.0,
      'active': true,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => CNFoldable.debugSetState(CNFoldableState.unsupported));

  group('CNFoldableState.fromMap', () {
    test('null or unsupported maps to unsupported', () {
      expect(CNFoldableState.fromMap(null), CNFoldableState.unsupported);
      expect(
        CNFoldableState.fromMap(<Object?, Object?>{'supported': false}),
        CNFoldableState.unsupported,
      );
    });

    test('parses hinge, vertical bar and regions', () {
      final state = CNFoldableState.fromMap(_bookPose());

      expect(state.isSupported, isTrue);
      expect(state.isFoldable, isTrue);
      expect(state.hinge!.status, CNHingeStatus.partiallyOpen);
      expect(state.hinge!.degrees, closeTo(90, 0.001));
      expect(state.verticalBarSide, CNVerticalBarSide.none);
      expect(state.hasVerticalBar, isFalse);
      expect(state.regions, hasLength(2));

      final fold = state.activeFold!;
      expect(fold.kind, CNReservedRegionKind.division);
      expect(fold.frame, const Rect.fromLTWH(324, 0, 20, 951));
      expect(fold.margins, const EdgeInsets.fromLTRB(8, 0, 8, 0));
      expect(fold.isHorizontal, isFalse);
    });

    test('a supported device without a hinge is not foldable', () {
      final state = CNFoldableState.fromMap(<Object?, Object?>{
        'supported': true,
        'verticalBarSide': 'right',
        'regions': <Object?>[],
      });

      expect(state.isSupported, isTrue);
      expect(state.isFoldable, isFalse);
      expect(state.verticalBarSide, CNVerticalBarSide.right);
      expect(state.hasVerticalBar, isTrue);
    });

    test('equal maps give equal states', () {
      expect(
        CNFoldableState.fromMap(_bookPose()),
        CNFoldableState.fromMap(_bookPose()),
      );
    });
  });

  group('displayFeatures', () {
    test('an active fold is a half-opened fold, a camera a cutout', () {
      final features = CNFoldableState.fromMap(_bookPose()).displayFeatures;

      expect(features, hasLength(2));
      expect(features[0].type, DisplayFeatureType.fold);
      expect(features[0].state, DisplayFeatureState.postureHalfOpened);
      expect(features[0].bounds, const Rect.fromLTWH(324, 0, 20, 951));
      expect(features[1].type, DisplayFeatureType.cutout);
    });

    test('an inactive (flat) fold is left out', () {
      final map = _bookPose();
      ((map['regions']! as List<Object?>)[0]!
              as Map<Object?, Object?>)['active'] =
          false;
      final features = CNFoldableState.fromMap(map).displayFeatures;

      expect(features, hasLength(1));
      expect(features.single.type, DisplayFeatureType.cutout);
    });
  });

  group('CNFoldableScope', () {
    testWidgets('adds the regions to MediaQuery.displayFeatures and exposes '
        'the state', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        CNFoldableScope(
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(MediaQuery.of(captured).displayFeatures, isEmpty);
      expect(CNFoldable.of(captured), CNFoldableState.unsupported);

      CNFoldable.debugSetState(CNFoldableState.fromMap(_bookPose()));
      await tester.pump();

      expect(MediaQuery.of(captured).displayFeatures, hasLength(2));
      expect(
        CNFoldable.of(captured).hinge!.status,
        CNHingeStatus.partiallyOpen,
      );
    });
  });

  group('CNTabScaffold', () {
    const items = <CNTabBarItem>[
      CNTabBarItem(label: 'One', icon: CNSymbol('house')),
      CNTabBarItem(label: 'Two', icon: CNSymbol('star')),
    ];

    Widget app({bool sidebar = false, Size size = const Size(400, 800)}) {
      return MediaQuery(
        data: MediaQueryData(size: size),
        child: CupertinoApp(
          home: CNFoldableScope(
            child: CNTabScaffold(
              items: items,
              currentIndex: 0,
              onTap: (_) {},
              sidebarOnWideScreens: sidebar,
              body: const _Counter(),
            ),
          ),
        ),
      );
    }

    // Android, so every widget takes its Flutter fallback in the test host.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('bottom bar by default', (tester) async {
      await tester.pumpWidget(app());
      // Let CNTabBar's deferred setup timer run before teardown.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CNTabBar), findsOneWidget);
      expect(find.byType(CNTabRail), findsNothing);
    }, variant: android);

    testWidgets('rail when the system uses a vertical bar', (tester) async {
      CNFoldable.debugSetState(
        const CNFoldableState(
          isSupported: true,
          verticalBarSide: CNVerticalBarSide.right,
        ),
      );
      await tester.pumpWidget(app());

      expect(find.byType(CNTabBar), findsNothing);
      final rail = tester.widget<CNTabRail>(find.byType(CNTabRail));
      expect(rail.style, CNTabRailStyle.rail);
    }, variant: android);

    testWidgets('sidebar on a wide screen only when opted in', (tester) async {
      tester.view.physicalSize = const Size(700, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(size: const Size(700, 950)));
      expect(find.byType(CNTabBar), findsOneWidget);

      await tester.pumpWidget(app(sidebar: true, size: const Size(700, 950)));
      final rail = tester.widget<CNTabRail>(find.byType(CNTabRail));
      expect(rail.style, CNTabRailStyle.sidebar);
    }, variant: android);

    testWidgets('the body keeps its state when the placement changes', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('count 0'));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);

      CNFoldable.debugSetState(
        const CNFoldableState(
          isSupported: true,
          verticalBarSide: CNVerticalBarSide.right,
        ),
      );
      await tester.pump();

      expect(find.byType(CNTabRail), findsOneWidget);
      expect(find.text('count 1'), findsOneWidget);
    }, variant: android);
  });

  group('CNTabRail', () {
    const home = CNImageAsset('assets/icons/home.svg');
    const homeFilled = CNImageAsset('assets/icons/home_filled.svg');
    const inbox = CNImageAsset('assets/icons/inbox.png');

    Future<List<CNImageAsset?>> assetsShown(
      WidgetTester tester,
      List<CNTabBarItem> items, {
      int currentIndex = 0,
    }) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNTabRail(
              items: items,
              currentIndex: currentIndex,
              onTap: (_) {},
            ),
          ),
        ),
      );
      return tester
          .widgetList<CNIcon>(find.byType(CNIcon))
          .map((icon) => icon.imageAsset)
          .toList();
    }

    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('draws image assets, the active one when selected', (
      tester,
    ) async {
      final shown = await assetsShown(tester, const [
        CNTabBarItem(
          label: 'Home',
          imageAsset: home,
          activeImageAsset: homeFilled,
        ),
        CNTabBarItem(label: 'Inbox', imageAsset: inbox),
      ]);
      expect(shown, [homeFilled, inbox]);
    }, variant: android);

    testWidgets('a selected item without an active asset keeps its asset', (
      tester,
    ) async {
      final shown = await assetsShown(tester, const [
        CNTabBarItem(label: 'Home', imageAsset: home),
        CNTabBarItem(label: 'Inbox', imageAsset: inbox),
      ], currentIndex: 1);
      expect(shown, [home, inbox]);
    }, variant: android);

    testWidgets('an image asset takes precedence over an SF Symbol', (
      tester,
    ) async {
      final shown = await assetsShown(tester, const [
        CNTabBarItem(
          label: 'Home',
          icon: CNSymbol('house'),
          imageAsset: home,
        ),
        CNTabBarItem(label: 'Star', icon: CNSymbol('star')),
      ]);
      expect(shown, [home, null]);
    }, variant: android);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _count++),
        child: Text('count $_count'),
      ),
    );
  }
}
