// #120: the native segmented control gets taps and horizontal drags, so a
// press on one segment can slide to another inside a scrolling list, while a
// vertical drag that starts on it still scrolls the list.

import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [PlatformVersion.shouldUseNativeControls] reads the real [Platform]: the
/// native path only exists in a test running on a Mac.
final bool _notOnMac = !Platform.isMacOS;

void main() {
  void mockNative(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
    for (var id = 0; id < 10; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativeSegmentedControl_$id'),
        (_) async => null,
      );
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 10; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeSegmentedControl_$id'),
          null,
        );
      }
    });
  }

  Set<Type> recognizerTypes(
    Set<Factory<OneSequenceGestureRecognizer>> factories,
  ) => {for (final f in factories) f.type};

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets(
      '${platform.name}: taps and horizontal drags go to the native control',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        mockNative(tester);
        await tester.pumpWidget(
          CupertinoApp(
            home: ListView(
              children: [
                CNSegmentedControl(
                  labels: const ['One', 'Two', 'Three'],
                  selectedIndex: 0,
                  onValueChanged: (_) {},
                ),
              ],
            ),
          ),
        );
        // Let PlatformViewGuard's debug delay pass.
        await tester.pump(const Duration(seconds: 1));

        final Set<Factory<OneSequenceGestureRecognizer>>? factories =
            platform == TargetPlatform.iOS
            ? tester
                  .widget<UiKitView>(find.byType(UiKitView))
                  .gestureRecognizers
            : tester
                  .widget<AppKitView>(find.byType(AppKitView))
                  .gestureRecognizers;
        expect(recognizerTypes(factories!), {
          HorizontalDragGestureRecognizer,
          TapGestureRecognizer,
        });
        // No vertical recognizer: a vertical drag still scrolls the list.
        expect(
          recognizerTypes(factories),
          isNot(contains(VerticalDragGestureRecognizer)),
        );

        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      },
      skip: _notOnMac,
    );
  }
}
