import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

void main() {
  group('CNSearchBar', () {
    // Helper to build CNSearchBar with proper MediaQuery constraints
    Widget buildSearchBarTest({
      required Widget child,
      Size screenSize = const Size(350, 600),
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: Scaffold(body: child),
        ),
      );
    }

    testWidgets('renders with default placeholder when expanded', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSearchBarTest(
          child: const CNSearchBar(
            expandable: false, // Always show expanded state
            showCancelButton: false, // Avoid overflow
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Flutter fallback should show the text field
      expect(find.byType(CupertinoTextField), findsOneWidget);
    });

    testWidgets('renders with custom placeholder when expanded', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSearchBarTest(
          child: const CNSearchBar(
            placeholder: 'Find items...',
            expandable: false,
            showCancelButton: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CupertinoTextField), findsOneWidget);
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changedText;

      await tester.pumpWidget(
        buildSearchBarTest(
          child: CNSearchBar(
            expandable: false, // Always expanded for easier testing
            showCancelButton: false,
            onChanged: (text) => changedText = text,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.enterText(find.byType(CupertinoTextField), 'test query');
      await tester.pump();

      expect(changedText, 'test query');
    });

    testWidgets('calls onSubmitted when search is submitted', (tester) async {
      String? submittedText;

      await tester.pumpWidget(
        buildSearchBarTest(
          child: CNSearchBar(
            expandable: false,
            showCancelButton: false,
            onSubmitted: (text) => submittedText = text,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.enterText(find.byType(CupertinoTextField), 'search term');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(submittedText, 'search term');
    });

    testWidgets('shows cancel button when expanded', (tester) async {
      await tester.pumpWidget(
        buildSearchBarTest(
          screenSize: const Size(500, 600), // Wider to fit cancel button
          child: const CNSearchBar(
            expandable: false,
            initiallyExpanded: true,
            showCancelButton: true,
            cancelText: 'Cancel',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('CNSearchBarController', () {
    test('creates controller', () {
      final controller = CNSearchBarController();
      expect(controller, isNotNull);
    });

    test('isExpanded defaults to false', () {
      final controller = CNSearchBarController();
      expect(controller.isExpanded, false);
    });
  });

  group('CNFloatingIsland', () {
    testWidgets('renders collapsed content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CNFloatingIsland(
              collapsed: Text('Collapsed'),
              expanded: Text('Expanded'),
            ),
          ),
        ),
      );

      expect(find.text('Collapsed'), findsOneWidget);
    });

    testWidgets('renders with custom position', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CNFloatingIsland(
              collapsed: Text('Bottom'),
              position: CNFloatingIslandPosition.bottom,
            ),
          ),
        ),
      );

      expect(find.text('Bottom'), findsOneWidget);
    });

    testWidgets('responds to tap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNFloatingIsland(
              collapsed: const Text('Tap me'),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('shows expanded content when isExpanded is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CNFloatingIsland(
              collapsed: Text('Collapsed'),
              expanded: Text('Expanded Content'),
              isExpanded: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Expanded Content'), findsOneWidget);
    });
  });

  group('CNFloatingIslandController', () {
    test('creates controller', () {
      final controller = CNFloatingIslandController();
      expect(controller, isNotNull);
    });

    test('isExpanded defaults to false', () {
      final controller = CNFloatingIslandController();
      expect(controller.isExpanded, false);
    });

    test('onExpandChanged callback is settable', () {
      final controller = CNFloatingIslandController();
      var callbackCalled = false;

      controller.onExpandChanged = () => callbackCalled = true;
      expect(callbackCalled, false);
    });
  });

  group('CNFloatingIslandPosition', () {
    test('has top and bottom values', () {
      expect(CNFloatingIslandPosition.values.length, 2);
      expect(
        CNFloatingIslandPosition.values,
        contains(CNFloatingIslandPosition.top),
      );
      expect(
        CNFloatingIslandPosition.values,
        contains(CNFloatingIslandPosition.bottom),
      );
    });
  });

  group('CNGlassButtonGroup', () {
    testWidgets('renders with CNButtonData list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNGlassButtonGroup(
              buttons: [
                CNButtonData(label: 'Button 1'),
                CNButtonData(label: 'Button 2'),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Button 1'), findsOneWidget);
      expect(find.text('Button 2'), findsOneWidget);
    });

    testWidgets('renders icon buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNGlassButtonGroup(
              buttons: [
                CNButtonData.icon(customIcon: Icons.home),
                CNButtonData.icon(customIcon: Icons.settings),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('triggers onPressed callback', (tester) async {
      var button1Pressed = false;
      var button2Pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNGlassButtonGroup(
              buttons: [
                CNButtonData(
                  label: 'Button 1',
                  onPressed: () => button1Pressed = true,
                ),
                CNButtonData(
                  label: 'Button 2',
                  onPressed: () => button2Pressed = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.text('Button 1'));
      await tester.pump();
      expect(button1Pressed, true);
      expect(button2Pressed, false);

      await tester.tap(find.text('Button 2'));
      await tester.pump();
      expect(button2Pressed, true);
    });

    testWidgets('renders in vertical axis', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNGlassButtonGroup(
              axis: Axis.vertical,
              buttons: [
                CNButtonData(label: 'Top'),
                CNButtonData(label: 'Bottom'),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
    });

    testWidgets('renders with custom spacing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNGlassButtonGroup(
              spacing: 16.0,
              spacingForGlass: 50.0,
              buttons: [
                CNButtonData(label: 'A'),
                CNButtonData(label: 'B'),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('LiquidGlassConfig', () {
    test('creates config with defaults', () {
      const config = LiquidGlassConfig();

      expect(config.effect, CNGlassEffect.regular);
      expect(config.shape, CNGlassEffectShape.capsule);
      expect(config.cornerRadius, isNull);
      expect(config.tint, isNull);
      expect(config.interactive, false);
    });

    test('creates config with custom values', () {
      const config = LiquidGlassConfig(
        effect: CNGlassEffect.prominent,
        shape: CNGlassEffectShape.capsule,
        cornerRadius: 16.0,
        tint: Colors.blue,
        interactive: true,
      );

      expect(config.effect, CNGlassEffect.prominent);
      expect(config.shape, CNGlassEffectShape.capsule);
      expect(config.cornerRadius, 16.0);
      expect(config.tint, Colors.blue);
      expect(config.interactive, true);
    });
  });

  group('CNGlassEffect', () {
    test('has all expected values', () {
      expect(CNGlassEffect.values.length, 2);
      expect(CNGlassEffect.values, contains(CNGlassEffect.regular));
      expect(CNGlassEffect.values, contains(CNGlassEffect.prominent));
    });
  });

  group('CNGlassEffectShape', () {
    test('has all expected values', () {
      expect(CNGlassEffectShape.values.length, 3);
      expect(CNGlassEffectShape.values, contains(CNGlassEffectShape.capsule));
      expect(CNGlassEffectShape.values, contains(CNGlassEffectShape.rect));
      expect(CNGlassEffectShape.values, contains(CNGlassEffectShape.circle));
    });
  });

  group('CNTabBarSearchItem', () {
    test('creates search item with defaults', () {
      const item = CNTabBarSearchItem();

      expect(item.placeholder, 'Search');
      expect(item.automaticallyActivatesSearch, true);
      expect(item.icon, isNull);
      expect(item.onSearchChanged, isNull);
      expect(item.onSearchSubmit, isNull);
      expect(item.onSearchActiveChanged, isNull);
    });

    test('creates search item with custom values', () {
      const icon = CNSymbol('magnifyingglass');
      var searchChangedCalled = false;
      var searchSubmitCalled = false;
      var searchActiveChangedCalled = false;

      final item = CNTabBarSearchItem(
        icon: icon,
        placeholder: 'Find customer',
        automaticallyActivatesSearch: false,
        onSearchChanged: (_) => searchChangedCalled = true,
        onSearchSubmit: (_) => searchSubmitCalled = true,
        onSearchActiveChanged: (_) => searchActiveChangedCalled = true,
      );

      expect(item.icon, icon);
      expect(item.placeholder, 'Find customer');
      expect(item.automaticallyActivatesSearch, false);

      item.onSearchChanged?.call('test');
      item.onSearchSubmit?.call('test');
      item.onSearchActiveChanged?.call(true);

      expect(searchChangedCalled, true);
      expect(searchSubmitCalled, true);
      expect(searchActiveChangedCalled, true);
    });

    test('equality and hashCode', () {
      const item1 = CNTabBarSearchItem(placeholder: 'Search');
      const item2 = CNTabBarSearchItem(placeholder: 'Search');
      const item3 = CNTabBarSearchItem(placeholder: 'Find');

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1, isNot(equals(item3)));
    });
  });

  group('CNTabBarSearchStyle', () {
    test('creates style with defaults', () {
      const style = CNTabBarSearchStyle();

      expect(style.iconSize, isNull);
      expect(style.iconColor, isNull);
      expect(style.activeIconColor, isNull);
      expect(style.searchBarBackgroundColor, isNull);
      expect(style.searchBarTextColor, isNull);
      expect(style.searchBarPlaceholderColor, isNull);
      expect(style.clearButtonColor, isNull);
      expect(style.buttonSize, isNull);
      expect(style.searchBarHeight, isNull);
      expect(style.searchBarBorderRadius, isNull);
      expect(style.searchBarPadding, isNull);
      expect(style.contentPadding, isNull);
      expect(style.spacing, isNull);
      expect(style.animationDuration, isNull);
      expect(style.showClearButton, true);
      expect(style.collapsedTabIcon, isNull);
    });

    test('creates style with custom values', () {
      const style = CNTabBarSearchStyle(
        iconSize: 24.0,
        iconColor: Color(0xFF000000),
        activeIconColor: Color(0xFF0000FF),
        searchBarBackgroundColor: Color(0xFFFFFFFF),
        searchBarTextColor: Color(0xFF333333),
        searchBarPlaceholderColor: Color(0xFF999999),
        clearButtonColor: Color(0xFF666666),
        buttonSize: 48.0,
        searchBarHeight: 50.0,
        searchBarBorderRadius: 12.0,
        searchBarPadding: EdgeInsets.all(16),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        spacing: 16.0,
        animationDuration: Duration(milliseconds: 500),
        showClearButton: false,
        collapsedTabIcon: CNSymbol('house'),
      );

      expect(style.iconSize, 24.0);
      expect(style.iconColor, const Color(0xFF000000));
      expect(style.activeIconColor, const Color(0xFF0000FF));
      expect(style.searchBarBackgroundColor, const Color(0xFFFFFFFF));
      expect(style.searchBarTextColor, const Color(0xFF333333));
      expect(style.searchBarPlaceholderColor, const Color(0xFF999999));
      expect(style.clearButtonColor, const Color(0xFF666666));
      expect(style.buttonSize, 48.0);
      expect(style.searchBarHeight, 50.0);
      expect(style.searchBarBorderRadius, 12.0);
      expect(style.searchBarPadding, const EdgeInsets.all(16));
      expect(
        style.contentPadding,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      );
      expect(style.spacing, 16.0);
      expect(style.animationDuration, const Duration(milliseconds: 500));
      expect(style.showClearButton, false);
      expect(style.collapsedTabIcon?.name, 'house');
    });

    test('equality and hashCode', () {
      const style1 = CNTabBarSearchStyle(iconSize: 20.0);
      const style2 = CNTabBarSearchStyle(iconSize: 20.0);
      const style3 = CNTabBarSearchStyle(iconSize: 24.0);

      expect(style1, equals(style2));
      expect(style1.hashCode, equals(style2.hashCode));
      expect(style1, isNot(equals(style3)));
    });

    test('search item uses style', () {
      const style = CNTabBarSearchStyle(
        iconSize: 22.0,
        buttonSize: 46.0,
        showClearButton: false,
      );
      const item = CNTabBarSearchItem(
        placeholder: 'Custom Search',
        style: style,
      );

      expect(item.style.iconSize, 22.0);
      expect(item.style.buttonSize, 46.0);
      expect(item.style.showClearButton, false);
    });
  });

  group('CNTabBarSearchController', () {
    test('creates controller with defaults', () {
      final controller = CNTabBarSearchController();

      expect(controller.text, '');
      expect(controller.isActive, false);
    });

    test('text setter notifies listeners', () {
      final controller = CNTabBarSearchController();
      var notified = false;

      controller.addListener(() => notified = true);
      controller.text = 'test query';

      expect(notified, true);
      expect(controller.text, 'test query');
    });

    test('activateSearch sets isActive to true', () {
      final controller = CNTabBarSearchController();
      var notified = false;

      controller.addListener(() => notified = true);
      controller.activateSearch();

      expect(notified, true);
      expect(controller.isActive, true);
    });

    test('deactivateSearch sets isActive to false', () {
      final controller = CNTabBarSearchController();
      controller.activateSearch();

      var notified = false;
      controller.addListener(() => notified = true);
      controller.deactivateSearch();

      expect(notified, true);
      expect(controller.isActive, false);
    });

    test('clear clears text and optionally deactivates', () {
      final controller = CNTabBarSearchController();
      controller.text = 'query';
      controller.activateSearch();

      controller.clear();
      expect(controller.text, '');
      expect(controller.isActive, true);

      controller.text = 'another query';
      controller.clear(deactivate: true);
      expect(controller.text, '');
      expect(controller.isActive, false);
    });

    test('updateFromNative updates state', () {
      final controller = CNTabBarSearchController();
      var notified = false;

      controller.addListener(() => notified = true);
      controller.updateFromNative(text: 'native text', isActive: true);

      expect(notified, true);
      expect(controller.text, 'native text');
      expect(controller.isActive, true);
    });

    test('dispose works correctly', () {
      final controller = CNTabBarSearchController();
      controller.dispose();
      // Should not throw
    });
  });

  group('CNTabBar with search', () {
    testWidgets('renders tab bar with search item (Flutter fallback)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 60,
              child: CNTabBar(
                items: [
                  CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                  CNTabBarItem(label: 'Settings', icon: CNSymbol('gear')),
                ],
                currentIndex: 0,
                onTap: (_) {},
                searchItem: CNTabBarSearchItem(
                  placeholder: 'Search',
                  onSearchChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // On non-iOS platforms with search, custom fallback layout is rendered
      // (not CupertinoTabBar, but a Row-based layout with search)
      expect(find.byType(Row), findsWidgets);
      // Should find the search icon (magnifyingglass)
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('renders regular tab bar without search item', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNTabBar(
              items: [
                CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                CNTabBarItem(label: 'Profile', icon: CNSymbol('person')),
                CNTabBarItem(label: 'Settings', icon: CNSymbol('gear')),
              ],
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CupertinoTabBar), findsOneWidget);
    });

    testWidgets('handles tab selection', (tester) async {
      var selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNTabBar(
              items: [
                CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                CNTabBarItem(label: 'Settings', icon: CNSymbol('gear')),
              ],
              currentIndex: selectedIndex,
              onTap: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      await tester.pump();

      // The fallback CupertinoTabBar should be rendered
      expect(find.byType(CupertinoTabBar), findsOneWidget);
    });
  });

  group('CNTabBarItem', () {
    test('creates item with SF Symbol', () {
      const icon = CNSymbol('house');
      const item = CNTabBarItem(label: 'Home', icon: icon);

      expect(item.label, 'Home');
      expect(item.icon, icon);
      expect(item.badge, isNull);
    });

    test('creates item with badge', () {
      const item = CNTabBarItem(
        label: 'Messages',
        icon: CNSymbol('message'),
        badge: '5',
      );

      expect(item.label, 'Messages');
      expect(item.badge, '5');
    });

    test('creates item with active icon', () {
      const icon = CNSymbol('house');
      const activeIcon = CNSymbol('house.fill');
      const item = CNTabBarItem(
        label: 'Home',
        icon: icon,
        activeIcon: activeIcon,
      );

      expect(item.icon, icon);
      expect(item.activeIcon, activeIcon);
    });

    test('creates item with image asset', () {
      final asset = CNImageAsset('assets/icon.png');
      final activeAsset = CNImageAsset('assets/icon_active.png');
      final item = CNTabBarItem(
        label: 'Custom',
        imageAsset: asset,
        activeImageAsset: activeAsset,
      );

      expect(item.imageAsset, asset);
      expect(item.activeImageAsset, activeAsset);
    });

    test('creates item with custom IconData', () {
      const item = CNTabBarItem(
        label: 'Custom',
        customIcon: Icons.home,
        activeCustomIcon: Icons.home_filled,
      );

      expect(item.customIcon, Icons.home);
      expect(item.activeCustomIcon, Icons.home_filled);
    });
  });

  group('CNTabBar iconSize', () {
    // These tests exercise the Flutter fallback path (which is what runs
    // in `flutter test` since UiKitView/AppKitView aren't available off-
    // device). The fallback mirrors the native sizing precedence used in
    // `_prepareCreationParams`, so it's the right place to assert that
    // bar-level `iconSize` is honored across icon kinds — including the
    // previously-broken `customIcon` path (Issue: customIcon ignored
    // bar-level iconSize, was hardcoded to 25.0).
    Finder iconWith(IconData data) =>
        find.byWidgetPredicate((w) => w is Icon && w.icon == data);

    // Drains `PlatformViewGuard`'s 500ms debug-mode debounce so the test
    // doesn't fail with a "pending Timer after dispose" error when run in
    // isolation. The guard is scheduled in `_CNTabBarState.initState`.
    Future<void> drainPlatformViewGuard(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('bar-level iconSize sizes customIcon (unselected)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNTabBar(
              iconSize: 32.0,
              items: const [
                CNTabBarItem(label: 'Home', customIcon: Icons.home),
                CNTabBarItem(label: 'Settings', customIcon: Icons.settings),
              ],
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final homeIcon = tester.widget<Icon>(iconWith(Icons.home));
      final settingsIcon = tester.widget<Icon>(iconWith(Icons.settings));
      expect(homeIcon.size, 32.0);
      expect(settingsIcon.size, 32.0);

      await drainPlatformViewGuard(tester);
    });

    testWidgets('bar-level iconSize sizes activeCustomIcon (selected)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNTabBar(
              iconSize: 28.0,
              items: const [
                CNTabBarItem(
                  label: 'Home',
                  customIcon: Icons.home_outlined,
                  activeCustomIcon: Icons.home,
                ),
                CNTabBarItem(label: 'Settings', customIcon: Icons.settings),
              ],
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Selected tab uses the active icon
      final activeHome = tester.widget<Icon>(iconWith(Icons.home));
      expect(activeHome.size, 28.0);

      await drainPlatformViewGuard(tester);
    });

    testWidgets('customIcon falls back to 25pt when iconSize unset', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CNTabBar(
              items: const [
                CNTabBarItem(label: 'Home', customIcon: Icons.home),
                CNTabBarItem(label: 'Settings', customIcon: Icons.settings),
              ],
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final homeIcon = tester.widget<Icon>(iconWith(Icons.home));
      expect(homeIcon.size, 25.0);

      await drainPlatformViewGuard(tester);
    });
  });
}
