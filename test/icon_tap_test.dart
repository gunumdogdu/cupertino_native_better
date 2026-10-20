import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';

void main() {
  testWidgets('tap on a native CNIcon reaches the enclosing button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      );
    });

    var taps = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoButton(
            onPressed: () => taps++,
            child: const CNIcon(
              symbol: CNSymbol('line.3.horizontal', size: 16),
            ),
          ),
        ),
      ),
    );
    // Let PlatformViewGuard's debug delay pass so the UiKitView is built.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump();
    expect(
      tester.allRenderObjects.whereType<RenderUiKitView>(),
      hasLength(1),
    );

    await tester.tap(find.byType(CNIcon));
    await tester.pump(const Duration(milliseconds: 500));

    expect(taps, 1);
    debugDefaultTargetPlatformOverride = null;
  }, skip: !(Platform.isMacOS || Platform.isIOS));
}
