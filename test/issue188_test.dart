import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart' show CupertinoSheetRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'native_view_finder.dart';

/// #188: the Material dropdown and popup menu routes start their page with a
/// `LayoutBuilder` as big as the screen. The modal measure didn't see through
/// it, so the menu counted as the whole screen and every CN widget with
/// `autoHideOnModal: true` hid.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  const screen = Rect.fromLTWH(0, 0, 800, 600);

  Widget app(GlobalKey<NavigatorState> navigator, Widget page) {
    return MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [CNTabBarRouteObserver()],
      home: page,
    );
  }

  Rect measured() => CNTabBarRouteObserver.routeModalRect.value!;

  Future<void> close(
    WidgetTester tester,
    GlobalKey<NavigatorState> navigator,
  ) async {
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(CNTabBarRouteObserver.routeModalRect.value, isNull);
  }

  testWidgets('the dropdown menu is measured as the menu, not the screen', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      app(
        navigator,
        Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 300),
              DropdownButton<String>(
                value: 'Apple',
                items: const [
                  DropdownMenuItem(value: 'Apple', child: Text('Apple')),
                  DropdownMenuItem(value: 'Banana', child: Text('Banana')),
                ],
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    final rect = measured();
    expect(rect, isNot(screen));
    expect(rect.width, lessThan(200));
    expect(rect.top, greaterThan(200), reason: 'well below the top');
    // The menu's rows are inside it.
    for (final row in [find.text('Apple').last, find.text('Banana').last]) {
      final r = tester.getRect(row);
      expect(rect.contains(r.topLeft) && rect.contains(r.bottomRight), isTrue);
    }
    await close(tester, navigator);
  });

  testWidgets('the popup menu is measured as the menu, not the screen', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final popup = GlobalKey<PopupMenuButtonState<String>>();
    await tester.pumpWidget(
      app(
        navigator,
        Scaffold(
          body: Center(
            child: PopupMenuButton<String>(
              key: popup,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'a', child: Text('Item A')),
                PopupMenuItem(value: 'b', child: Text('Item B')),
              ],
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    popup.currentState!.showButtonMenu();
    await tester.pumpAndSettle();

    final rect = measured();
    expect(rect, isNot(screen));
    expect(rect.width, lessThan(300));
    expect(rect.height, lessThan(200));
    final row = tester.getRect(find.text('Item B'));
    expect(rect.contains(row.center), isTrue);
    await close(tester, navigator);
  });

  testWidgets('any route page that starts with a LayoutBuilder is seen into', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigator, const Scaffold()));
    showGeneralDialog<void>(
      context: navigator.currentContext!,
      pageBuilder: (_, _, _) => LayoutBuilder(
        builder: (_, _) => const Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(measured(), const Rect.fromLTWH(350, 260, 100, 80));
    await close(tester, navigator);
  });

  testWidgets(
    'framework sheet routes count as sheets whatever their class is named',
    (tester) async {
      // `--obfuscate` renames classes, so a name test can't find these.
      // Subclasses with other names stand in for that.
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(navigator, const Scaffold()));
      final context = navigator.currentContext!;

      navigator.currentState!.push(
        _Renamed<void>(
          builder: (_) => const SizedBox(height: 200),
          isScrollControlled: false,
          capturedThemes: InheritedTheme.capture(from: context, to: null),
        ),
      );
      await tester.pumpAndSettle();
      expect(CNTabBarRouteObserver.modalDepth.value, 1);
      expect(CNTabBarRouteObserver.anyModalDepth.value, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      navigator.currentState!.push(
        _RenamedCupertino<void>(
          scrollableBuilder: (_, _) => const SizedBox.expand(),
        ),
      );
      await tester.pumpAndSettle();
      expect(CNTabBarRouteObserver.modalDepth.value, 1);
      expect(CNTabBarRouteObserver.anyModalDepth.value, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(CNTabBarRouteObserver.modalDepth.value, 0);
      expect(CNTabBarRouteObserver.anyModalDepth.value, 0);
    },
  );

  testWidgets(
    'glass buttons in the app bar stay while the dropdown menu is open',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeButton_$id'),
          (_) async => null,
        );
      }
      final navigator = GlobalKey<NavigatorState>();
      Widget button(String key, String symbol) => SizedBox(
        width: 44,
        height: 44,
        child: CNButton.icon(
          key: Key(key),
          icon: CNSymbol(symbol),
          onPressed: () {},
        ),
      );
      await tester.pumpWidget(
        app(
          navigator,
          Scaffold(
            appBar: AppBar(
              leading: Center(child: button('leading', 'chevron.left')),
              actions: [button('action', 'ellipsis')],
            ),
            body: Center(
              child: DropdownButton<String>(
                value: 'Apple',
                items: const [
                  DropdownMenuItem(value: 'Apple', child: Text('Apple')),
                  DropdownMenuItem(value: 'Banana', child: Text('Banana')),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(findNativeView(), findsNWidgets(2));

      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(CNTabBarRouteObserver.anyModalDepth.value, 1);
      for (final key in ['leading', 'action']) {
        expect(
          find.descendant(of: find.byKey(Key(key)), matching: findNativeView()),
          findsOneWidget,
          reason: 'the menu is nowhere near the $key button',
        );
      }

      await close(tester, navigator);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeButton_$id'),
          null,
        );
      }
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      debugDefaultTargetPlatformOverride = null;
    },
    skip: skip || !PlatformVersion.shouldUseNativeGlass,
  );
}

class _Renamed<T> extends ModalBottomSheetRoute<T> {
  _Renamed({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
  });
}

class _RenamedCupertino<T> extends CupertinoSheetRoute<T> {
  _RenamedCupertino({required super.scrollableBuilder});
}
