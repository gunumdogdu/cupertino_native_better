import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a [CNPopUpButton] whose options a test can change.
class _Host extends StatefulWidget {
  const _Host({super.key, this.refuse});

  /// A value the parent does not accept.
  final String? refuse;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String value = 'm';
  bool enabled = true;
  bool hasCallback = true;
  CNButtonStyle? style;
  Color? tint;
  double? height;
  String label = 'Size';
  List<CNPopUpButtonEntry<String>> items = _items;
  final List<String> changes = [];

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: Center(
      child: CNPopUpButton<String>(
        value: value,
        items: items,
        enabled: enabled,
        buttonStyle: style,
        tint: tint,
        height: height,
        semanticLabel: label,
        onChanged: hasCallback
            ? (v) {
                changes.add(v);
                if (v != widget.refuse) setState(() => value = v);
              }
            : null,
      ),
    ),
  );
}

const _items = <CNPopUpButtonEntry<String>>[
  CNPopUpButtonItem(value: 's', label: 'Small'),
  CNPopUpButtonItem(value: 'm', label: 'Medium', icon: CNSymbol('star')),
  CNPopUpButtonDivider(),
  CNPopUpButtonSection(
    title: 'More',
    items: [
      CNPopUpButtonItem(value: 'l', label: 'Large'),
      CNPopUpButtonItem(value: 'x', label: 'Huge', enabled: false),
    ],
  ),
];

