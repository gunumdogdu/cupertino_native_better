import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int?> unselectedColor(
    WidgetTester tester, {
    Brightness? theme,
    Brightness system = Brightness.light,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = system;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      CupertinoApp(
        theme: CupertinoThemeData(brightness: theme),
        home: CNSegmentedControl(
          labels: const ['One', 'Two'],
          selectedIndex: 0,
          onValueChanged: (_) {},
        ),
      ),
    );
    return tester
        .widget<CupertinoSegmentedControl<int>>(
          find.byType(CupertinoSegmentedControl<int>),
        )
        .unselectedColor
        ?.toARGB32();
  }

  group('CNSegmentedControl fallback follows the app theme', () {
    testWidgets('light theme on a dark system stays white', (tester) async {
      expect(
        await unselectedColor(
          tester,
          theme: Brightness.light,
          system: Brightness.dark,
        ),
        0xFFFFFFFF,
      );
    });

    testWidgets('dark theme on a light system is black', (tester) async {
      expect(await unselectedColor(tester, theme: Brightness.dark), 0xFF000000);
    });

    testWidgets('no theme brightness takes the system', (tester) async {
      expect(
        await unselectedColor(tester, system: Brightness.dark),
        0xFF000000,
      );
    });
  });
}
