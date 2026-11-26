import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #201: `CNGlassButtonGroup.spacingForGlass` is sent to the native view only
/// when the caller sets it, so the native default (80 for a horizontal group
/// of 2+ buttons, else 40) applies only when it is null. The native-path tests
/// run on a macOS 26+ host.
void main() {
  final skip = !(Platform.isMacOS || Platform.isIOS);
  late List<MethodCall> calls;

  setUp(() => calls = <MethodCall>[]);

  void listen(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
  }

  Map<Object?, Object?> creationParams() {
    final create = calls.where((c) => c.method == 'create').single;
    final bytes = (create.arguments as Map)['params'] as Uint8List;
    return const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(bytes),
        )
        as Map<Object?, Object?>;
  }

  Future<void> pumpGroup(WidgetTester tester, {double? spacingForGlass}) async {
    debugDefaultTargetPlatformOverride = Platform.isIOS
        ? TargetPlatform.iOS
        : TargetPlatform.macOS;
    listen(tester);
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CNGlassButtonGroup(
            spacing: 14,
            spacingForGlass: spacingForGlass,
            buttons: [
              CNButtonData.icon(
                icon: const CNSymbol('square.and.arrow.up'),
                onPressed: () {},
              ),
              CNButtonData.icon(
                icon: const CNSymbol('heart'),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tearDownView(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  test('spacingForGlass defaults to null', () {
    expect(const CNGlassButtonGroup(buttons: []).spacingForGlass, isNull);
    expect(
      const CNGlassButtonGroup.fromWidgets(buttonWidgets: []).spacingForGlass,
      isNull,
    );
  });

  testWidgets('an unset spacingForGlass is not sent, so the native default '
      'applies', (tester) async {
    await pumpGroup(tester);
    final params = creationParams();
    expect(params.containsKey('spacingForGlass'), isFalse);
    expect(params['spacing'], 14.0);
    await tearDownView(tester);
  }, skip: skip);

  testWidgets('a set spacingForGlass is sent as is, even below the default', (
    tester,
  ) async {
    await pumpGroup(tester, spacingForGlass: 10);
    expect(creationParams()['spacingForGlass'], 10.0);
    await tearDownView(tester);
  }, skip: skip);
}
