import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The test host is not iOS 26, so CNTabBar and CNTabRail draw their Flutter
  // fallbacks.

  group('CNTabBar fallback image assets (#104)', () {
    const tint = Color(0xFFFF2D55);

    Future<List<CNImageAsset>> assetsShown(
      WidgetTester tester,
      List<CNTabBarItem> items,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                items: items,
                currentIndex: 0,
                onTap: (_) {},
                tint: tint,
              ),
            ),
          ),
        ),
      );
      // Drain PlatformViewGuard's debounce timer.
      await tester.pump(const Duration(milliseconds: 600));
      return tester
          .widgetList<CNIcon>(find.byType(CNIcon))
          .map((icon) => icon.imageAsset)
          .whereType<CNImageAsset>()
          .toList();
    }

    testWidgets('take the bar colours, as the native bar tints them', (
      tester,
    ) async {
      final shown = await assetsShown(tester, const [
        CNTabBarItem(
          label: 'Home',
          imageAsset: CNImageAsset('assets/home.svg'),
          activeImageAsset: CNImageAsset('assets/home_filled.svg'),
        ),
        CNTabBarItem(
          label: 'Chat',
          imageAsset: CNImageAsset('assets/chat.svg'),
        ),
      ]);

      expect(shown.map((a) => a.assetPath), [
        'assets/home_filled.svg',
        'assets/chat.svg',
      ]);
      expect(shown[0].color, tint);
      expect(shown[1].color, isNotNull);
      expect(shown[1].color, isNot(tint));
    });

    testWidgets('keep a colour of their own', (tester) async {
      const own = Color(0xFF34C759);
      final shown = await assetsShown(tester, const [
        CNTabBarItem(
          label: 'Home',
          imageAsset: CNImageAsset('assets/home.svg', color: own),
        ),
        CNTabBarItem(
          label: 'Chat',
          imageAsset: CNImageAsset('assets/chat.svg'),
        ),
      ]);
      expect(shown[0].color, own);
    });
  });

  group('CNTabBarItem.dotBadge (#105)', () {
    testWidgets(
      'CNTabRail draws a dot, not a text badge',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: CNTabRail(
                items: const [
                  CNTabBarItem(
                    label: 'Home',
                    icon: CNSymbol('house'),
                    badge: CNTabBarItem.dotBadge,
                  ),
                  CNTabBarItem(
                    label: 'Inbox',
                    icon: CNSymbol('tray'),
                    badge: '3',
                  ),
                ],
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text(CNTabBarItem.dotBadge), findsNothing);
        expect(find.text('3'), findsOneWidget);
        final dots = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 9 &&
              w.constraints?.maxHeight == 9,
        );
        expect(dots, findsOneWidget);
        // A dot has no count to read out.
        expect(
          tester.getSemantics(find.bySemanticsLabel('Home')).value,
          isEmpty,
        );
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });
}
