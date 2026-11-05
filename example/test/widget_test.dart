// The example's home page builds (Flutter fallbacks on the test host).

import 'package:cupertino_native_better_example/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Android: every widget takes its Flutter fallback, no platform views.
  testWidgets(
    'the example home lists the showcase and the components',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Showcase'), findsWidgets);
      expect(find.text('Components'), findsWidgets);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
