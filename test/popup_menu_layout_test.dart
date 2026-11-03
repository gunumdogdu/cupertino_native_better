import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/popup_menu_encoder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Inline and palette submenus, their element size, and items that keep the
/// menu open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int? argb(Color? c) => c?.toARGB32();

  group('encodePopupMenuEntries', () {
    test('a menu that uses none of them sends none of their keys', () {
      final encoded = encodePopupMenuEntries(const [
        CNPopupMenuItem(label: 'Copy'),
        CNPopupMenuSubmenu(
          label: 'Share',
          items: [CNPopupMenuItem(label: 'Mail')],
        ),
      ], resolveColor: argb);

      expect(encoded.containsKey('keepsMenuPresented'), isFalse);
      expect(encoded.containsKey('submenuStyles'), isFalse);
      expect(encoded.containsKey('elementSizes'), isFalse);
    });

    test('styles, sizes and kept items are sent slot by slot', () {
      final encoded = encodePopupMenuEntries(const [
        CNPopupMenuItem(label: 'Zoom in', keepsMenuPresented: true),
        CNPopupMenuDivider(),
        CNPopupMenuSubmenu(
          label: 'Format',
          style: CNPopupMenuSubmenuStyle.palette,
          elementSize: CNPopupMenuElementSize.small,
          items: [
            CNPopupMenuItem(label: 'Bold', icon: CNSymbol('bold')),
            CNPopupMenuItem(label: 'Italic', icon: CNSymbol('italic')),
          ],
        ),
        CNPopupMenuSubmenu(
          label: 'Sort',
          style: CNPopupMenuSubmenuStyle.inline,
          items: [CNPopupMenuItem(label: 'Name')],
        ),
      ], resolveColor: argb);

      expect(encoded['keepsMenuPresented'], [true, false, false, false]);
      expect(encoded['submenuStyles'], [null, null, 'palette', 'inline']);
      expect(encoded['elementSizes'], [null, null, 'small', null]);
    });
  });

  group('the action sheet fallback', () {
    // Android, so the button takes its CupertinoActionSheet fallback.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    Future<(List<int>, List<List<int>>)> pumpMenu(WidgetTester tester) async {
      final indices = <int>[];
      final paths = <List<int>>[];
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNPopupMenuButton(
              buttonLabel: 'Edit',
              items: const [
                CNPopupMenuItem(label: 'Copy'),
                CNPopupMenuSubmenu(
                  label: 'Sort by',
                  style: CNPopupMenuSubmenuStyle.inline,
                  items: [
                    CNPopupMenuItem(label: 'Name'),
                    CNPopupMenuSubmenu(
                      label: 'Date',
                      items: [CNPopupMenuItem(label: 'Created')],
                    ),
                  ],
                ),
              ],
              onSelected: indices.add,
              onPathSelected: paths.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      return (indices, paths);
    }

    testWidgets('lists an inline submenu in place under its label', (
      tester,
    ) async {
      final (indices, paths) = await pumpMenu(tester);

      expect(find.text('Sort by'), findsOneWidget);
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      expect(indices, [1]);
      expect(paths, [
        [1, 0],
      ]);
    }, variant: android);

    testWidgets(
      'a nested submenu inside an inline one still opens a sheet',
      (tester) async {
        final (_, paths) = await pumpMenu(tester);

        await tester.tap(find.text('Date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Created'));
        await tester.pumpAndSettle();

        expect(paths, [
          [1, 1, 0],
        ]);
      },
      variant: android,
    );

    testWidgets('the header is not a choice', (tester) async {
      final (indices, paths) = await pumpMenu(tester);

      await tester.tap(find.text('Sort by'));
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget, reason: 'the sheet is open');
      expect(indices, isEmpty);
      expect(paths, isEmpty);
    }, variant: android);
  });
}
