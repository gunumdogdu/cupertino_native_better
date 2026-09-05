import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'unchanged rebuilds do not resend button and menu state',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <String, List<MethodCall>>{};
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final channel = '${args['viewType']}_${args['id']}';
          calls[channel] = [];
          messenger.setMockMethodCallHandler(MethodChannel(channel), (
            call,
          ) async {
            calls[channel]!.add(call);
            if (call.method == 'getIntrinsicSize') {
              return {'width': 44.0, 'height': 44.0};
            }
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in calls.keys) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), null);
        }
      });
      PlatformViewGuard.ensureScheduled();
      await tester.pump(const Duration(milliseconds: 500));

      var enabled = true;
      var hasCallback = true;
      var checked = false;
      var destructive = false;
      Future<void> rebuild() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  CNButton(
                    label: 'Refresh',
                    enabled: enabled,
                    onPressed: hasCallback ? () {} : null,
                  ),
                  CNButton.icon(
                    key: const ValueKey('fixedIcon'),
                    icon: const CNSymbol('chevron.left'),
                    config: const CNButtonConfig(width: 32, minHeight: 32),
                    onPressed: () {},
                  ),
                  CNButton(
                    key: const ValueKey('verticalIcon'),
                    label: 'Above',
                    icon: const CNSymbol('arrow.up'),
                    config: const CNButtonConfig(
                      imagePlacement: CNImagePlacement.top,
                    ),
                    onPressed: () {},
                  ),
                  CNPopupMenuButton.icon(
                    buttonIcon: const CNSymbol('ellipsis'),
                    items: [
                      CNPopupMenuItem(
                        label: 'Item',
                        checked: checked,
                        enabled: enabled,
                        isDestructive: destructive,
                      ),
                    ],
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      List<MethodCall> sent(String method) => calls.values
          .expand((values) => values)
          .where((call) => call.method == method)
          .toList();
      void clear() {
        for (final values in calls.values) {
          values.clear();
        }
      }

      await rebuild();
      expect(calls.length, 4);
      expect(sent('getIntrinsicSize').length, 2);
      expect(
        tester.getSize(find.byKey(const ValueKey('fixedIcon'))),
        const Size(32, 32),
      );
      clear();
      for (var i = 0; i < 10; i++) {
        await rebuild();
      }
      expect(
        {
          'setEnabled': sent('setEnabled').length,
          'setItems': sent('setItems').length,
        },
        {'setEnabled': 0, 'setItems': 0},
      );

      enabled = false;
      checked = true;
      destructive = true;
      await rebuild();
      expect(sent('setEnabled').single.arguments, {'enabled': false});
      final menu = sent('setItems').single.arguments as Map;
      expect(menu['enabled'], [false]);
      expect(menu['checked'], [true]);
      expect(menu['isDestructive'], [true]);
      clear();
      await rebuild();
      expect(sent('setEnabled'), isEmpty);
      expect(sent('setItems'), isEmpty);

      enabled = true;
      await rebuild();
      expect(sent('setEnabled').single.arguments, {'enabled': true});
      clear();
      hasCallback = false;
      await rebuild();
      expect(sent('setEnabled').single.arguments, {'enabled': false});
      clear();
      hasCallback = true;
      await rebuild();
      expect(sent('setEnabled').single.arguments, {'enabled': true});
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.supportsLiquidGlass,
  );
}
