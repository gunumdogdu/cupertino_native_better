import 'package:cupertino_native_better/components/toolbar.dart'
    show debugResetCNToolbarWindow;
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _window = MethodChannel('cn_toolbar');

class _Host extends StatefulWidget {
  const _Host({required this.log, required this.search});

  final List<String> log;
  final CNTabBarSearchController search;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: CNSearchScaffold(
      items: const [
        CNSearchScaffoldItem(label: 'Home', icon: CNSymbol('house')),
        CNSearchScaffoldItem(label: 'Search', isSearchTab: true),
        CNSearchScaffoldItem(icon: CNSymbol('gearshape')),
      ],
      currentIndex: index,
      onTap: (i) {
        widget.log.add('tap $i');
        setState(() => index = i);
      },
      searchPlaceholder: 'Search fruit',
      searchController: widget.search,
      onSearchChanged: (t) => widget.log.add('search "$t"'),
      onSearchSubmit: (t) => widget.log.add('submit "$t"'),
      onSearchActiveChanged: (a) => widget.log.add('active $a'),
      children: const [Text('home'), Text('results'), Text('settings')],
    ),
  );
}

void main() {
  tearDown(debugResetCNToolbarWindow);

  testWidgets(
    'macOS: tabs and search in the window toolbar',
    (tester) async {
      final calls = <MethodCall>[];
      final log = <String>[];
      final search = CNTabBarSearchController();
      addTearDown(search.dispose);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_window, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_window, null));
      await tester.pumpWidget(_Host(log: log, search: search));
      await tester.pumpAndSettle();

      expect(find.byType(UiKitView), findsNothing);
      expect(find.text('home'), findsOneWidget);
      Map<Object?, Object?> payload() =>
          calls.lastWhere((c) => c.method == 'setToolbar').arguments
              as Map<Object?, Object?>;
      List<Map<Object?, Object?>> items() =>
          (payload()['items'] as List).cast<Map<Object?, Object?>>();

      expect(items().map((i) => i['kind']), [
        'segmented',
        'flexibleSpace',
        'search',
      ]);
      final tabs = items().first;
      expect(tabs['role'], 'tabs');
      expect(tabs['centered'], true);
      expect(tabs['selected'], [0]);
      // The search tab is the search field, not a segment; a tab without a
      // label shows its icon.
      final segments = (tabs['segments'] as List).cast<Map<Object?, Object?>>();
      expect(segments.map((s) => s['label']), ['Home', '']);
      expect(segments.first['image'], isNull);
      expect((segments.last['image'] as Map)['symbol'], 'gearshape');
      expect(items().last['placeholder'], 'Search fruit');
      expect(items().last['label'], 'Search');

      final token = payload()['token'];
      Future<void> native(String method, Map<String, Object?> args) async {
        await messenger.handlePlatformMessage(
          'cn_toolbar',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, {'token': token, ...args}),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      // The second segment is the third item (the search tab is skipped).
      await native('onSegmentSelected', {
        'id': 'tabs',
        'index': 1,
        'selected': [1],
      });
      expect(find.text('settings'), findsOneWidget);
      // Clicking into the field selects the search tab; no tab segment is
      // selected meanwhile.
      await native('onSearchActiveChanged', {'id': 'search', 'active': true});
      expect(find.text('results'), findsOneWidget);
      expect(items().first['selected'], isEmpty);
      await native('onSearchChanged', {'id': 'search', 'text': 'an'});
      await native('onSearchSubmitted', {'id': 'search', 'text': 'an'});
      expect(search.text, 'an');
      expect(search.isActive, true);
      expect(log, [
        'tap 2',
        'tap 1',
        'active true',
        'search "an"',
        'submit "an"',
      ]);
      await tester.pumpWidget(const SizedBox());
      expect(calls.last.method, 'removeToolbar');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'other platforms: a CupertinoTabScaffold',
    (tester) async {
      final search = CNTabBarSearchController();
      addTearDown(search.dispose);
      await tester.pumpWidget(_Host(log: [], search: search));
      expect(find.byType(CupertinoTabScaffold), findsOneWidget);
      expect(find.byType(CNToolbar), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
