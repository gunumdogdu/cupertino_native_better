import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #156: a glass widget with `autoHideOnModal: false` under a sheet from a
/// sheet package stayed flat (contained) the whole time the sheet was up,
/// because the sheet's route was measured as covering the whole screen: the
/// package wraps its sheet in an `OverlayPortal` and a full-screen gesture
/// detector, which the measurement didn't know paint only their child. And
/// a dialog far from the widget clipped its glass while it faded in and out.

/// A sheet route built like the sheet packages build theirs: a full-screen
/// `OverlayPortal` (a status bar tap handler) and drag detector around a
/// 300 pt sheet at the bottom.
class _PackageStyleSheetRoute extends PopupRoute<void> {
  final OverlayPortalController _portal = OverlayPortalController();

  @override
  Color? get barrierColor => const Color(0x33000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (_) => const SizedBox.shrink(),
      child: GestureDetector(
        onVerticalDragUpdate: (_) {},
        child: TapRegion(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 300, color: const Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }
}

/// The page scale a [_PageScalingSheetRoute] drives, as sheet packages
/// scale the page under their sheet down while it comes and goes.
final ValueNotifier<double> _pageScale = ValueNotifier<double>(1);

class _PageScalingSheetRoute extends _PackageStyleSheetRoute {
  @override
  TickerFuture didPush() {
    animation!.addListener(() => _pageScale.value = 1 - 0.1 * animation!.value);
    return super.didPush();
  }

  /// Moves the sheet as a finger dragging it does: the package sets its
  /// controller's value directly.
  void dragTo(double value) => controller!.value = value;

  /// Lets go: the sheet springs back up.
  void release() => controller!.forward();
}

void main() {
  final sent = <String, List<bool>>{};
  final navigator = GlobalKey<NavigatorState>();

  void mockNative(WidgetTester tester) {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    for (var id = 0; id < 40; id++) {
      final name = 'CupertinoNativeButton_$id';
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (call.method == 'setTransitioning') {
          (sent[name] ??= <bool>[]).add((call.arguments as Map)['active']);
        }
        return null;
      });
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeButton_$id'),
          null,
        );
      }
    });
  }

  Widget app(Widget home) => CupertinoApp(
    navigatorKey: navigator,
    navigatorObservers: <NavigatorObserver>[CNTabBarRouteObserver()],
    home: home,
  );

  setUp(sent.clear);

  testWidgets('the sheet is measured, not the full-screen wrappers around it', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const CupertinoPageScaffold(child: SizedBox())),
    );
    navigator.currentState!.push(_PackageStyleSheetRoute());
    await tester.pumpAndSettle();
    // 300 pt at the bottom of the 800 by 600 test screen.
    expect(
      CNTabBarRouteObserver.routeModalRect.value,
      const Rect.fromLTRB(0, 300, 800, 600),
    );
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(CNTabBarRouteObserver.routeModalRect.value, isNull);
  });

  testWidgets(
    'a glass button above that sheet keeps its full glass while the sheet '
    'is up',
    (tester) async {
      mockNative(tester);
      await tester.pumpWidget(
        app(
          CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CNButton.icon(
                  icon: const CNSymbol('xmark'),
                  autoHideOnModal: false,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final name = sent.keys.single;
      sent.clear();

      navigator.currentState!.push(_PackageStyleSheetRoute());
      await tester.pumpAndSettle();
      expect(sent[name], isNull, reason: 'never clipped: full glass');
      expect(find.byType(UiKitView), findsOneWidget);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(sent[name], isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'a dialog away from the button leaves its full glass while it fades in '
    'and out',
    (tester) async {
      mockNative(tester);
      await tester.pumpWidget(
        app(
          CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CNButton.icon(
                  icon: const CNSymbol('xmark'),
                  autoHideOnModal: false,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final name = sent.keys.single;
      sent.clear();

      showCupertinoDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: 200,
            height: 300,
            child: ColoredBox(color: Color(0xFFFFFFFF)),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect(sent[name], isNull, reason: 'not clipped as it fades in, or up');

      navigator.currentState!.pop();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect(sent[name], isNull, reason: 'or as it fades out');
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  Widget scalingPage() => app(
    ValueListenableBuilder<double>(
      valueListenable: _pageScale,
      builder: (_, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: CupertinoPageScaffold(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CNButton.icon(
              icon: const CNSymbol('xmark'),
              autoHideOnModal: false,
              onPressed: () {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'a sheet that scales the page under it leaves the glass full as it comes '
    'and goes',
    (tester) async {
      mockNative(tester);
      await tester.pumpWidget(scalingPage());
      await tester.pumpAndSettle();
      final name = sent.keys.single;
      sent.clear();

      navigator.currentState!.push(_PageScalingSheetRoute());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(_pageScale.value, lessThan(1), reason: 'the page moves');
      expect(sent[name], isNull, reason: 'never clipped: full glass');
      await tester.pumpAndSettle();
      expect(sent[name], isNull);

      navigator.currentState!.pop();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect(sent[name], isNull);
      await tester.pumpWidget(const SizedBox());
      _pageScale.value = 1;
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'a sheet held mid-drag leaves the glass full while it moves the page and '
    'for as long as the finger holds it',
    (tester) async {
      mockNative(tester);
      await tester.pumpWidget(scalingPage());
      await tester.pumpAndSettle();
      final name = sent.keys.single;
      final route = _PageScalingSheetRoute();
      navigator.currentState!.push(route);
      await tester.pumpAndSettle();
      sent.clear();

      // The finger drags the sheet down part-way and holds it there.
      for (var v = 0.98; v > 0.6; v -= 0.02) {
        route.dragTo(v);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(seconds: 2));
      expect(route.animation!.status, AnimationStatus.forward);
      expect(_pageScale.value, lessThan(1));
      expect(sent[name], isNull, reason: 'full glass mid-drag');

      // Lets go: it springs back up.
      route.release();
      await tester.pumpAndSettle();
      expect(sent[name], isNull);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      _pageScale.value = 1;
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets(
    'no clip the size of the glass view around it: under a scaled page the '
    'engine would mask the view to its bounds and box the glow',
    (tester) async {
      mockNative(tester);
      await tester.pumpWidget(
        app(
          CupertinoPageScaffold(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CNButton.icon(
                    icon: const CNSymbol('xmark'),
                    onPressed: () {},
                  ),
                  CNPopupMenuButton.icon(
                    buttonIcon: const CNSymbol('ellipsis'),
                    items: const [CNPopupMenuItem(label: 'One')],
                    onSelected: (_) {},
                  ),
                  SizedBox(
                    width: 200,
                    child: CNGlassButtonGroup(
                      buttons: [
                        CNButtonData.icon(
                          icon: const CNSymbol('plus'),
                          onPressed: () {},
                        ),
                        CNButtonData.icon(
                          icon: const CNSymbol('minus'),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final views = find.byType(UiKitView);
      expect(views, findsNWidgets(3));
      expect(
        find.ancestor(of: views, matching: find.byType(ClipRect)),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );

  testWidgets('a sliding sheet is measured where it will be next frame', (
    tester,
  ) async {
    const sheet = Key('sheet');
    await tester.pumpWidget(
      app(const CupertinoPageScaffold(child: SizedBox())),
    );
    showCupertinoModalPopup<void>(
      context: navigator.currentContext!,
      builder: (_) =>
          Container(key: sheet, height: 300, color: const Color(0xFFFFFFFF)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final painted = tester.getRect(find.byKey(sheet));
    final measured = CNTabBarRouteObserver.routeModalRect.value!;
    expect(painted.top, lessThan(600), reason: 'on its way in');
    expect(measured.top, lessThan(painted.top), reason: 'ahead of it');
    expect(measured.bottom, greaterThanOrEqualTo(painted.bottom));

    await tester.pumpAndSettle();
    expect(
      CNTabBarRouteObserver.routeModalRect.value,
      tester.getRect(find.byKey(sheet)),
      reason: 'exact at rest',
    );
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
  });
}
