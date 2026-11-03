import 'package:cupertino_native_better/components/tab_badge.dart';
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

  group('CNTabBar fallback badges', () {
    const items = [
      CNTabBarItem(label: 'Home', icon: CNSymbol('house'), badge: '3'),
      CNTabBarItem(label: 'Inbox', icon: CNSymbol('tray'), badge: '99+'),
      CNTabBarItem(
        label: 'Alerts',
        icon: CNSymbol('bell'),
        badge: CNTabBarItem.dotBadge,
      ),
      CNTabBarItem(label: 'People', icon: CNSymbol('person'), badge: ''),
      CNTabBarItem(label: 'Settings', icon: CNSymbol('gear')),
    ];

    Future<void> pumpBar(
      WidgetTester tester,
      List<CNTabBarItem> items, {
      int currentIndex = 0,
      bool search = false,
    }) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                items: items,
                currentIndex: currentIndex,
                onTap: (_) {},
                searchItem: search ? const CNTabBarSearchItem() : null,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    final dots = find.byType(TabBadgeDot);
    final badges = find.byType(TabBadge);

    for (final search in [false, true]) {
      final bar = search ? 'with searchItem' : 'without searchItem';

      testWidgets('$bar: counts and a dot show; null and empty do not', (
        tester,
      ) async {
        await pumpBar(tester, items, search: search);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('99+'), findsOneWidget);
        expect(badges, findsNWidgets(2));
        // The dot draws no count.
        expect(dots, findsOneWidget);
        expect(find.text(CNTabBarItem.dotBadge), findsNothing);
        expect(
          find.descendant(of: dots, matching: find.byType(Text)),
          findsNothing,
        );
      });

      testWidgets('$bar: VoiceOver reads the count, not the dot', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpBar(tester, items, search: search);
        expect(find.bySemanticsLabel(RegExp('Home')), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel(RegExp('Home'))).value,
          '3',
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(RegExp('Inbox'))).value,
          '99+',
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(RegExp('Alerts'))).value,
          isEmpty,
        );
        handle.dispose();
      });

      testWidgets('$bar: a badge stays put when its tab is selected', (
        tester,
      ) async {
        await pumpBar(tester, items, currentIndex: 1, search: search);
        final unselected = tester.getRect(badges.first);
        await pumpBar(tester, items, currentIndex: 0, search: search);
        expect(tester.getRect(badges.first), unselected);
      });

      testWidgets('$bar: a badge changed at runtime is redrawn', (
        tester,
      ) async {
        await pumpBar(tester, items, search: search);
        await pumpBar(tester, [
          for (final item in items)
            CNTabBarItem(
              label: item.label,
              icon: item.icon,
              badge: item.label == 'Home' ? null : '7',
            ),
        ], search: search);
        expect(find.text('3'), findsNothing);
        expect(find.text('7'), findsNWidgets(4));
        expect(dots, findsNothing);
      });

      testWidgets('$bar: adding or clearing a badge keeps the icon', (
        tester,
      ) async {
        const plain = [
          CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
          CNTabBarItem(label: 'Inbox', icon: CNSymbol('tray')),
        ];
        Element homeIcon() => tester.element(find.byType(CNIcon).first);
        await pumpBar(tester, plain, search: search);
        final before = homeIcon();
        await pumpBar(tester, [
          const CNTabBarItem(
            label: 'Home',
            icon: CNSymbol('house'),
            badge: '1',
          ),
          plain[1],
        ], search: search);
        expect(badges, findsOneWidget);
        expect(homeIcon(), same(before));
        await pumpBar(tester, plain, search: search);
        expect(badges, findsNothing);
        expect(homeIcon(), same(before));
      });

      testWidgets('$bar: right to left puts the badge on the leading side', (
        tester,
      ) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: CupertinoPageScaffold(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: CNTabBar(
                    items: const [
                      CNTabBarItem(
                        label: 'Home',
                        icon: CNSymbol('house'),
                        badge: '3',
                      ),
                      CNTabBarItem(label: 'Inbox', icon: CNSymbol('tray')),
                    ],
                    currentIndex: 0,
                    onTap: (_) {},
                    searchItem: search ? const CNTabBarSearchItem() : null,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        final icon = tester.getRect(find.byType(CNIcon).first);
        final badge = tester.getRect(badges.first);
        expect(badge.center.dx, lessThan(icon.center.dx));
      });
    }
  });
}
