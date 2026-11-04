import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

// The test platform is Android, so CNSearchBar draws its Flutter fallback,
// the path iOS < 26 takes.
void main() {
  Future<void> pumpHost(WidgetTester tester, Widget body) => tester.pumpWidget(
    CupertinoApp(
      home: CupertinoPageScaffold(child: SafeArea(child: body)),
    ),
  );

  // Collapsed, tap to expand; expandable: false starts expanded.
  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.byIcon(CupertinoIcons.search));
    await tester.pumpAndSettle();
  }

  final parents = <String, Widget Function(Widget)>{
    'ListView(padding: 16)': (bar) =>
        ListView(padding: const EdgeInsets.all(16), children: [bar]),
    'Padding + Column': (bar) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [bar],
      ),
    ),
    'Row + Expanded': (bar) => Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('A'),
          Expanded(child: bar),
        ],
      ),
    ),
    'Center (full width)': (bar) => Center(child: bar),
  };

  for (final MapEntry(key: name, value: wrap) in parents.entries) {
    for (final expandable in [true, false]) {
      for (final cancel in [true, false]) {
        testWidgets('$name, expandable: $expandable, cancel: $cancel: '
            'no overflow when expanded', (tester) async {
          await pumpHost(
            tester,
            wrap(CNSearchBar(expandable: expandable, showCancelButton: cancel)),
          );
          if (expandable) await expand(tester);
          expect(tester.takeException(), isNull);
          expect(find.text('Cancel'), cancel ? findsOneWidget : findsNothing);
        });
      }
    }
  }

  testWidgets(
    'a full-width parent without cancel still gets the screen width',
    (tester) async {
      await pumpHost(
        tester,
        const Center(child: CNSearchBar(showCancelButton: false)),
      );
      await expand(tester);
      final screen =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getSize(find.byType(AnimatedContainer)).width, screen);
    },
  );

  testWidgets('the bar leaves room for Cancel and Cancel collapses it', (
    tester,
  ) async {
    await pumpHost(
      tester,
      ListView(
        padding: const EdgeInsets.all(16),
        children: const [CNSearchBar()],
      ),
    );
    await expand(tester);
    final bar = tester.getRect(find.byType(AnimatedContainer));
    final cancel = tester.getRect(find.text('Cancel'));
    final screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(bar.left, 16);
    expect(cancel.left, greaterThanOrEqualTo(bar.right));
    expect(cancel.right, lessThanOrEqualTo(screen - 16));

    // Collapsing never widens the bar into the space Cancel gives back.
    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final width = tester.getSize(find.byType(AnimatedContainer)).width;
      expect(width, lessThanOrEqualTo(bar.width));
    }
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);
    expect(tester.getSize(find.byType(AnimatedContainer)).width, 44);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unbounded parent falls back to the screen width', (
    tester,
  ) async {
    await pumpHost(
      tester,
      const SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: CNSearchBar(expandable: false, showCancelButton: false),
      ),
    );
    expect(tester.takeException(), isNull);
    final screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getSize(find.byType(AnimatedContainer)).width, screen);
  });

  testWidgets('an unbounded parent with Cancel shown throws nothing', (
    tester,
  ) async {
    await pumpHost(
      tester,
      const SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: CNSearchBar(),
      ),
    );
    await expand(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Cancel'), findsOneWidget);
  });

  for (final expandable in [true, false]) {
    testWidgets(
      'expandable: $expandable: inside IntrinsicHeight and IntrinsicWidth',
      (tester) async {
        await pumpHost(
          tester,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(child: CNSearchBar(expandable: expandable)),
                IntrinsicWidth(child: CNSearchBar(expandable: expandable)),
              ],
            ),
          ),
        );
        if (expandable) {
          await tester.tap(find.byIcon(CupertinoIcons.search).first);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
