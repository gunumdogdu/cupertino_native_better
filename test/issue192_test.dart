import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #192: CNSearchBar takes maxLength and inputFormatters, autofocus works on
/// a bar open from the start, and CNSearchBarFormField works in a Form. The
/// sheet content painted after a native view is covered in
/// `issue192_slice_bridge_test.dart`.
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

  group('#192 autofocus on a bar open from the start', () {
    testWidgets('sent for an open bar, not for a collapsed one', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester, 'CNSearchBar');
      await tester.pumpWidget(
        host(const CNSearchBar(expandable: false, autofocus: true)),
      );
      await settle(tester);
      expect(creationParams()['autofocusOnOpen'], isTrue);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      await tester.pumpWidget(host(const CNSearchBar(autofocus: true)));
      await settle(tester);
      expect(creationParams()['autofocusOnOpen'], isFalse);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('the bar drawn in Flutter focuses its field', (tester) async {
      PlatformVersion.debugForceFallbacks = true;
      addTearDown(PlatformVersion.reset);
      await tester.pumpWidget(
        host(const CNSearchBar(expandable: false, autofocus: true)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .autofocus,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
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
  });

  group('#192 CNSearchBarFormField', () {
    testWidgets('validate, save and reset; no error shown', (tester) async {
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
      // No error state: the system search field has none.
      expect(find.text('Please enter a name'), findsNothing);

      await tester.enterText(find.byType(CupertinoTextField), 'Van');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
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
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
