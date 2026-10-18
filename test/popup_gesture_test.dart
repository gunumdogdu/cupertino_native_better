import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Issue #76: the CNPopupGesture menu stayed invisible until a hot reload, and
// every item reported the same out-of-range index.
void main() {
  Future<List<int>> openMenu(WidgetTester tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CNPopupGesture(
              enableHapticFeedback: false,
              items: const [
                CNPopupMenuItem(label: 'Copy'),
                CNPopupMenuItem(label: 'Share'),
                CNPopupMenuDivider(),
                CNPopupMenuItem(label: 'Delete'),
              ],
              onSelected: selected.add,
              child: const Text('Long press me'),
            ),
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Long press me'));
    await tester.pumpAndSettle();
    return selected;
  }

  testWidgets('menu is visible once the open animation has finished', (
    tester,
  ) async {
    await openMenu(tester);

    expect(find.text('Share'), findsOneWidget);
    // On the old code the menu sat under an Opacity frozen at 0.
    expect(
      find.ancestor(
        of: find.text('Share'),
        matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
      ),
      findsNothing,
    );
  });

  testWidgets('each item reports its own index, dividers excluded', (
    tester,
  ) async {
    final selected = await openMenu(tester);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(selected, [1]);

    await tester.longPress(find.text('Long press me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(selected, [1, 2]);
  });
}
