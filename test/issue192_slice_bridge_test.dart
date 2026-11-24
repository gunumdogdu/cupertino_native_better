import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/slice_bridge.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #192: with two native views live under a modal, the Flutter content the
/// modal paints after a native view of its own fell into the engine's
/// overlay span and wasn't painted. A native view in such a modal now draws
/// a screen-sized hairline outside the screen right after itself and in the
/// route's overlay ([CNSliceBridge]).
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  const dialogKey = Key('dialog');
  const bridgePaint = Color(0x01000000);

  void listen(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    for (var id = 0; id < 40; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativeSwitch_$id'),
        (_) async => null,
      );
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeSwitch_$id'),
          null,
        );
      }
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget nativeSwitch({bool autoHideOnModal = false}) => CNSwitch(
    value: true,
    autoHideOnModal: autoHideOnModal,
    onChanged: (_) {},
  );

  /// A page with [count] live switches spread from top to bottom.
  Future<GlobalKey<NavigatorState>> pumpPage(
    WidgetTester tester, {
    required int count,
    bool autoHideOnModal = false,
    bool centred = false,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    listen(tester);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        navigatorObservers: [CNTabBarRouteObserver()],
        home: CupertinoPageScaffold(
          child: Column(
            mainAxisAlignment: centred
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < count; i++)
                Center(child: nativeSwitch(autoHideOnModal: autoHideOnModal)),
            ],
          ),
        ),
      ),
    );
    await settle(tester);
    return navigator;
  }

  Future<void> openDialog(GlobalKey<NavigatorState> navigator) async {
    showCupertinoDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => Center(
        child: SizedBox(
          key: dialogKey,
          width: 300,
          height: 200,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: Column(
              children: [
                nativeSwitch(),
                const SizedBox(height: 20),
                const Text('Below the switch'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> close(
    WidgetTester tester,
    GlobalKey<NavigatorState> navigator,
  ) async {
    navigator.currentState!.pop();
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  Finder named(String type, {Finder? within}) {
    final finder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == type,
      skipOffstage: false,
    );
    return within == null
        ? finder
        : find.descendant(of: within, matching: finder, skipOffstage: false);
  }

  final drawsBridge = paints
    ..rect(color: bridgePaint, style: PaintingStyle.stroke);

  testWidgets(
    'a native view in a dialog draws the bridge over two live views below',
    (tester) async {
      final navigator = await pumpPage(tester, count: 2);
      expect(CNSliceBridge.debugLiveCount, 2);
      await openDialog(navigator);
      await settle(tester);
      expect(CNSliceBridge.debugLiveCount, 3);

      // Right after the native view, outside the switch's own clip...
      final inDialog = named('_SliceBridge', within: find.byKey(dialogKey));
      expect(inDialog, findsOneWidget);
      expect(tester.renderObject(inDialog), drawsBridge);
      // ...and from the route's overlay, outside every clip.
      final overlay = named('_OverlayBridge');
      expect(overlay, findsOneWidget);
      expect(tester.renderObject(overlay), drawsBridge);

      // The views on the page draw nothing: their route is opaque.
      for (final element in named('_SliceBridge').evaluate()) {
        final ro = element.renderObject!;
        if (identical(ro, tester.renderObject(inDialog))) continue;
        expect(ro, isNot(drawsBridge));
      }
      await close(tester, navigator);
      expect(CNSliceBridge.debugLiveCount, 0);
    },
    skip: skip,
  );

  testWidgets('with one live view below there is no span: nothing drawn', (
    tester,
  ) async {
    final navigator = await pumpPage(tester, count: 1);
    await openDialog(navigator);
    await settle(tester);
    final inDialog = named('_SliceBridge', within: find.byKey(dialogKey));
    expect(tester.renderObject(inDialog), isNot(drawsBridge));
    expect(tester.renderObject(named('_OverlayBridge')), isNot(drawsBridge));
    await close(tester, navigator);
  }, skip: skip);

  testWidgets('views the dialog hides (autoHideOnModal) do not count', (
    tester,
  ) async {
    // Two switches in the middle of the page, under the dialog.
    final navigator = await pumpPage(
      tester,
      count: 2,
      autoHideOnModal: true,
      centred: true,
    );
    expect(CNSliceBridge.debugLiveCount, 2);
    await openDialog(navigator);
    await settle(tester);
    expect(CNSliceBridge.debugLiveCount, 1, reason: 'only the dialog view');
    final inDialog = named('_SliceBridge', within: find.byKey(dialogKey));
    expect(tester.renderObject(inDialog), isNot(drawsBridge));
    await close(tester, navigator);
  }, skip: skip);

  testWidgets('the dialog is still measured as its card, not the screen', (
    tester,
  ) async {
    final navigator = await pumpPage(tester, count: 2);
    await openDialog(navigator);
    await settle(tester);
    expect(tester.renderObject(named('_OverlayBridge')), drawsBridge);
    expect(
      CNTabBarRouteObserver.routeModalRect.value,
      tester.getRect(find.byKey(dialogKey)),
    );
    await close(tester, navigator);
  }, skip: skip);
}
