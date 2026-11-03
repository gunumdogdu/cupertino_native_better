import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// `CNTabBarItem.menuItems` on the Flutter fallback: the menu opens as an
/// action sheet instead of the item being selected.
void main() {
  // The test host is not iOS 26, so CNTabBar draws its Flutter fallback.

  Future<(List<int>, List<int>, List<List<int>>)> pumpBar(
    WidgetTester tester,
  ) async {
    final taps = <int>[];
    final menuIndices = <int>[];
    final paths = <List<int>>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: CNTabBar(
              items: const [
                CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                CNTabBarItem(
                  label: 'Create',
                  icon: CNSymbol('plus'),
                  menuItems: [
                    CNPopupMenuItem(label: 'New note', subtitle: 'Text'),
                    CNPopupMenuDivider(),
                    CNPopupMenuSubmenu(
                      label: 'Import',
                      items: [
                        CNPopupMenuItem(label: 'Photo'),
                        CNPopupMenuItem(label: 'File'),
                      ],
                    ),
                  ],
                ),
              ],
              currentIndex: 0,
              onTap: taps.add,
              onMenuSelected: (index, path) {
                menuIndices.add(index);
                paths.add(path);
              },
            ),
          ),
        ),
      ),
    );
    // Drain PlatformViewGuard's debounce timer.
    await tester.pump(const Duration(milliseconds: 600));
    return (taps, menuIndices, paths);
  }

  testWidgets('a plain item still calls onTap', (tester) async {
    final (taps, menuIndices, paths) = await pumpBar(tester);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(taps, [0]);
    expect(menuIndices, isEmpty);
    expect(paths, isEmpty);
  });

  testWidgets('an item with a menu opens it instead of calling onTap', (
    tester,
  ) async {
    final (taps, menuIndices, paths) = await pumpBar(tester);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
    expect(menuIndices, [1]);
    expect(paths, [
      [0],
    ]);
  });

  testWidgets('an entry in a submenu reports its full path', (tester) async {
    final (taps, menuIndices, paths) = await pumpBar(tester);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
    expect(menuIndices, [1]);
    expect(paths, [
      [2, 1],
    ]);
  });

  testWidgets('cancelling reports nothing', (tester) async {
    final (taps, menuIndices, paths) = await pumpBar(tester);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
    expect(menuIndices, isEmpty);
    expect(paths, isEmpty);
  });
}
