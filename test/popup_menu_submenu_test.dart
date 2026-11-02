import 'dart:typed_data';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/popup_menu_encoder.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Subtitles and submenus in `CNPopupMenuButton`, and `onPathSelected`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int? argb(Color? c) => c?.toARGB32();

  group('encodePopupMenuEntries', () {
    test('a menu without subtitles or submenus keeps its keys and values', () {
      const asset = CNImageAsset('assets/icons/star.svg', size: 22);
      const items = <CNPopupMenuEntry>[
        CNPopupMenuItem(
          label: 'Copy',
          icon: CNSymbol('doc.on.doc', size: 18, color: Color(0xFF112233)),
          checked: true,
        ),
        CNPopupMenuDivider(),
        CNPopupMenuItem(label: 'Star', imageAsset: asset),
        CNPopupMenuItem(label: 'Delete', isDestructive: true, enabled: false),
      ];

      final encoded = encodePopupMenuEntries(items, resolveColor: argb);

      // The keys and values `CNPopupMenuButton` sent before submenus existed.
      expect(encoded, {
        'labels': ['Copy', '', 'Star', 'Delete'],
        'sfSymbols': ['doc.on.doc', '', '', ''],
        'customIconBytes': [null, null, null, null],
        'customIconColors': [null, null, null, null],
        'imageAssetPaths': ['', '', 'assets/icons/star.svg', ''],
        'imageAssetData': [null, null, null, null],
        'imageAssetFormats': ['', '', 'svg', ''],
        'isDivider': [false, true, false, false],
        'enabled': [true, false, true, false],
        'checked': [true, false, false, false],
        'isDestructive': [false, false, false, true],
        'sfSymbolSizes': [18.0, null, 22.0, null],
        'sfSymbolColors': [0xFF112233, null, null, null],
        'sfSymbolRenderingModes': [null, null, null, null],
        'sfSymbolPaletteColors': [null, null, null, null],
        'sfSymbolGradientEnabled': [null, null, null, null],
      });
    });

    test('setItems leaves out the top level custom icons, as before', () {
      final encoded = encodePopupMenuEntries(
        const [CNPopupMenuItem(label: 'A')],
        resolveColor: argb,
        includeCustomIcons: false,
      );

      expect(encoded.containsKey('customIconBytes'), isFalse);
      expect(encoded.containsKey('customIconColors'), isFalse);
    });

    test('subtitles and submenus are encoded level by level', () {
      const items = <CNPopupMenuEntry>[
        CNPopupMenuItem(label: 'Name', subtitle: 'A to Z'),
        CNPopupMenuDivider(),
        CNPopupMenuSubmenu(
          label: 'Export',
          subtitle: '3 formats',
          icon: CNSymbol('square.and.arrow.up'),
          items: [
            CNPopupMenuItem(label: 'PDF'),
            CNPopupMenuSubmenu(
              label: 'Spreadsheet',
              items: [CNPopupMenuItem(label: 'CSV', subtitle: 'Semicolons')],
            ),
          ],
        ),
      ];

      final encoded = encodePopupMenuEntries(items, resolveColor: argb);

      expect(encoded['labels'], ['Name', '', 'Export']);
      expect(encoded['sfSymbols'], ['', '', 'square.and.arrow.up']);
      expect(encoded['subtitles'], ['A to Z', '', '3 formats']);
      expect(encoded['isSubmenu'], [false, false, true]);
      final submenus = encoded['submenus']! as List;
      expect(submenus[0], isNull);
      expect(submenus[1], isNull);

      final export = submenus[2] as Map<String, Object?>;
      expect(export['labels'], ['PDF', 'Spreadsheet']);
      expect(export['isSubmenu'], [false, true]);
      // A level with no subtitle still sends them when it has a submenu.
      expect(export['subtitles'], ['', '']);

      final spreadsheet =
          (export['submenus']! as List)[1] as Map<String, Object?>;
      expect(spreadsheet['labels'], ['CSV']);
      expect(spreadsheet['subtitles'], ['Semicolons']);
      expect(spreadsheet.containsKey('isSubmenu'), isFalse);
    });

    test('custom icons stay on their own entry after a divider', () {
      // Before, icons were looked up with a counter that skipped dividers in
      // one list and not in the other, so `B` got the divider's empty slot.
      const a = CNPopupMenuItem(label: 'A', customIcon: CupertinoIcons.heart);
      const b = CNPopupMenuItem(label: 'B', customIcon: CupertinoIcons.star);
      const child = CNPopupMenuItem(
        label: 'C',
        customIcon: CupertinoIcons.bell,
      );
      const submenu = CNPopupMenuSubmenu(label: 'More', items: [child]);
      final bytesA = Uint8List.fromList([1]);
      final bytesB = Uint8List.fromList([2]);
      final bytesC = Uint8List.fromList([3]);

      final encoded = encodePopupMenuEntries(
        const [a, CNPopupMenuDivider(), b, submenu],
        resolveColor: argb,
        customIconBytes: Map.identity()
          ..[a] = bytesA
          ..[b] = bytesB
          ..[child] = bytesC,
      );

      expect(encoded['customIconBytes'], [bytesA, null, bytesB, null]);
      final more = (encoded['submenus']! as List)[3] as Map<String, Object?>;
      expect(more['customIconBytes'], [bytesC]);
    });

    test('submenus carry their custom icons in setItems too', () {
      const child = CNPopupMenuItem(
        label: 'C',
        customIcon: CupertinoIcons.bell,
      );
      final bytes = Uint8List.fromList([3]);

      final encoded = encodePopupMenuEntries(
        const [
          CNPopupMenuSubmenu(label: 'More', items: [child]),
        ],
        resolveColor: argb,
        customIconBytes: Map.identity()..[child] = bytes,
        includeCustomIcons: false,
      );

      final more = (encoded['submenus']! as List)[0] as Map<String, Object?>;
      expect(more['customIconBytes'], [bytes]);
    });
  });

  group('CNPopupMenuButton fallback', () {
    // Android, so the button takes its CupertinoActionSheet fallback.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    const items = <CNPopupMenuEntry>[
      CNPopupMenuItem(label: 'Name', subtitle: 'A to Z'),
      CNPopupMenuDivider(),
      CNPopupMenuSubmenu(
        label: 'Export',
        subtitle: '3 formats',
        items: [
          CNPopupMenuItem(label: 'PDF'),
          CNPopupMenuDivider(),
          CNPopupMenuSubmenu(
            label: 'Spreadsheet',
            items: [CNPopupMenuItem(label: 'CSV')],
          ),
        ],
      ),
    ];

    Future<(List<int>, List<List<int>>)> pumpMenu(
      WidgetTester tester, {
      bool withOnSelected = true,
    }) async {
      final indices = <int>[];
      final paths = <List<int>>[];
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: CNPopupMenuButton(
              buttonLabel: 'Sort',
              items: items,
              onSelected: withOnSelected ? indices.add : null,
              onPathSelected: paths.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sort'));
      await tester.pumpAndSettle();
      return (indices, paths);
    }

    testWidgets('shows subtitles under their label', (tester) async {
      await pumpMenu(tester);

      expect(find.text('A to Z'), findsOneWidget);
      expect(find.text('3 formats'), findsOneWidget);
    }, variant: android);

    testWidgets('a top-level item reports its index and its path', (
      tester,
    ) async {
      final (indices, paths) = await pumpMenu(tester);

      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      expect(indices, [0]);
      expect(paths, [
        [0],
      ]);
    }, variant: android);

    testWidgets('an item in nested submenus reports its full path', (
      tester,
    ) async {
      final (indices, paths) = await pumpMenu(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spreadsheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();

      // onSelected gets the top-level entry the item is under.
      expect(indices, [2]);
      expect(paths, [
        [2, 2, 0],
      ]);
    }, variant: android);

    testWidgets('cancelling in a submenu reports nothing', (tester) async {
      final (indices, paths) = await pumpMenu(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(indices, isEmpty);
      expect(paths, isEmpty);
    }, variant: android);

    testWidgets('onPathSelected alone is enough', (tester) async {
      final (_, paths) = await pumpMenu(tester, withOnSelected: false);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      expect(paths, [
        [2, 0],
      ]);
    }, variant: android);
  });

  group('CNPopupMenuButton callbacks', () {
    test('needs onSelected or onPathSelected', () {
      expect(
        () => CNPopupMenuButton(
          buttonLabel: 'Sort',
          items: const [CNPopupMenuItem(label: 'A')],
        ),
        throwsAssertionError,
      );
      expect(
        () => CNPopupMenuButton.icon(
          buttonIcon: const CNSymbol('ellipsis'),
          items: const [CNPopupMenuItem(label: 'A')],
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'a submenu without onPathSelected is reported',
      (tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: CNPopupMenuButton(
                buttonLabel: 'Sort',
                items: const [
                  CNPopupMenuSubmenu(
                    label: 'Export',
                    items: [CNPopupMenuItem(label: 'PDF')],
                  ),
                ],
                onSelected: (_) {},
              ),
            ),
          ),
        );

        expect(tester.takeException(), isAssertionError);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });
}
