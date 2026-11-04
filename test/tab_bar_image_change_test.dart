import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:cupertino_native_better/utils/icon_renderer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// An item whose image asset or custom icon changes, with its label and
/// symbol unchanged, still reaches the native bar (setItems), on iOS and on
/// macOS alike.
void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    // A rendering memoised in an earlier test's fake-async zone never
    // completes in this one.
    clearIconImageCache();
  });

  Future<void> pumpBar(
    WidgetTester tester,
    ValueListenable<_Props> props,
    TargetPlatform platform,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    for (var id = 0; id < 20; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativeTabBar_$id'),
        (call) async {
          calls.add(call);
          if (call.method == 'getIntrinsicSize') {
            return {'width': 400.0, 'height': 63.0};
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

    await tester.pumpWidget(
      CupertinoApp(
        home: ValueListenableBuilder<_Props>(
          valueListenable: props,
          builder: (_, p, _) => Align(
            alignment: Alignment.bottomCenter,
            child: CNTabBar(
              items: [
                CNTabBarItem(
                  label: 'Home',
                  imageAsset: CNImageAsset(p.homeAsset),
                  activeImageAsset: CNImageAsset(p.homeActiveAsset),
                ),
                CNTabBarItem(label: 'Chats', customIcon: p.chatsIcon),
                CNTabBarItem(
                  label: 'Data',
                  imageAsset: CNImageAsset(
                    '',
                    imageData: p.data,
                    imageFormat: 'png',
                  ),
                ),
              ],
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    // Custom icons render to PNG with real async work before the native bar
    // is created.
    for (var i = 0; i < 16; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      calls.map((c) => c.method),
      contains('getIntrinsicSize'),
      reason: 'the native bar was not created',
    );
  }

  /// Changes the props in one rebuild and returns what that sync sent.
  Future<List<MethodCall>> change(
    WidgetTester tester,
    ValueNotifier<_Props> props,
    _Props next,
  ) async {
    final from = calls.length;
    props.value = next;
    await tester.pump();
    // The custom icons render again before setItems goes out.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    return calls
        .skip(from)
        .where((c) => c.method != 'getIntrinsicSize')
        .toList();
  }

  Future<void> tearDownBar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  // The native bar needs PlatformVersion's real platform (iOS 26+ or a Mac).
  final skip = !(Platform.isMacOS || Platform.isIOS);

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    group(platform.name, () {
      testWidgets('a rebuild with the same images sends nothing', (
        tester,
      ) async {
        final props = ValueNotifier(_Props());
        await pumpBar(tester, props, platform);

        final sent = await change(tester, props, props.value.copy());

        expect(sent, isEmpty);
        await tearDownBar(tester);
      }, skip: skip);

      testWidgets('a new image asset path sends setItems', (tester) async {
        final props = ValueNotifier(_Props());
        await pumpBar(tester, props, platform);

        final sent = await change(
          tester,
          props,
          props.value.copy(
            homeAsset: 'assets/profile.svg',
            homeActiveAsset: 'assets/profile_filled.svg',
          ),
        );

        expect(sent.map((c) => c.method), ['setItems']);
        final args = sent.single.arguments as Map;
        expect((args['imageAssetPaths'] as List).first, 'assets/profile.svg');
        expect(
          (args['activeImageAssetPaths'] as List).first,
          'assets/profile_filled.svg',
        );
        expect((args['imageAssetFormats'] as List).first, 'svg');
        await tearDownBar(tester);
      }, skip: skip);

      testWidgets('new image bytes send setItems', (tester) async {
        final props = ValueNotifier(_Props());
        await pumpBar(tester, props, platform);

        final sent = await change(
          tester,
          props,
          props.value.copy(data: Uint8List.fromList(List.filled(12, 7))),
        );

        expect(sent.map((c) => c.method), ['setItems']);
        final data = (sent.single.arguments as Map)['imageAssetData'] as List;
        expect((data.last as Uint8List).length, 12);
        await tearDownBar(tester);
      }, skip: skip);

      testWidgets('a new custom icon sends setItems', (tester) async {
        final props = ValueNotifier(_Props());
        await pumpBar(tester, props, platform);

        final sent = await change(
          tester,
          props,
          props.value.copy(chatsIcon: CupertinoIcons.chat_bubble_fill),
        );

        expect(sent.map((c) => c.method), ['setItems']);
        await tearDownBar(tester);
      }, skip: skip);
    });
  }
}

class _Props {
  _Props({
    this.homeAsset = 'assets/home.svg',
    this.homeActiveAsset = 'assets/home_filled.svg',
    this.chatsIcon = CupertinoIcons.chat_bubble,
    Uint8List? data,
  }) : data = data ?? Uint8List.fromList(List.filled(8, 1));

  final String homeAsset;
  final String homeActiveAsset;
  final IconData chatsIcon;
  final Uint8List data;

  _Props copy({
    String? homeAsset,
    String? homeActiveAsset,
    IconData? chatsIcon,
    Uint8List? data,
  }) => _Props(
    homeAsset: homeAsset ?? this.homeAsset,
    homeActiveAsset: homeActiveAsset ?? this.homeActiveAsset,
    chatsIcon: chatsIcon ?? this.chatsIcon,
    data: data ?? this.data,
  );
}
