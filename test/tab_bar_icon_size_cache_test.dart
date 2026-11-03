import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

void main() {
  // PR #107: a bar created with an iconSize must not resend its items on the
  // first rebuild after creation, since nothing changed.
  testWidgets(
    'rebuilding a bar created with iconSize sends no setItems',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async => null,
      );
      // The view id is not known up front, so listen on the first few.
      final calls = <String>[];
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeTabBar_$id'),
          (call) async {
            calls.add(call.method);
            if (call.method == 'getIntrinsicSize') {
              return {'width': 300.0, 'height': 50.0};
            }
            return null;
          },
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (var id = 0; id < 20; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('CupertinoNativeTabBar_$id'),
            null,
          );
        }
      });

      late StateSetter rebuild;
      await tester.pumpWidget(
        CupertinoApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Align(
                alignment: Alignment.bottomCenter,
                child: CNTabBar(
                  iconSize: 24,
                  items: const [
                    CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                    CNTabBarItem(label: 'Profile', icon: CNSymbol('person')),
                  ],
                  currentIndex: 0,
                  onTap: (_) {},
                ),
              );
            },
          ),
        ),
      );
      // Past PlatformViewGuard's debug delay, then let the native bar land and
      // run its delayed refresh passes.
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(calls, contains('refresh'), reason: 'the native bar was created');

      calls.clear();
      rebuild(() {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls, isNot(contains('setItems')));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !(Platform.isMacOS || Platform.isIOS),
  );
}
