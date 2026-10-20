import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

void main() {
  // Own file so `PlatformViewGuard` starts un-ready: its static state is
  // per-isolate and other test files drain it.
  testWidgets(
    'CNTabBar shows no CupertinoTabBar fallback before the native bar lands',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(
        CupertinoApp(
          home: Align(
            alignment: Alignment.bottomCenter,
            child: CNTabBar(
              items: const [
                CNTabBarItem(label: 'Home', icon: CNSymbol('house')),
                CNTabBarItem(label: 'Profile', icon: CNSymbol('person')),
              ],
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(CupertinoTabBar), findsNothing);
      expect(tester.getSize(find.byType(CNTabBar)).height, 50);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );
}
