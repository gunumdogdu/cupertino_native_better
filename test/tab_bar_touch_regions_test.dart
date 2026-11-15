import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

/// #162: the native bar sits 14 pt below the top of its platform view, and
/// the iOS 26 capsule doesn't fill the bar's width. The native bar reports
/// where it takes touches, and a touch elsewhere on the view goes to the
/// Flutter content behind the bar, as it would in a native app.
void main() {
  late List<MethodCall> platformViewCalls;
  late List<int> createdIds;

  // The bar is 800 x 63 at the bottom of the 800 x 600 test surface.
  const barTop = 600.0 - 63.0;
  // The capsule as the native bar reports it, in the view's coordinates:
  // 14 pt below the view's top, 300 pt wide in the middle.
  const capsule = <double>[250, 14, 300, 49];

  Future<int> pumpBar(
    WidgetTester tester, {
    required VoidCallback onBehind,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    platformViewCalls = <MethodCall>[];
    createdIds = <int>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      platformViewCalls.add(call);
      if (call.method == 'create') {
        createdIds.add((call.arguments as Map)['id'] as int);
      }
      return null;
    });
    for (var id = 0; id < 200; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativeTabBar_$id'),
        (call) async {
          if (call.method == 'getIntrinsicSize') {
            return {'width': 800.0, 'height': 63.0};
          }
          return null;
        },
      );
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 200; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeTabBar_$id'),
          null,
        );
      }
    });

    await tester.pumpWidget(
      CupertinoApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBehind,
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: CNTabBar(
                items: const [
                  CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                  CNTabBarItem(
                    label: 'Search',
                    icon: CNSymbol('magnifyingglass'),
                  ),
                  CNTabBarItem(label: 'Profile', icon: CNSymbol('person')),
                ],
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
    // Past PlatformViewGuard's debug delay, then let the native bar land.
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(createdIds, isNotEmpty, reason: 'the native bar was created');
    return createdIds.last;
  }

  Future<void> report(WidgetTester tester, int id, Object? regions) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'CupertinoNativeTabBar_$id',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('touchRegions', regions),
      ),
      (_) {},
    );
    await tester.pump();
  }

  int rejected() =>
      platformViewCalls.where((c) => c.method == 'rejectGesture').length;

  Future<void> tearDownBar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  final skip = !(Platform.isMacOS || Platform.isIOS);

  testWidgets(
    'until the native bar reports where it takes touches, it takes every touch on its view',
    (tester) async {
      var behind = 0;
      await pumpBar(tester, onBehind: () => behind++);

      await tester.tapAt(
        const Offset(400, barTop + 5),
      ); // the room above the bar
      await tester.tapAt(const Offset(20, barTop + 40)); // beside the capsule
      await tester.tapAt(const Offset(400, barTop + 40)); // on the capsule
      await tester.pump();

      expect(behind, 0);
      expect(rejected(), 0);
      await tearDownBar(tester);
    },
    skip: skip,
  );

  testWidgets(
    'taps above and beside the reported capsule reach the content behind; taps on it stay with the bar (#162)',
    (tester) async {
      var behind = 0;
      final id = await pumpBar(tester, onBehind: () => behind++);
      await report(tester, id, [capsule]);

      // The 14 pt room above the bar, straight above the capsule.
      await tester.tapAt(const Offset(400, barTop + 5));
      await tester.pump();
      expect(
        behind,
        1,
        reason: 'a tap in the room above the bar reaches the content',
      );
      expect(rejected(), 1, reason: 'the native view lets go of that touch');

      // Beside the capsule, at the bar's height.
      await tester.tapAt(const Offset(20, barTop + 40));
      await tester.tapAt(const Offset(780, barTop + 40));
      await tester.pump();
      expect(behind, 3, reason: 'taps beside the capsule reach the content');
      expect(rejected(), 3);

      // On the capsule, at its edges and in the middle.
      await tester.tapAt(const Offset(400, barTop + 40));
      await tester.tapAt(const Offset(251, barTop + 15));
      await tester.tapAt(const Offset(549, barTop + 62));
      await tester.pump();
      expect(behind, 3, reason: 'taps on the capsule stay with the native bar');
      expect(rejected(), 3);

      await tearDownBar(tester);
    },
    skip: skip,
  );

  testWidgets(
    'a split bar reports two capsules, and the gap between them reaches the content',
    (tester) async {
      var behind = 0;
      final id = await pumpBar(tester, onBehind: () => behind++);
      await report(tester, id, [
        <double>[0, 14, 300, 49],
        <double>[500, 14, 100, 49],
      ]);

      await tester.tapAt(const Offset(150, barTop + 40));
      await tester.tapAt(const Offset(550, barTop + 40));
      await tester.pump();
      expect(behind, 0, reason: 'both capsules take their taps');

      await tester.tapAt(const Offset(400, barTop + 40));
      await tester.pump();
      expect(
        behind,
        1,
        reason: 'the gap between the capsules reaches the content',
      );

      await tearDownBar(tester);
    },
    skip: skip,
  );

  testWidgets(
    'a report of no regions gives every touch on the view back to the bar',
    (tester) async {
      var behind = 0;
      final id = await pumpBar(tester, onBehind: () => behind++);
      await report(tester, id, [capsule]);
      await report(tester, id, null);

      await tester.tapAt(const Offset(400, barTop + 5));
      await tester.tapAt(const Offset(20, barTop + 40));
      await tester.pump();
      expect(behind, 0);

      await report(tester, id, <Object?>[]);
      await tester.tapAt(const Offset(400, barTop + 5));
      await tester.pump();
      expect(behind, 0, reason: 'an empty list counts as none');

      await tearDownBar(tester);
    },
    skip: skip,
  );
}
