import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a [CNSidebar] whose rows and selection a test can change.
class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int selected = 1;
  String? badge = '3';
  bool iconsOnly = false;
  final List<int> picked = [];

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: Row(
      children: [
        SizedBox(
          width: CNSidebar.width,
          child: CNSidebar(
            sections: [
              CNSidebarSection(
                items: [
                  CNSidebarItem(
                    title: 'Inbox',
                    sfSymbol: const CNSymbol('tray'),
                    activeSfSymbol: const CNSymbol('tray.fill'),
                    badge: badge,
                  ),
                  const CNSidebarItem(
                    title: 'Flagged',
                    sfSymbol: CNSymbol('flag'),
                    badge: CNSidebarItem.dotBadge,
                  ),
                ],
              ),
              const CNSidebarSection(
                title: 'Smart Mailboxes',
                items: [
                  CNSidebarItem(title: 'Today', sfSymbol: CNSymbol('calendar')),
                ],
              ),
            ],
            selectedIndex: selected,
            iconsOnly: iconsOnly,
            semanticLabel: 'Mailboxes',
            onSelected: picked.add,
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    ),
  );
}

void main() {
  late List<MethodCall> calls;

  void mockNative(WidgetTester tester, String prefix) {
    calls = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') calls.add(call);
      return null;
    });
    for (var id = 0; id < 20; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('${prefix}_$id'), (
        call,
      ) async {
        calls.add(call);
        return null;
      });
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('${prefix}_$id'),
          null,
        );
      }
    });
  }

  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  MethodCall create() => calls.lastWhere((c) => c.method == 'create');

  Map<Object?, Object?> creationParams() {
    final bytes = (create().arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  List<MethodCall> sent() => calls.where((c) => c.method != 'create').toList();

  /// Sends [method] from the native view, as the AppKit view does.
  Future<void> fromNative(
    WidgetTester tester,
    String channel,
    String method,
    Object? args,
  ) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  group('CNSidebar on macOS', () {
    testWidgets('creates the AppKit sidebar with every row and section', (
      tester,
    ) async {
      mockNative(tester, 'CNSidebar');
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      expect(find.byType(AppKitView), findsOneWidget);
      expect((create().arguments as Map)['viewType'], 'CNSidebar');
      final params = creationParams();
      expect(params['selectedIndex'], 1);
      expect(params['iconsOnly'], false);
      expect(params['semanticLabel'], 'Mailboxes');
      expect(params['isDark'], false);
      expect(params['tint'], isNull);
      expect(params['sections'], [
        {
          'items': [
            {
              'title': 'Inbox',
              'sfSymbol': 'tray',
              'activeSfSymbol': 'tray.fill',
              'badge': '3',
            },
            {'title': 'Flagged', 'sfSymbol': 'flag', 'badge': '​'},
          ],
        },
        {
          'title': 'Smart Mailboxes',
          'items': [
            {'title': 'Today', 'sfSymbol': 'calendar'},
          ],
        },
      ]);
      expect(tester.getSize(find.byType(AppKitView)).width, CNSidebar.width);
      await tester.pumpWidget(const SizedBox());
    }, variant: mac);

    testWidgets('a user pick calls onSelected, not a change from Dart', (
      tester,
    ) async {
      mockNative(tester, 'CNSidebar');
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      await tester.pumpAndSettle();
      final id = (create().arguments as Map)['id'] as int;
      final view = tester.widget<AppKitView>(find.byType(AppKitView));
      view.onPlatformViewCreated!(id);
      await tester.pump();

      await fromNative(tester, 'CNSidebar_$id', 'valueChanged', {'index': 2});
      expect(key.currentState!.picked, [2]);

      // The parent follows the pick: nothing goes back to the native view.
      key.currentState!.update(() => key.currentState!.selected = 2);
      await tester.pumpAndSettle();
      expect(sent(), isEmpty);

      // A change made in Dart is sent, and does not call onSelected.
      key.currentState!.update(() => key.currentState!.selected = 0);
      await tester.pumpAndSettle();
      expect(sent().map((c) => '${c.method} ${c.arguments}'), [
        'setSelectedIndex {index: 0}',
      ]);
      expect(key.currentState!.picked, [2]);
      await tester.pumpWidget(const SizedBox());
    }, variant: mac);

    testWidgets('new rows and a new style are sent once each', (tester) async {
      mockNative(tester, 'CNSidebar');
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      await tester.pumpAndSettle();
      final id = (create().arguments as Map)['id'] as int;
      tester.widget<AppKitView>(find.byType(AppKitView)).onPlatformViewCreated!(
        id,
      );
      await tester.pump();

      key.currentState!.update(() => key.currentState!.badge = '4');
      await tester.pumpAndSettle();
      key.currentState!.update(() => key.currentState!.iconsOnly = true);
      await tester.pumpAndSettle();
      final methods = sent().map((c) => c.method).toList();
      expect(methods, ['setSections', 'setStyle']);
      final sections = (sent().first.arguments as Map)['sections'] as List;
      expect(((sections.first as Map)['items'] as List).first, {
        'title': 'Inbox',
        'sfSymbol': 'tray',
        'activeSfSymbol': 'tray.fill',
        'badge': '4',
      });
      expect((sent().last.arguments as Map)['iconsOnly'], true);
      await tester.pumpWidget(const SizedBox());
    }, variant: mac);
  });

  group('CNSidebar elsewhere', () {
    testWidgets('Android: a CNTabRail sidebar with every row, no headers', (
      tester,
    ) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      final rail = tester.widget<CNTabRail>(find.byType(CNTabRail));
      expect(rail.style, CNTabRailStyle.sidebar);
      expect(rail.items.map((e) => e.label), ['Inbox', 'Flagged', 'Today']);
      expect(rail.items.first.badge, '3');
      expect(rail.currentIndex, 1);
      expect(find.text('Smart Mailboxes'), findsNothing);
      expect(find.byType(AppKitView), findsNothing);

      await tester.tap(find.text('Today'));
      await tester.pump(const Duration(seconds: 1));
      expect(key.currentState!.picked, [2]);
    }, variant: android);
  });

  group('CNTabRail on macOS', () {
    const items = <CNTabBarItem>[
      CNTabBarItem(label: 'Home', icon: CNSymbol('house'), badge: '2'),
      CNTabBarItem(label: 'Music', icon: CNSymbol('music.note')),
    ];

    testWidgets('the sidebar style is a CNSidebar of the tabs', (tester) async {
      mockNative(tester, 'CNSidebar');
      final taps = <int>[];
      await tester.pumpWidget(
        CupertinoApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: CNTabRail(
              items: items,
              currentIndex: 1,
              style: CNTabRailStyle.sidebar,
              onTap: taps.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sidebar = tester.widget<CNSidebar>(find.byType(CNSidebar));
      expect(sidebar.iconsOnly, isFalse);
      expect(sidebar.selectedIndex, 1);
      expect(sidebar.sections.single.items.map((e) => e.title), [
        'Home',
        'Music',
      ]);
      expect(sidebar.sections.single.items.first.badge, '2');
      expect(
        tester.getSize(find.byType(CNTabRail)).width,
        CNTabRail.sidebarWidth,
      );
      expect((create().arguments as Map)['viewType'], 'CNSidebar');
      sidebar.onSelected(0);
      expect(taps, [0]);
      await tester.pumpWidget(const SizedBox());
    }, variant: mac);

    testWidgets('the rail style shows icons only, at the rail size', (
      tester,
    ) async {
      mockNative(tester, 'CNSidebar');
      await tester.pumpWidget(
        CupertinoApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: CNTabRail(items: items, currentIndex: 0, onTap: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CNSidebar>(find.byType(CNSidebar)).iconsOnly, true);
      expect(
        tester.getSize(find.byType(CNTabRail)),
        Size(CNTabRail.railWidth, CNTabRail.railHeight(2)),
      );
      expect(creationParams()['iconsOnly'], true);
      await tester.pumpWidget(const SizedBox());
    }, variant: mac);
  });
}
