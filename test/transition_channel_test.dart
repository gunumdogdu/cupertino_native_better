import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'containment changes at transition boundaries, not every frame',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <String, List<bool>>{};
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final viewType = args['viewType'] as String;
          final channel = '${viewType}_${args['id']}';
          calls[channel] = [];
          messenger.setMockMethodCallHandler(MethodChannel(channel), (
            call,
          ) async {
            if (call.method == 'setTransitioning') {
              calls[channel]!.add((call.arguments as Map)['active'] as bool);
            }
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
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Scaffold(
            body: Column(
              children: [
                CNButton(onPressed: () {}, label: 'Open'),
                const LiquidGlassContainer(
                  config: LiquidGlassConfig(cornerRadius: 16),
                  child: SizedBox(width: 100, height: 40),
                ),
                CNPopupMenuButton.icon(
                  buttonIcon: const CNSymbol('ellipsis'),
                  items: const [CNPopupMenuItem(label: 'Item')],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.length, 3);
      final hostChannels = calls.keys.toList();
      for (final values in calls.values) {
        values.clear();
      }
      navigatorKey.currentState!.push(
        CupertinoPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Details')),
        ),
      );
      await tester.pump();
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (final channel in hostChannels) {
        expect(calls[channel], [true, false], reason: channel);
        calls[channel]!.clear();
      }
      navigatorKey.currentState!.pop();
      await tester.pump();
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (final channel in hostChannels) {
        expect(calls[channel], [true, false], reason: channel);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.supportsLiquidGlass,
  );
}
