import 'package:cupertino_native_better/components/toolbar.dart'
    show debugResetCNToolbarWindow, debugResolveToolbarItemIds;
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _window = MethodChannel('cn_toolbar');

/// A page with a [CNToolbar] whose items a test can change.
class _Host extends StatefulWidget {
  const _Host({super.key, required this.log, this.search});

  final List<String> log;
  final CNTabBarSearchController? search;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int badge = 3;
  bool flag = true;
  bool prominent = true;
  Set<int> view = {0};
  String? title = 'Inbox';
  bool showToolbar = true;
  bool tickers = true;
  Brightness? brightness;

  void update(VoidCallback fn) => setState(fn);

  List<CNToolbarItem> get items => [
    const CNToolbarSidebarToggle(),
    const CNToolbarSidebarTrackingSeparator(),
    CNToolbarButton(
      id: 'back',
      label: 'Back',
      icon: const CNSymbol('chevron.left'),
      isNavigational: true,
      onPressed: () => widget.log.add('back'),
    ),
    CNToolbarSegmentedGroup(
      id: 'view',
      label: 'View',
      segments: const [
        CNToolbarSegment(label: 'List', icon: CNSymbol('list.bullet')),
        CNToolbarSegment(label: 'Grid', icon: CNSymbol('square.grid.2x2')),
      ],
      selectedIndices: view,
      onSelected: (i) => widget.log.add('view $i'),
      onSelectionChanged: (s) => widget.log.add('selection $s'),
    ),
    const CNToolbarSpace.flexible(),
    CNToolbarMenu(
      id: 'sort',
      label: 'Sort',
      icon: const CNSymbol('arrow.up.arrow.down'),
      items: const [
        CNPopupMenuItem(label: 'Date'),
        CNPopupMenuDivider(),
        CNPopupMenuSubmenu(
          label: 'Group',
          items: [CNPopupMenuItem(label: 'Day')],
        ),
      ],
      onSelected: (path) => widget.log.add('sort $path'),
    ),
    if (flag)
      CNToolbarButton(
        id: 'flag',
        label: 'Flag',
        icon: const CNSymbol('flag'),
        onPressed: () => widget.log.add('flag'),
      ),
    CNToolbarButton(
      id: 'compose',
      label: 'New Message',
      icon: const CNSymbol('square.and.pencil'),
      tooltip: 'Write a new message',
      style: prominent
          ? CNToolbarItemStyle.prominent
          : CNToolbarItemStyle.plain,
      tint: const Color(0xFFFF2D55),
      badge: badge > 0 ? CNToolbarBadge.count(badge) : null,
      onPressed: () => widget.log.add('compose'),
    ),
    CNToolbarSearch(
      id: 'search',
      placeholder: 'Search mail',
      controller: widget.search,
      onChanged: (t) => widget.log.add('search "$t"'),
      onSubmitted: (t) => widget.log.add('submit "$t"'),
      onActiveChanged: (a) => widget.log.add('active $a'),
    ),
  ];

  @override
  Widget build(BuildContext context) => CupertinoApp(
    theme: CupertinoThemeData(brightness: brightness),
    home: TickerMode(
      enabled: tickers,
      child: Column(
        children: [
          const Expanded(child: SizedBox()),
          if (showToolbar)
            CNToolbar(title: title, subtitle: '3 unread', items: items),
        ],
      ),
    ),
  );
}

