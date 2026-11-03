import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Color? tint;

  void setTint(Color? value) => setState(() => tint = value);

  @override
  Widget build(BuildContext context) => CupertinoApp(
    home: CupertinoPageScaffold(
      child: Center(
        child: SizedBox(
          width: 52,
          height: 52,
          child: CNButton.icon(
            icon: const CNSymbol('crop'),
            tint: tint,
            config: const CNButtonConfig(style: CNButtonStyle.clearGlass),
            onPressed: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  final calls = <MethodCall>[];

  void mockNative(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    for (var id = 0; id < 40; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('CupertinoNativeButton_$id'),
        (call) async {
          calls.add(call);
          return null;
        },
      );
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeButton_$id'),
          null,
        );
      }
    });
  }

  List<String> styleCalls() => [
    for (final c in calls)
      if (c.method == 'setStyle') '${c.arguments}',
  ];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  testWidgets(
    'a tint set back to null resets the native tint',
    (tester) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: host));
      await tester.pumpAndSettle();
      expect(styleCalls(), isEmpty, reason: 'created without a tint');

      host.currentState!.setTint(const Color(0xFFFFCC00));
      await tester.pumpAndSettle();
      host.currentState!.setTint(null);
      await tester.pumpAndSettle();
      host.currentState!.setTint(null);
      await tester.pumpAndSettle();

      expect(styleCalls(), [
        '{tint: ${0xFFFFCC00}}',
        '{clearTint: true}',
      ]);
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !PlatformVersion.shouldUseNativeGlass,
  );
}
