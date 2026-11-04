import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, LinearProgressIndicator;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a [CNProgressIndicator] whose options a test can change.
class _Host extends StatefulWidget {
  const _Host({super.key, this.indicator});

  final CNProgressIndicator? indicator;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double? value = 0.25;
  CNProgressStyle style = CNProgressStyle.bar;
  CNControlSize? size;
  Color? tint;

  void update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.indicator ??
              CNProgressIndicator(
                value: value,
                style: style,
                size: size,
                tint: tint,
                semanticLabel: 'Upload',
              ),
        ],
      ),
    ),
  );
}

void main() {
  group('CNProgressIndicator fallback', () {
    // The test host takes the Flutter fallback on Android.
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('a bar reads its label and percentage', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const _Host());
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(CNProgressIndicator)),
        matchesSemantics(label: 'Upload', value: '25%'),
      );
      semantics.dispose();
    }, variant: android);

    testWidgets('a spinner without a value is a circular indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _Host(
          indicator: CNProgressIndicator(style: CNProgressStyle.spinner),
        ),
      );
      final circle = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(circle.value, isNull);
    }, variant: android);

    testWidgets('a bar in an unbounded row gets a fixed width', (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Row(children: [CNProgressIndicator(value: 0.5)]),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CNProgressIndicator)).width, 160);
    }, variant: android);
  });

  group('CNProgressIndicator native', () {
    late List<MethodCall> calls;

    Future<GlobalKey<_HostState>> pumpNative(
      WidgetTester tester,
      TargetPlatform platform,
    ) async {
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
          MethodChannel('CupertinoNativeProgressIndicator_$id'),
          (call) async {
            calls.add(call);
            return null;
          },
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (var id = 0; id < 20; id++) {
          messenger.setMockMethodCallHandler(
            MethodChannel('CupertinoNativeProgressIndicator_$id'),
            null,
          );
        }
      });
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: key));
      await tester.pumpAndSettle();
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

    List<MethodCall> sent() =>
        calls.where((c) => c.method != 'create').toList();

    Size viewSize(WidgetTester tester) => tester.getSize(
      find.byWidgetPredicate((w) => w is AppKitView || w is UiKitView),
    );

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    }

    testWidgets(
      'macOS: a bar as wide as its parent, every option sent',
      (tester) async {
        await pumpNative(tester, TargetPlatform.macOS);
        expect(find.byType(AppKitView), findsOneWidget);
        expect(creationParams(), {
          'style': 'bar',
          'tint': null,
          'controlSize': 'regular',
          'semanticLabel': 'Upload',
          'value': 0.25,
          'isDark': false,
        });
        final parent = tester.getSize(find.byType(Column)).width;
        expect(viewSize(tester), Size(parent, 20));
        expect(sent(), isEmpty, reason: 'nothing changed since creation');
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: sends a new value to animate and a new style whole',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.macOS);
        key.currentState!.update(() => key.currentState!.value = 0.75);
        await tester.pumpAndSettle();
        key.currentState!.update(() => key.currentState!.value = 1.4);
        await tester.pumpAndSettle();
        key.currentState!.update(() => key.currentState!.value = null);
        await tester.pumpAndSettle();
        key.currentState!.update(
          () => key.currentState!.tint = const Color(0xFFFF2D55),
        );
        await tester.pumpAndSettle();
        expect(sent().map((c) => '${c.method} ${c.arguments}'), [
          'setValue {value: 0.75, animated: true}',
          'setValue {value: 1.0, animated: true}',
          'setValue {value: null, animated: true}',
          'setConfig {style: bar, tint: ${0xFFFF2D55}, controlSize: regular, '
              'semanticLabel: Upload}',
        ]);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'macOS: spinners take the NSProgressIndicator sizes',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.macOS);
        final host = key.currentState!;
        host.update(() => host.style = CNProgressStyle.spinner);
        await tester.pumpAndSettle();
        expect(viewSize(tester), const Size(32, 32));
        host.update(() => host.size = CNControlSize.small);
        await tester.pumpAndSettle();
        expect(viewSize(tester), const Size(16, 16));
        host.update(() {
          host.size = CNControlSize.mini;
          host.value = null;
        });
        await tester.pumpAndSettle();
        expect(viewSize(tester), const Size(10, 10));
        host.update(() => host.style = CNProgressStyle.bar);
        await tester.pumpAndSettle();
        expect(viewSize(tester).height, 12);
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeControls,
    );

    testWidgets(
      'iOS: a known bar is a UIProgressView track, the rest a spinner',
      (tester) async {
        final key = await pumpNative(tester, TargetPlatform.iOS);
        final host = key.currentState!;
        expect(find.byType(UiKitView), findsOneWidget);
        expect(viewSize(tester).height, 4);
        host.update(() => host.value = null);
        await tester.pumpAndSettle();
        expect(viewSize(tester), const Size(20, 20));
        host.update(() {
          host.style = CNProgressStyle.spinner;
          host.size = CNControlSize.large;
        });
        await tester.pumpAndSettle();
        expect(viewSize(tester), const Size(37, 37));
        await finish(tester);
      },
      skip: !PlatformVersion.shouldUseNativeGlass,
    );
  });
}