Map<String, Object?> _item(Map<Object?, Object?> payload, String id) =>
    ((payload['items'] as List).cast<Map<Object?, Object?>>().firstWhere(
      (i) => i['id'] == id,
    )).cast<String, Object?>();

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  tearDown(debugResetCNToolbarWindow);

  test('items without an id are known by kind and position', () {
    expect(
      debugResolveToolbarItemIds([
        const CNToolbarButton(label: 'A'),
        const CNToolbarSpace.flexible(),
        const CNToolbarButton(label: 'B'),
        const CNToolbarButton(id: 'c', label: 'C'),
        CNToolbarMenu(label: 'M', items: const []),
        const CNToolbarSpace.flexible(),
        const CNToolbarSidebarToggle(),
      ]),
      [
        'button#0',
        'flexibleSpace#0',
        'button#1',
        'c',
        'menu#0',
        'flexibleSpace#1',
        'sidebarToggle',
      ],
    );
  });

  group('macOS window toolbar', () {
    late List<MethodCall> calls;
    late List<String> log;

    Future<GlobalKey<_HostState>> pump(
      WidgetTester tester, {
      CNTabBarSearchController? search,
    }) async {
      calls = <MethodCall>[];
      log = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_window, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_window, null));
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, log: log, search: search));
      await tester.pumpAndSettle();
      return key;
    }

    Map<Object?, Object?> lastPayload() =>
        calls.lastWhere((c) => c.method == 'setToolbar').arguments
            as Map<Object?, Object?>;

    Future<void> native(
      WidgetTester tester,
      String method,
      Map<String, Object?> args,
    ) async {
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, args),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'cn_toolbar',
        data,
        (_) {},
      );
      await tester.pump();
    }

    testWidgets('takes no room and installs the toolbar with every item', (
      tester,
    ) async {
      await pump(tester);
      expect(tester.getSize(find.byType(CNToolbar)), Size.zero);
      expect(calls.map((c) => c.method), ['setToolbar']);
      final payload = lastPayload();
      expect(payload['title'], 'Inbox');
      expect(payload['subtitle'], '3 unread');
      expect(payload['style'], 'unified');
      expect(payload['showsTitle'], true);
      // A theme that follows the system leaves the window's appearance.
      expect(payload['isDark'], isNull);
      expect(payload['token'], isA<int>());
      expect(
        (payload['items'] as List).map((i) => (i as Map)['kind']).toList(),
        [
          'sidebarToggle',
          'sidebarTrackingSeparator',
          'button',
          'segmented',
          'flexibleSpace',
          'menu',
          'button',
          'button',
          'search',
        ],
      );
      expect(_item(payload, 'compose'), {
        'kind': 'button',
        'id': 'compose',
        'label': 'New Message',
        'image': {
          'symbol': 'square.and.pencil',
          'color': null,
          'mode': null,
          'palette': null,
        },
        'tooltip': 'Write a new message',
        'enabled': true,
        'badge': {'type': 'count', 'value': 3},
        'style': 'prominent',
        'tint': 0xFFFF2D55,
        'navigational': false,
        'centered': false,
      });
      final view = _item(payload, 'view');
      expect(view['selectionMode'], 'selectOne');
      expect(view['selected'], [0]);
      expect(view['usesImages'], true);
      expect(view['role'], 'automatic');
      expect((view['segments'] as List).length, 2);
      final sort = _item(payload, 'sort');
      expect(((sort['menu'] as Map)['labels'] as List), ['Date', '', 'Group']);
      expect(((sort['menu'] as Map)['isSubmenu'] as List), [
        false,
        false,
        true,
      ]);
      expect(_item(payload, 'search'), {
        'kind': 'search',
        'id': 'search',
        'label': 'Search',
        'placeholder': 'Search mail',
        'text': null,
        'width': null,
      });
      expect(_item(payload, 'back')['navigational'], true);
    }, variant: macOS);

    testWidgets('sends changes, and nothing when nothing changed', (
      tester,
    ) async {
      final key = await pump(tester);
      key.currentState!.update(() {});
      await tester.pumpAndSettle();
      expect(calls.length, 1, reason: 'an identical rebuild sends nothing');

      key.currentState!.update(() {
        key.currentState!.badge = 0;
        key.currentState!.flag = false;
        key.currentState!.prominent = false;
        key.currentState!.view = {1};
      });
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      final payload = lastPayload();
      expect(_item(payload, 'compose')['badge'], isNull);
      expect(_item(payload, 'compose')['style'], 'plain');
      expect(_item(payload, 'view')['selected'], [1]);
      expect(
        (payload['items'] as List).where((i) => (i as Map)['id'] == 'flag'),
        isEmpty,
      );
    }, variant: macOS);

    testWidgets('a dark theme makes the window dark', (tester) async {
      final key = await pump(tester);
      key.currentState!.update(
        () => key.currentState!.brightness = Brightness.dark,
      );
      await tester.pumpAndSettle();
      expect(lastPayload()['isDark'], true);
    }, variant: macOS);

    testWidgets('gives the window back when removed or covered', (
      tester,
    ) async {
      final key = await pump(tester);
      key.currentState!.update(() => key.currentState!.tickers = false);
      await tester.pumpAndSettle();
      expect(calls.last.method, 'removeToolbar');
      key.currentState!.update(() => key.currentState!.tickers = true);
      await tester.pumpAndSettle();
      expect(calls.last.method, 'setToolbar');
      key.currentState!.update(() => key.currentState!.showToolbar = false);
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), [
        'setToolbar',
        'removeToolbar',
        'setToolbar',
        'removeToolbar',
      ]);
    }, variant: macOS);

    testWidgets('the newest toolbar owns the window; the older one returns', (
      tester,
    ) async {
      await pump(tester);
      final firstToken = lastPayload()['token'];
      final second = GlobalKey<_HostState>();
      // A second page with its own toolbar, over the first.
      await tester.pumpWidget(
        Column(
          children: [
            Expanded(child: _Host(log: log)),
            Expanded(
              child: _Host(key: second, log: log),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final payloads = calls.where((c) => c.method == 'setToolbar').toList();
      expect((payloads.last.arguments as Map)['token'], isNot(firstToken));
      second.currentState!.update(() => second.currentState!.title = 'Sent');
      await tester.pumpAndSettle();
      expect(lastPayload()['title'], 'Sent');
      // The newer one leaves: the remaining one is installed again.
      await tester.pumpWidget(_Host(log: log));
      await tester.pumpAndSettle();
      expect(lastPayload()['title'], 'Inbox');
      expect(calls.last.method, 'setToolbar');
    }, variant: macOS);

    testWidgets('reports item events to the callbacks', (tester) async {
      await pump(tester);
      final token = lastPayload()['token'];
      await native(tester, 'onButtonPressed', {'token': token, 'id': 'back'});
      await native(tester, 'onButtonPressed', {
        'token': token,
        'id': 'compose',
      });
      await native(tester, 'onSegmentSelected', {
        'token': token,
        'id': 'view',
        'index': 1,
        'selected': [1],
      });
      await native(tester, 'onMenuSelected', {
        'token': token,
        'id': 'sort',
        'path': [2, 0],
      });
      await native(tester, 'onSearchActiveChanged', {
        'token': token,
        'id': 'search',
        'active': true,
      });
      await native(tester, 'onSearchChanged', {
        'token': token,
        'id': 'search',
        'text': 'inv',
      });
      await native(tester, 'onSearchSubmitted', {
        'token': token,
        'id': 'search',
        'text': 'inv',
      });
      // From a toolbar that no longer owns the window: dropped.
      await native(tester, 'onButtonPressed', {'token': 999, 'id': 'back'});
      expect(log, [
        'back',
        'compose',
        'view 1',
        'selection {1}',
        'sort [2, 0]',
        'active true',
        'search "inv"',
        'submit "inv"',
      ]);
    }, variant: macOS);

    testWidgets('the search controller starts and ends the search, sets '
        'the text, and is not echoed back', (tester) async {
      final search = CNTabBarSearchController();
      addTearDown(search.dispose);
      await pump(tester, search: search);
      final token = lastPayload()['token'];

      search.activateSearch();
      await tester.pumpAndSettle();
      expect(calls.last.method, 'focusSearch');
      expect(calls.last.arguments, {'id': 'search'});
      search.deactivateSearch();
      await tester.pumpAndSettle();
      expect(calls.last.method, 'endSearch');

      search.text = 'invoices';
      await tester.pumpAndSettle();
      expect(_item(lastPayload(), 'search')['text'], 'invoices');

      // What the user typed comes back as the controller's text, but is not
      // sent to the field again.
      final before = calls.length;
      await native(tester, 'onSearchChanged', {
        'token': token,
        'id': 'search',
        'text': 'inv',
      });
      await tester.pumpAndSettle();
      expect(search.text, 'inv');
      final sentText = calls
          .skip(before)
          .where((c) => c.method == 'setToolbar')
          .map((c) => _item(c.arguments as Map, 'search')['text']);
      expect(sentText.whereType<String>(), isEmpty);

      await native(tester, 'onSearchActiveChanged', {
        'token': token,
        'id': 'search',
        'active': true,
      });
      expect(search.isActive, true);
    }, variant: macOS);
  });

  group('iOS', () {
    testWidgets(
      'iOS 26+: a UIToolbar platform view with the same items',
      (tester) async {
        final log = <String>[];
        final calls = <MethodCall>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          calls.add(call);
          return null;
        });
        for (var id = 0; id < 10; id++) {
          messenger.setMockMethodCallHandler(MethodChannel('CNToolbar_$id'), (
            call,
          ) async {
            calls.add(call);
            return null;
          });
        }
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          for (var id = 0; id < 10; id++) {
            messenger.setMockMethodCallHandler(
              MethodChannel('CNToolbar_$id'),
              null,
            );
          }
        });
        final key = GlobalKey<_HostState>();
        await tester.pumpWidget(_Host(key: key, log: log));
        await tester.pumpAndSettle();

        final view = tester.widget<UiKitView>(find.byType(UiKitView));
        expect(view.viewType, 'CNToolbar');
        expect(tester.getSize(find.byType(UiKitView)).height, 44);
        final params = view.creationParams as Map<String, Object?>;
        expect(params.containsKey('token'), isFalse);
        expect(params['isDark'], false);
        expect(_item(params, 'compose')['style'], 'prominent');

        key.currentState!.update(() => key.currentState!.badge = 7);
        await tester.pumpAndSettle();
        final setItems = calls.lastWhere((c) => c.method == 'setItems');
        expect(_item(setItems.arguments as Map, 'compose')['badge'], {
          'type': 'count',
          'value': 7,
        });

        // The view's events.
        final create = calls.firstWhere((c) => c.method == 'create');
        final id = (create.arguments as Map)['id'] as int;
        await messenger.handlePlatformMessage(
          'CNToolbar_$id',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onButtonPressed', {'id': 'compose'}),
          ),
          (_) {},
        );
        await messenger.handlePlatformMessage(
          'CNToolbar_$id',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSegmentSelected', {
              'id': 'view',
              'index': 1,
              'selected': [1],
            }),
          ),
          (_) {},
        );
        expect(log, ['compose', 'view 1', 'selection {1}']);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      // The native path needs PlatformVersion's real platform: a Mac.
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'the Flutter toolbar where there is no native one',
      (tester) async {
        final log = <String>[];
        await tester.pumpWidget(_Host(log: log));
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsNothing);
        expect(tester.getSize(find.byType(CNToolbar)).height, 44);
        // Buttons by their labels; the search and sidebar items are left out,
        // as on iOS.
        expect(find.bySemanticsLabel('New Message'), findsOneWidget);
        expect(find.bySemanticsLabel('Search'), findsNothing);
        await tester.tap(find.bySemanticsLabel('New Message'));
        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pump();
        expect(log, ['compose', 'back']);
        expect(
          find.byType(CupertinoSlidingSegmentedControl<int>),
          findsOneWidget,
        );
        expect(find.text('3'), findsOneWidget, reason: 'the badge');
        // CNIcon's platform view guard.
        await tester.pump(const Duration(seconds: 1));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });
}
