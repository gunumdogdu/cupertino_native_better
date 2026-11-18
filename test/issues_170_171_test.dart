import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dart side of #170 (glass shadow, initial text) and #171 (placeholder
/// and clear-button colours) for CNSearchBar. The native-path tests run on a
/// macOS 26+ host with the target platform set to iOS.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  void listen(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
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
  }

  Map<Object?, Object?> creationParams() {
    final create = calls.lastWhere((c) => c.method == 'create');
    final bytes = (create.arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
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

  Widget app(Widget child) => CupertinoApp(
    home: CupertinoPageScaffold(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  group('#170 CNSearchBar native (iOS 26)', () {
    testWidgets(
      'initialText is the view\'s text and is not reported as a change',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester);
        final changes = <String>[];
        await tester.pumpWidget(
          app(
            CNSearchBar(
              expandable: false,
              initialText: 'Land Cruiser',
              onChanged: changes.add,
            ),
          ),
        );
        await settle(tester);
        expect(creationParams()['text'], 'Land Cruiser');
        expect(changes, isEmpty);
        await tearDownView(tester);
      },
      skip: skip,
    );

    testWidgets(
      'keeps the glass shadow by default: not clipped to the capsule',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        listen(tester);
        await tester.pumpWidget(app(const CNSearchBar(expandable: false)));
        await settle(tester);
        expect(creationParams()['glassShadow'], isTrue);
        expect(
          find.ancestor(
            of: find.byType(UiKitView),
            matching: find.byType(ClipRRect),
          ),
          findsNothing,
        );
        await tearDownView(tester);
      },
      skip: skip,
    );

    testWidgets('glassShadow: false clips the view to the capsule again', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        app(const CNSearchBar(expandable: false, glassShadow: false)),
      );
      await settle(tester);
      expect(creationParams()['glassShadow'], isFalse);
      expect(
        find.ancestor(
          of: find.byType(UiKitView),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
      await tearDownView(tester);
    }, skip: skip);
  });

  group('#171 CNSearchBar colours (native)', () {
    testWidgets('sends the placeholder and clear-icon colours', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        app(
          const CNSearchBar(
            expandable: false,
            placeholderColor: Color(0xFFFF0000),
            clearIcon: CNSymbol('xmark.circle.fill', color: Color(0xFF00FF00)),
          ),
        ),
      );
      await settle(tester);
      final params = creationParams();
      expect(params['placeholderColor'], 0xFFFF0000);
      expect(params['clearIconColor'], 0xFF00FF00);
      await tearDownView(tester);
    }, skip: skip);

    testWidgets('no clearIconColor without a clear-icon colour', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      listen(tester);
      await tester.pumpWidget(
        app(
          const CNSearchBar(
            expandable: false,
            placeholderColor: Color(0xFFFF0000),
          ),
        ),
      );
      await settle(tester);
      expect(creationParams().containsKey('clearIconColor'), isFalse);
      await tearDownView(tester);
    }, skip: skip);
  });

  group('Flutter fallback', () {
    setUp(() => PlatformVersion.debugForceFallbacks = true);
    tearDown(PlatformVersion.reset);

    testWidgets('#170 initialText fills the field without onChanged', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final changes = <String>[];
      await tester.pumpWidget(
        app(
          CNSearchBar(
            expandable: false,
            initialText: 'Land Cruiser',
            onChanged: changes.add,
          ),
        ),
      );
      await tester.pump();
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.controller!.text, 'Land Cruiser');
      expect(changes, isEmpty);
      // The clear button shows, as it does for typed text.
      expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsOneWidget);
      await tearDownView(tester);
    });

    testWidgets('#171 the clear icon takes clearIcon.color', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        app(
          const CNSearchBar(
            expandable: false,
            initialText: 'a',
            placeholderColor: Color(0xFFFF0000),
            clearIcon: CNSymbol('xmark.circle.fill', color: Color(0xFF00FF00)),
          ),
        ),
      );
      await tester.pump();
      final icon = tester.widget<Icon>(
        find.byIcon(CupertinoIcons.xmark_circle_fill),
      );
      expect(icon.color, const Color(0xFF00FF00));
      final field = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(field.placeholderStyle!.color, const Color(0xFFFF0000));
      await tearDownView(tester);
    });
  });
}
