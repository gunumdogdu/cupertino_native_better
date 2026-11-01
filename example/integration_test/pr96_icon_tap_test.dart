// PR #96: a tap on a native CNIcon inside a tappable must reach the tappable.
//
//   cd example && flutter test integration_test/pr96_icon_tap_test.dart -d <device>
//
// Runs on an iOS simulator or device, where CNIcon builds its UiKitView and
// the platform view's gesture recognizer takes part in the arena.

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHost(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(CupertinoApp(home: Center(child: child)));
    // Debug builds hold platform views back for PlatformViewGuard's 500 ms.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(UiKitView), findsOneWidget);
  }

  testWidgets('CupertinoButton: a tap on the CNIcon presses the button', (
    tester,
  ) async {
    var presses = 0;
    await pumpHost(
      tester,
      CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => presses++,
        child: const CNIcon(symbol: CNSymbol('star.fill', size: 56)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(CNIcon));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(presses, 3);
  });

  testWidgets('GestureDetector: a tap on the CNIcon reaches onTap', (
    tester,
  ) async {
    var taps = 0;
    await pumpHost(
      tester,
      GestureDetector(
        onTap: () => taps++,
        child: const CNIcon(symbol: CNSymbol('heart.fill', size: 56)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(CNIcon));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(taps, 3);
  });
}
