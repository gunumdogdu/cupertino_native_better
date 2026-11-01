import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

void main() {
  // Own file so `PlatformViewGuard` starts un-ready: its static state is
  // per-isolate and other test files drain it. Skipped off Apple hosts
  // because CNIcon picks its native path from the host OS.
  testWidgets('CNIcon draws no circle placeholder while guard is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: CNIcon(symbol: CNSymbol('line.3.horizontal', size: 18)),
        ),
      ),
    );

    expect(find.byIcon(CupertinoIcons.circle_fill), findsNothing);
    expect(tester.getSize(find.byType(CNIcon)), const Size(18, 18));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  }, skip: !(Platform.isMacOS || Platform.isIOS));
}
