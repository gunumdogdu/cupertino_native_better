import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a [CNSearchBar] and records what it reports.
class _Host extends StatefulWidget {
  const _Host({super.key, this.expandable = true, this.controller});

  final bool expandable;
  final CNSearchBarController? controller;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final events = <String>[];
  Color? tint;

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: CupertinoPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CNSearchBar(
              placeholder: 'Find',
              expandable: widget.expandable,
              tint: tint,
              controller: widget.controller,
              recentsAutosaveName: 'recents',
              onChanged: (t) => events.add('changed $t'),
              onSubmitted: (t) => events.add('submitted $t'),
              onCancelTap: () => events.add('cancel'),
              onExpandStateChanged: (open) =>
                  events.add(open ? 'expanded' : 'collapsed'),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  late List<MethodCall> calls;
  late int viewId;

  Future<GlobalKey<_HostState>> pumpNative(
    WidgetTester tester,
    TargetPlatform platform, {
    bool expandable = true,
    CNSearchBarController? controller,
  }) async {
    calls = <MethodCall>[];
    debugDefaultTargetPlatformOverride = platform;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        viewId = (call.arguments as Map)['id'] as int;
        calls.add(call);
      }
      return null;
    });
    for (var id = 0; id < 20; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('CNSearchBar_$id'), (
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
          MethodChannel('CNSearchBar_$id'),
          null,
        );
      }
    });
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      _Host(key: key, expandable: expandable, controller: controller),
    );
    await tester.pumpAndSettle();
    return key;
  }

  MethodCall create() => calls.firstWhere((c) => c.method == 'create');

  Map<Object?, Object?> creationParams() {
    final bytes = (create().arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  /// What the widget sent the view, without the creation and the route
  /// transition state it sends to every view (#29).
  List<MethodCall> sent() => calls
      .where((c) => c.method != 'create' && c.method != 'setTransitioning')
      .toList();

  Future<void> fromNative(
    WidgetTester tester,
    String method, [
    Object? args,
  ]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'CNSearchBar_$viewId',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  /// Removes the view and the platform override inside the test body, as
  /// the binding checks the override is unset when the body returns.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  }

  group('CNSearchBar on macOS', () {
    testWidgets(
      'is an NSSearchField view with the recents name',
      (tester) async {
        await pumpNative(tester, TargetPlatform.macOS);
        expect((create().arguments as Map)['viewType'], 'CNSearchBar');
        expect(find.byType(AppKitView), findsOneWidget);
        final params = creationParams();
        expect(params['placeholder'], 'Find');
        expect(params['expandable'], true);
        expect(params['recentsAutosaveName'], 'recents');
        expect(sent(), isEmpty, reason: 'nothing changed since creation');
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'starts as a button and opens to the width of its parent',
      (tester) async {
        await pumpNative(tester, TargetPlatform.macOS);
        expect(tester.getSize(find.byType(AppKitView)).width, 44);
        await fromNative(tester, 'expanded');
        final parent = tester.getSize(find.byType(Column)).width;
        expect(tester.getSize(find.byType(AppKitView)).width, parent);
        expect(tester.takeException(), isNull);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'an always open field is as wide as its parent',
      (tester) async {
        await pumpNative(tester, TargetPlatform.macOS, expandable: false);
        final parent = tester.getSize(find.byType(Column)).width;
        expect(tester.getSize(find.byType(AppKitView)).width, parent);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'reports what the field does',
      (tester) async {
        final controller = CNSearchBarController();
        final key = await pumpNative(
          tester,
          TargetPlatform.macOS,
          controller: controller,
        );
        await fromNative(tester, 'expanded');
        expect(controller.isExpanded, isTrue);
        await fromNative(tester, 'textChanged', {'text': 'fl'});
        await fromNative(tester, 'submitted', {'text': 'fl'});
        await fromNative(tester, 'textChanged', {'text': ''});
        await fromNative(tester, 'collapsed');
        await fromNative(tester, 'cancelTapped');
        expect(controller.isExpanded, isFalse);
        expect(key.currentState!.events, [
          'expanded',
          'changed fl',
          'submitted fl',
          'changed ',
          'collapsed',
          'cancel',
        ]);
        // Nothing reported is sent back to the field.
        expect(sent(), isEmpty);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'the controller drives the field',
      (tester) async {
        final controller = CNSearchBarController();
        await pumpNative(tester, TargetPlatform.macOS, controller: controller);
        await controller.expand();
        await controller.setText('swift');
        await controller.focus();
        await controller.unfocus();
        await controller.clear();
        await controller.collapse();
        expect(sent().map((c) => c.method), [
          'expand',
          'setText',
          'focus',
          'unfocus',
          'clear',
          'collapse',
        ]);
        expect(sent()[1].arguments, {'text': 'swift'});
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'sends a new tint to the field',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.macOS);
        key.currentState!.update(
          () => key.currentState!.tint = const Color(0xFF34C759),
        );
        await tester.pumpAndSettle();
        expect(sent().map((c) => c.method), ['setConfig']);
        expect((sent().single.arguments as Map)['tint'], 0xFF34C759);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );
  });

  group('CNSearchBar on iOS 26+', () {
    testWidgets(
      'keeps its SwiftUI view and options',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.iOS);
        expect(find.byType(UiKitView), findsOneWidget);
        expect(creationParams().keys, isNot(contains('recentsAutosaveName')));
        expect(creationParams()['placeholder'], 'Find');
        // The macOS options are not sent to the iOS view.
        key.currentState!.update(
          () => key.currentState!.tint = const Color(0xFF34C759),
        );
        await tester.pumpAndSettle();
        expect(sent(), isEmpty);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
