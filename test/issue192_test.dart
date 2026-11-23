import 'dart:io' show Platform;
import 'dart:ui' show FakeViewPadding;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #192: a CNTabBar kept under modals is left out of the scene while the
/// keyboard is up over a modal; CNSearchBar takes maxLength,
/// inputFormatters and errorText, and CNSearchBarFormField works in a Form.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  void listen(
    WidgetTester tester,
    String prefix, {
    Object? Function(MethodCall)? reply,
  }) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    for (var id = 0; id < 20; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('${prefix}_$id'), (
        call,
      ) async {
        calls.add(call);
        return reply?.call(call);
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

  Map<Object?, Object?> creationParams() {
    final create = calls.lastWhere((c) => c.method == 'create');
    final bytes = (create.arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  int viewId() =>
      ((calls.lastWhere((c) => c.method == 'create').arguments as Map)['id']
              as num)
          .toInt();

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

  Future<void> fromNative(
    WidgetTester tester,
    String method,
    Object? args,
  ) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'CNSearchBar_${viewId()}',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  Widget host(Widget child) => CupertinoApp(
    navigatorObservers: [CNTabBarRouteObserver()],
    home: CupertinoPageScaffold(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  group('#192 CNSearchBar maxLength and inputFormatters (native)', () {
    testWidgets('maxLength is sent at creation and on change', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNSearchBar');
      await tester.pumpWidget(
        host(const CNSearchBar(expandable: false, maxLength: 5)),
      );
      await settle(tester);
      expect(creationParams()['maxLength'], 5);
      await tester.pumpWidget(
        host(const CNSearchBar(expandable: false, maxLength: 3)),
      );
      await settle(tester);
      expect(named('setMaxLength').single.arguments, {'maxLength': 3});
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('a longer native text is cut and sent back', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNSearchBar');
      final changes = <String>[];
      await tester.pumpWidget(
        host(
          CNSearchBar(expandable: false, maxLength: 4, onChanged: changes.add),
        ),
      );
      await settle(tester);
      await fromNative(tester, 'textChanged', {'text': 'abcdef'});
      expect(changes, ['abcd']);
      expect(
        named('textChanged').map((c) => (c.arguments as Map)['text']),
        contains('abcd'),
      );
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('inputFormatters run on native changes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNSearchBar');
      final changes = <String>[];
      await tester.pumpWidget(
        host(
          CNSearchBar(
            expandable: false,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: changes.add,
          ),
        ),
      );
      await settle(tester);
      await fromNative(tester, 'textChanged', {'text': '1'});
      await fromNative(tester, 'textChanged', {'text': '1a'});
      await fromNative(tester, 'textChanged', {'text': '12'});
      // "1a" is formatted back to "1", which changes nothing for Flutter.
      expect(changes, ['1', '12']);
      expect(
        named('textChanged').map((c) => (c.arguments as Map)['text']),
        contains('1'),
      );
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('initialText is cut to maxLength', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNSearchBar');
      await tester.pumpWidget(
        host(
          const CNSearchBar(
            expandable: false,
            maxLength: 3,
            initialText: 'abcdef',
          ),
        ),
      );
      await settle(tester);
      expect(creationParams()['text'], 'abc');
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#192 CNSearchBar errorText (native)', () {
    testWidgets('error text and outline, without a new native view', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNSearchBar');
      Widget bar(String error) =>
          host(CNSearchBar(expandable: false, errorText: error));
      await tester.pumpWidget(bar(''));
      await settle(tester);
      expect(creationParams().containsKey('errorColor'), isFalse);
      expect(find.text('Required'), findsNothing);

      await tester.pumpWidget(bar('Required'));
      await settle(tester);
      expect(find.text('Required'), findsOneWidget);
      expect((named('setError').last.arguments as Map)['color'], isA<int>());

      await tester.pumpWidget(bar(''));
      await settle(tester);
      expect(find.text('Required'), findsNothing);
      expect(
        (named('setError').last.arguments as Map).containsKey('color'),
        isFalse,
      );
      // The field was never created again.
      expect(named('create'), hasLength(1));
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#192 bar drawn in Flutter', () {
    testWidgets('maxLength and inputFormatters limit typing', (tester) async {
      PlatformVersion.debugForceFallbacks = true;
      addTearDown(PlatformVersion.reset);
      final changes = <String>[];
      await tester.pumpWidget(
        host(
          CNSearchBar(
            expandable: false,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '1a2345');
      await tester.pump();
      expect(changes.last, '123');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('errorText shows under the bar', (tester) async {
      PlatformVersion.debugForceFallbacks = true;
      addTearDown(PlatformVersion.reset);
      await tester.pumpWidget(
        host(const CNSearchBar(expandable: false, errorText: 'Too short')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Too short'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('#192 CNSearchBarFormField', () {
    testWidgets('validate, save and reset', (tester) async {
      PlatformVersion.debugForceFallbacks = true;
      addTearDown(PlatformVersion.reset);
      final formKey = GlobalKey<FormState>();
      String? saved;
      await tester.pumpWidget(
        host(
          Form(
            key: formKey,
            child: CNSearchBarFormField(
              initialValue: 'Car',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Please enter a name' : null,
              onSaved: (v) => saved = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(formKey.currentState!.validate(), isTrue);

      await tester.enterText(find.byType(CupertinoTextField), '');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Please enter a name'), findsOneWidget);

      await tester.enterText(find.byType(CupertinoTextField), 'Van');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Please enter a name'), findsNothing);
      formKey.currentState!.save();
      expect(saved, 'Van');

      formKey.currentState!.reset();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller!
            .text,
        'Car',
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('autovalidateMode.onUserInteraction', (tester) async {
      PlatformVersion.debugForceFallbacks = true;
      addTearDown(PlatformVersion.reset);
      await tester.pumpWidget(
        host(
          CNSearchBarFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => (v ?? '').length < 3 ? 'At least 3' : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('At least 3'), findsNothing);
      await tester.enterText(find.byType(CupertinoTextField), 'ab');
      await tester.pump();
      expect(find.text('At least 3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('#192 CNTabBar under the keyboard over a modal', () {
    Future<void> pumpTabBar(WidgetTester tester, {required bool hide}) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(
        tester,
        'CupertinoNativeTabBar',
        reply: (call) => call.method == 'getIntrinsicSize'
            ? {'width': 300.0, 'height': 63.0}
            : null,
      );
      await tester.pumpWidget(
        CupertinoApp(
          navigatorObservers: [CNTabBarRouteObserver()],
          home: Align(
            alignment: Alignment.bottomCenter,
            child: CNTabBar(
              autoHideOnModal: hide,
              items: const [
                CNTabBarItem(label: 'One', icon: CNSymbol('1.circle')),
                CNTabBarItem(label: 'Two', icon: CNSymbol('2.circle')),
              ],
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
    }

    int? paintedIndex(WidgetTester tester) {
      final stacks = find.descendant(
        of: find.byType(CNTabBar, skipOffstage: false),
        matching: find.byType(IndexedStack, skipOffstage: false),
        skipOffstage: false,
      );
      if (stacks.evaluate().isEmpty) return null;
      return tester.widget<IndexedStack>(stacks.first).index;
    }

    Future<void> openModal(WidgetTester tester) async {
      final context = tester.element(find.byType(CNTabBar));
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => const SizedBox(height: 200),
      );
      await settle(tester);
    }

    testWidgets('is left out of the scene, and kept mounted', (tester) async {
      await pumpTabBar(tester, hide: false);
      expect(paintedIndex(tester), 1);
      final creates = named('create').length;

      // A modal without the keyboard: the bar stays painted.
      await openModal(tester);
      expect(paintedIndex(tester), 1);

      // The keyboard comes up over the modal.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);
      expect(paintedIndex(tester), 0);

      // It goes down: painted again, by the same native view.
      tester.view.viewInsets = FakeViewPadding.zero;
      await settle(tester);
      expect(paintedIndex(tester), 1);
      expect(named('create'), hasLength(creates));
      // Close the modal: the observer's depth is shared by every test.
      Navigator.of(tester.element(find.byType(CNTabBar))).pop();
      await settle(tester);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('the keyboard without a modal changes nothing', (tester) async {
      await pumpTabBar(tester, hide: false);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);
      expect(paintedIndex(tester), 1);
      await tearDownView(tester);
    }, skip: skip);
  });
}
