// macOS: CNButton, CNPopupMenuButton and LiquidGlassContainer are AppKit
// views on every macOS; CNFloatingIsland and CNGlassCard's spotlight have no
// AppKit view and stay in Flutter.

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platform views created, by view type, with their creation params.
final _created = <String, List<Map<Object?, Object?>>>{};

/// Method calls sent on the views' channels, as `method arguments`.
final _sent = <String>[];

const _channelPrefixes = [
  'CupertinoNativeButton',
  'CupertinoNativePopupMenuButton',
  'CupertinoNativeLiquidGlassContainer',
  'CNFloatingIsland',
];

void _mockNative(WidgetTester tester) {
  _created.clear();
  _sent.clear();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
    call,
  ) async {
    if (call.method == 'create') {
      final args = call.arguments as Map;
      final bytes = args['params'] as Uint8List?;
      final params = bytes == null
          ? const <Object?, Object?>{}
          : const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(bytes),
                )
                as Map<Object?, Object?>;
      _created.putIfAbsent(args['viewType'] as String, () => []).add(params);
    }
    return null;
  });
  for (final prefix in _channelPrefixes) {
    for (var id = 0; id < 30; id++) {
      messenger.setMockMethodCallHandler(MethodChannel('${prefix}_$id'), (
        call,
      ) async {
        _sent.add('${call.method} ${call.arguments}');
        if (call.method == 'getIntrinsicSize') {
          return {'width': 90.0, 'height': 36.0};
        }
        return null;
      });
    }
  }
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final prefix in _channelPrefixes) {
      for (var id = 0; id < 30; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('${prefix}_$id'),
          null,
        );
      }
    }
  });
}

Widget _app(Widget child) => CupertinoApp(
  home: CupertinoPageScaffold(child: Center(child: child)),
);

/// Removes the views and the platform override inside the test body, as the
/// binding checks the override is unset when the body returns.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  debugDefaultTargetPlatformOverride = null;
}

class _ButtonHost extends StatefulWidget {
  const _ButtonHost({super.key});

  @override
  State<_ButtonHost> createState() => _ButtonHostState();
}

class _ButtonHostState extends State<_ButtonHost> {
  bool changed = false;

  void change() => setState(() => changed = true);

  @override
  Widget build(BuildContext context) => _app(
    CNButton(
      label: 'Edit',
      semanticLabel: changed ? 'Edit photo' : null,
      onPressed: () {},
      config: CNButtonConfig(
        style: CNButtonStyle.glass,
        shrinkWrap: true,
        interaction: !changed,
        labelColor: changed ? CupertinoColors.white : null,
        labelFontWeight: changed ? FontWeight.w600 : null,
      ),
    ),
  );
}

void main() {
  // Native AppKit controls need the macOS host the tests run on.
  final skip = !PlatformVersion.shouldUseNativeControls;

  testWidgets('CNButton is an AppKit view on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    _mockNative(tester);
    await tester.pumpWidget(
      _app(
        CNButton(
          label: 'Glass',
          semanticLabel: 'Glass button',
          onPressed: () {},
          config: const CNButtonConfig(
            style: CNButtonStyle.prominentClearGlass,
            labelFontWeight: FontWeight.w600,
            shrinkWrap: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppKitView), findsOneWidget);
    expect(find.byType(CupertinoButton), findsNothing);
    final params = _created['CupertinoNativeButton']!.single;
    expect(params['buttonTitle'], 'Glass');
    expect(params['buttonStyle'], 'prominentClearGlass');
    expect(params['semanticLabel'], 'Glass button');
    expect(params['labelFontWeight'], 600);
    // The intrinsic width the native button reports sizes the slot.
    expect(tester.getSize(find.byType(AppKitView)).width, 90);
    await _finish(tester);
  }, skip: skip);

  testWidgets(
    'CNButton sends label, label style and interaction changes on macOS',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      _mockNative(tester);
      final host = GlobalKey<_ButtonHostState>();
      await tester.pumpWidget(_ButtonHost(key: host));
      await tester.pumpAndSettle();
      _sent.clear();

      host.currentState!.change();
      await tester.pumpAndSettle();

      expect(_sent, contains('setSemanticLabel {label: Edit photo}'));
      expect(_sent, contains('setInteraction {interaction: false}'));
      final labelStyle = _sent.firstWhere((s) => s.startsWith('setLabelStyle'));
      expect(labelStyle, contains('labelColor: 4294967295'));
      expect(labelStyle, contains('labelFontWeight: 600'));
      await _finish(tester);
    },
    skip: skip,
  );

  testWidgets('CNPopupMenuButton is an AppKit view on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    _mockNative(tester);
    await tester.pumpWidget(
      _app(
        CNPopupMenuButton.icon(
          buttonIcon: const CNSymbol('ellipsis'),
          semanticLabel: 'More',
          size: 40,
          items: const [
            CNPopupMenuItem(label: 'Copy', icon: CNSymbol('doc.on.doc')),
            CNPopupMenuItem(
              label: 'Chat',
              imageAsset: CNImageAsset('assets/chat.svg', size: 16),
            ),
          ],
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppKitView), findsOneWidget);
    final params = _created['CupertinoNativePopupMenuButton']!.single;
    expect(params['semanticLabel'], 'More');
    expect(params['round'], true);
    expect(params['height'], 40.0);
    expect(params['sfSymbols'], ['doc.on.doc', '']);
    expect(params['imageAssetPaths'], ['', 'assets/chat.svg']);
    expect(params['imageAssetFormats'], ['', 'svg']);
    await _finish(tester);
  }, skip: skip);

  testWidgets(
    'LiquidGlassContainer on macOS: an AppKit view with room for its shadow',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      _mockNative(tester);
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 120,
            height: 40,
            child: LiquidGlassContainer(
              config: LiquidGlassConfig(tint: CupertinoColors.systemOrange),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      // Platform views wait 500 ms after start-up in debug builds.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      final params = _created['CupertinoNativeLiquidGlassContainer']!.single;
      expect(params['inset'], 12.0);
      expect(params['shape'], 'capsule');
      // The view is larger than the child by the inset on each side.
      expect(tester.getSize(find.byType(AppKitView)), const Size(144, 64));
      await _finish(tester);
    },
    skip: skip,
  );

  testWidgets('CNFloatingIsland stays in Flutter on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    _mockNative(tester);
    await tester.pumpWidget(
      _app(const CNFloatingIsland(collapsed: Text('Now Playing'))),
    );
    await tester.pumpAndSettle();

    // No native island; its Flutter pill may use the native glass.
    expect(_created.containsKey('CNFloatingIsland'), isFalse);
    expect(find.text('Now Playing'), findsOneWidget);
    await _finish(tester);
  }, skip: skip);

  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    testWidgets(
      'CNGlassCard spotlight is drawn over native glass on ${platform.name}',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        _mockNative(tester);
        await tester.pumpWidget(
          _app(
            const CNGlassCard(
              spotlight: CNSpotlightMode.touch,
              child: Text('Card'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        // No platform registers a native spotlight card.
        expect(_created.containsKey('CNGlassCardWithSpotlight'), isFalse);
        expect(_created['CupertinoNativeLiquidGlassContainer'], hasLength(1));
        expect(find.text('Card'), findsOneWidget);
        await _finish(tester);
      },
      skip: skip,
    );
  }
}