void main() {
  group('CNPopUpButton fallback', () {
    // The test host takes the Flutter fallback on Android.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('shows the selected label and reads label and value', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const _Host());
      expect(find.text('Medium'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(CNPopUpButton<String>)),
        matchesSemantics(
          label: 'Size',
          value: 'Medium',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
      // CNIcon's platform view guard.
      await tester.pump(const Duration(seconds: 1));
    }, variant: android);

    testWidgets('the sheet lists the items and reports a choice', (
      tester,
    ) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      // The section's header, its items, and the checkmark on the selection.
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Huge'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark), findsOneWidget);
      // A disabled item does nothing.
      await tester.tap(find.text('Huge'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(key.currentState!.changes, isEmpty);
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
      expect(key.currentState!.changes, ['l']);
      expect(find.text('Large'), findsOneWidget);
    }, variant: android);

    testWidgets('a null onChanged disables the button', (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      key.currentState!.update(() => key.currentState!.hasCallback = false);
      await tester.pump();
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
    }, variant: android);
  });

  group('CNPopUpButton native', () {
    late List<MethodCall> calls;
    late MethodChannel channel;

    Future<GlobalKey<_HostState>> pumpNative(
      WidgetTester tester,
      TargetPlatform platform, {
      String? refuse,
      Map<String, double>? reportedSize,
    }) async {
      calls = <MethodCall>[];
      debugDefaultTargetPlatformOverride = platform;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') calls.add(call);
        return null;
      });
      for (var id = 0; id < 20; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativePopUpButton_$id'),
          (call) async {
            calls.add(call);
            if (call.method == 'getIntrinsicSize') {
              return reportedSize ?? {'width': 117.0, 'height': 24.0};
            }
            return null;
          },
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (var id = 0; id < 20; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('CupertinoNativePopUpButton_$id'),
            null,
          );
        }
      });
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key, refuse: refuse));
      await tester.pumpAndSettle();
      final create = calls.lastWhere((c) => c.method == 'create');
      final id = (create.arguments as Map)['id'] as int;
      channel = MethodChannel('CupertinoNativePopUpButton_$id');
      return key;
    }

    Map<Object?, Object?> creationParams() {
      final create = calls.lastWhere((c) => c.method == 'create');
      final bytes = (create.arguments as Map)['params'] as Uint8List;
      return const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(bytes),
          )
          as Map<Object?, Object?>;
    }

    List<String> sent() => calls
        .where((c) => c.method != 'create' && c.method != 'getIntrinsicSize')
        .map((c) => '${c.method} ${c.arguments}')
        .toList();

    /// A call from the native view, as its channel delivers it.
    Future<void> fromNative(
      WidgetTester tester,
      String method,
      Object? args,
    ) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets(
      'macOS: an NSPopUpButton with the encoded menu and the selection',
      (tester) async {
        await pumpNative(tester, TargetPlatform.macOS);
        expect(find.byType(AppKitView), findsOneWidget);
        final params = creationParams();
        final items = params['items']! as Map;
        expect(items['labels'], ['Small', 'Medium', '', 'More']);
        expect(items['isDivider'], [false, false, true, false]);
        expect(items['isSubmenu'], [false, false, false, true]);
        expect(items['submenuStyles'], [null, null, null, 'inline']);
        expect(items['sfSymbols'], ['', 'star', '', '']);
        // The native view marks the selection; nothing is sent checked.
        expect(items['checked'], [false, false, false, false]);
        final section = (items['submenus']! as List)[3] as Map;
        expect(section['labels'], ['Large', 'Huge']);
        expect(section['enabled'], [true, false]);
        expect(params['selectedPath'], [1]);
        expect(params['enabled'], true);
        // The default macOS pop-up is not tinted.
        expect(params['buttonStyle'], isNull);
        expect(params['tint'], isNull);
        expect(params['height'], isNull);
        expect(params['semanticLabel'], 'Size');
        expect(params['isDark'], false);
        // The default height is a regular NSPopUpButton's; the width the
        // native view reports.
        expect(tester.getSize(find.byType(AppKitView)), const Size(117, 24));
        expect(sent(), isEmpty, reason: 'nothing changed since creation');
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: sends what changes, and nothing else',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.macOS);
        final host = key.currentState!;
        host.update(() => host.value = 'l');
        await tester.pumpAndSettle();
        host.update(() => host.enabled = false);
        await tester.pumpAndSettle();
        host.update(() {
          host.style = CNButtonStyle.glass;
          host.height = 32;
        });
        await tester.pumpAndSettle();
        host.update(() => host.label = 'Font size');
        await tester.pumpAndSettle();
        host.update(
          () => host.items = [
            ..._items,
            const CNPopUpButtonItem(value: 'z', label: 'Zero'),
          ],
        );
        await tester.pumpAndSettle();
        expect(sent().take(4), [
          'setSelectedPath {path: [3, 0]}',
          'setEnabled {enabled: false}',
          'setStyle {buttonStyle: glass, tint: null, height: 32.0}',
          'setSemanticLabel {label: Font size}',
        ]);
        final setItems = calls.lastWhere((c) => c.method == 'setItems');
        final args = setItems.arguments as Map;
        expect((args['items'] as Map)['labels'], [
          'Small',
          'Medium',
          '',
          'More',
          'Zero',
        ]);
        expect(args['selectedPath'], [3, 0]);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: a choice reaches onChanged; a refused one goes back',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.macOS, refuse: 's');
        final host = key.currentState!;
        await fromNative(tester, 'valueChanged', {
          'path': [3, 0],
        });
        expect(host.changes, ['l']);
        expect(host.value, 'l');
        expect(sent(), isEmpty, reason: 'the native view shows it already');
        await fromNative(tester, 'valueChanged', {
          'path': [0],
        });
        expect(host.changes, ['l', 's']);
        expect(host.value, 'l');
        expect(sent(), ['setSelectedPath {path: [3, 0]}']);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: takes the width the native view reports later',
      (tester) async {
        await pumpNative(tester, TargetPlatform.macOS);
        await fromNative(tester, 'sizeChanged', {
          'width': 150.0,
          'height': 24.0,
        });
        expect(tester.getSize(find.byType(AppKitView)).width, 150);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'a value no item has selects the first enabled item',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.macOS);
        key.currentState!.update(() => key.currentState!.value = 'nope');
        await tester.pumpAndSettle();
        expect(sent(), ['setSelectedPath {path: [0]}']);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'iOS: a tinted UIButton; taps and a resting finger reach it',
      (tester) async {
        await pumpNative(
          tester,
          TargetPlatform.iOS,
          reportedSize: {'width': 96.0, 'height': 34.0},
        );
        final view = tester.widget<UiKitView>(find.byType(UiKitView));
        // The default iOS pop-up is plain, in the theme's primary colour.
        expect(creationParams()['tint'], CupertinoColors.systemBlue.toARGB32());
        expect(tester.getSize(find.byType(UiKitView)), const Size(96, 34));
        // A tap, and a press after the scroll view's delay; a scroll that
        // starts sooner wins against both.
        final recognizers = view.gestureRecognizers!
            .map((f) => f.constructor())
            .toList();
        expect(recognizers.whereType<TapGestureRecognizer>(), hasLength(1));
        final press = recognizers.whereType<LongPressGestureRecognizer>();
        expect(press, hasLength(1));
        expect(press.first.deadline, kCNPopUpButtonPressDelay);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });

  group('CNPopUpButton in a vertical list (iOS)', () {
    late List<MethodCall> gestures;

    Future<void> pumpList(WidgetTester tester) async {
      gestures = [];
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'acceptGesture' || call.method == 'rejectGesture') {
          gestures.add(call);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: ListView(
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(
                  height: 60,
                  child: Center(
                    child: CNPopUpButton<String>(
                      value: 's',
                      items: _items,
                      onChanged: (_) {},
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Offset buttonCenter(WidgetTester tester) =>
        tester.getCenter(find.byType(UiKitView).first);

    double scrollOffset(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets(
      'a tap goes to the native button',
      (tester) async {
        await pumpList(tester);
        await tester.tapAt(buttonCenter(tester));
        await tester.pump();
        expect(gestures.map((c) => c.method), ['acceptGesture']);
        expect(scrollOffset(tester), 0);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'a finger that rests goes to the native button before it lifts',
      (tester) async {
        await pumpList(tester);
        final gesture = await tester.startGesture(buttonCenter(tester));
        await tester.pump(const Duration(milliseconds: 200));
        expect(gestures.map((c) => c.method), ['acceptGesture']);
        await gesture.up();
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );

    testWidgets(
      'a vertical drag that starts on a button scrolls the list',
      (tester) async {
        await pumpList(tester);
        await tester.dragFrom(buttonCenter(tester), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(gestures.map((c) => c.method), ['rejectGesture']);
        expect(scrollOffset(tester), greaterThan(100));
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
