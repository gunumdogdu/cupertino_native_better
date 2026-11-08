import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({super.key, required this.initial});

  final CNIcon initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late CNIcon icon = widget.initial;

  void show(CNIcon next) => setState(() => icon = next);

  @override
  Widget build(BuildContext context) => CupertinoApp(home: Center(child: icon));
}

void main() {
  group('CNSymbolEffect.toMap', () {
    test('encodes only the options that are set', () {
      expect(const CNSymbolEffect.bounce().toMap(), {'type': 'bounce'});
      expect(const CNSymbolEffect.pulse().toMap(), {'type': 'pulse'});
      expect(const CNSymbolEffect.drawOff().toMap(), {'type': 'drawOff'});
    });

    test('encodes direction, scope, speed and effect flags', () {
      expect(
        const CNSymbolEffect.bounce(
          direction: CNSymbolEffectDirection.down,
          scope: CNSymbolEffectScope.byLayer,
          speed: 1.5,
        ).toMap(),
        {
          'type': 'bounce',
          'direction': 'down',
          'scope': 'byLayer',
          'speed': 1.5,
        },
      );
      expect(
        const CNSymbolEffect.variableColor(
          cumulative: true,
          reversing: true,
          hideInactiveLayers: true,
        ).toMap(),
        {
          'type': 'variableColor',
          'cumulative': true,
          'reversing': true,
          'hideInactiveLayers': true,
        },
      );
      expect(const CNSymbolEffect.wiggle(angle: 45).toMap(), {
        'type': 'wiggle',
        'angle': 45.0,
      });
      expect(const CNSymbolEffect.breathe(pulse: true).toMap(), {
        'type': 'breathe',
        'pulse': true,
      });
      expect(
        const CNSymbolEffect.drawOff(
          reversed: true,
          scope: CNSymbolEffectScope.individually,
        ).toMap(),
        {'type': 'drawOff', 'scope': 'individually', 'reversed': true},
      );
    });

    test('encodes the repeat behaviours', () {
      expect(
        const CNSymbolEffect.pulse(repeat: CNSymbolEffectRepeat.once).toMap(),
        {'type': 'pulse', 'repeat': 'once'},
      );
      expect(
        const CNSymbolEffect.rotate(
          repeat: CNSymbolEffectRepeat.continuous,
        ).toMap(),
        {'type': 'rotate', 'repeat': 'continuous'},
      );
      expect(
        const CNSymbolEffect.bounce(
          repeat: CNSymbolEffectRepeat.periodic(
            count: 3,
            delay: Duration(milliseconds: 250),
          ),
        ).toMap(),
        {
          'type': 'bounce',
          'repeat': 'periodic',
          'repeatCount': 3,
          'repeatDelay': 0.25,
        },
      );
    });

    test('compares by value', () {
      expect(
        const CNSymbolEffect.wiggle(
          direction: CNSymbolEffectDirection.left,
          repeat: CNSymbolEffectRepeat.periodic(count: 2),
        ),
        CNSymbolEffect.wiggle(
          direction: CNSymbolEffectDirection.left,
          repeat: CNSymbolEffectRepeat.periodic(count: 1 + 1),
        ),
      );
      expect(
        const CNSymbolEffect.pulse() == const CNSymbolEffect.breathe(),
        isFalse,
      );
      expect(
        const CNSymbolEffect.pulse().hashCode,
        const CNSymbolEffect.pulse().hashCode,
      );
    });

    test('rejects a direction the effect does not take', () {
      expect(
        () => CNSymbolEffect.rotate(direction: CNSymbolEffectDirection.up),
        throwsAssertionError,
      );
      expect(
        () =>
            CNSymbolEffect.bounce(direction: CNSymbolEffectDirection.clockwise),
        throwsAssertionError,
      );
    });
  });

  group('CNIcon symbol effects on the channel', () {
    final created = <Map<Object?, Object?>>[];
    final calls = <MethodCall>[];

    void mockNative(WidgetTester tester) {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final params = (call.arguments as Map)['params'] as Uint8List;
          created.add(
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(params),
                )
                as Map<Object?, Object?>,
          );
        }
        return null;
      });
      for (var id = 0; id < 40; id++) {
        messenger.setMockMethodCallHandler(
          MethodChannel('CupertinoNativeIcon_$id'),
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
            MethodChannel('CupertinoNativeIcon_$id'),
            null,
          );
        }
      });
    }

    Future<GlobalKey<_HostState>> pumpHost(
      WidgetTester tester,
      CNIcon icon,
    ) async {
      mockNative(tester);
      final host = GlobalKey<_HostState>();
      await tester.pumpWidget(_Host(key: host, initial: icon));
      // Let PlatformViewGuard's debug delay pass so the UiKitView is built.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      return host;
    }

    Future<void> show(
      WidgetTester tester,
      GlobalKey<_HostState> host,
      CNIcon icon,
    ) async {
      calls.clear();
      host.currentState!.show(icon);
      await tester.pumpAndSettle();
    }

    List<String> methods() => [for (final c in calls) c.method];

    setUp(() {
      created.clear();
      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    testWidgets(
      'creation params are unchanged when no effect is used',
      (tester) async {
        await pumpHost(
          tester,
          const CNIcon(
            symbol: CNSymbol('heart', size: 20),
            color: Color(0xFFFF0000),
          ),
        );
        expect(created, hasLength(1));
        expect(created.single, {
          'name': 'heart',
          'isDark': false,
          'style': {'iconSize': 20.0, 'iconColor': 0xFFFF0000},
        });
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );

    testWidgets(
      'a rebuild without effects sends no effect calls',
      (tester) async {
        final host = await pumpHost(
          tester,
          const CNIcon(symbol: CNSymbol('heart', size: 20)),
        );
        await show(
          tester,
          host,
          const CNIcon(symbol: CNSymbol('star', size: 24)),
        );
        // A new symbol and a new size go out as one `setStyle` (#130).
        expect(methods(), ['setStyle']);
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );

    testWidgets(
      'a new symbol and colour go out as one setStyle carrying the symbol '
      '(#130)',
      (tester) async {
        final host = await pumpHost(
          tester,
          const CNIcon(
            symbol: CNSymbol('play.fill'),
            color: Color(0xFF007AFF),
            replaceTransition: CNSymbolReplaceTransition.replace,
          ),
        );
        await show(
          tester,
          host,
          const CNIcon(
            symbol: CNSymbol('pause.fill'),
            color: Color(0xFF8E8E93),
            replaceTransition: CNSymbolReplaceTransition.replace,
          ),
        );
        expect(methods(), ['setStyle']);
        final args = calls.last.arguments as Map;
        expect(args['name'], 'pause.fill');
        expect(args['iconColor'], 0xFF8E8E93);
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );

    testWidgets(
      'a new symbol alone still goes out as setSymbol',
      (tester) async {
        final host = await pumpHost(
          tester,
          const CNIcon(symbol: CNSymbol('play.fill'), color: Color(0xFF007AFF)),
        );
        await show(
          tester,
          host,
          const CNIcon(
            symbol: CNSymbol('pause.fill'),
            color: Color(0xFF007AFF),
          ),
        );
        expect(methods(), ['setSymbol']);
        expect((calls.last.arguments as Map)['name'], 'pause.fill');
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );

    testWidgets(
      'creation params carry the effect and transition',
      (tester) async {
        await pumpHost(
          tester,
          const CNIcon(
            symbol: CNSymbol('wifi'),
            effect: CNSymbolEffect.variableColor(cumulative: true),
            replaceTransition: CNSymbolReplaceTransition.magic,
            effectTrigger: 1,
          ),
        );
        expect(created.single['symbolEffect'], {
          'type': 'variableColor',
          'cumulative': true,
        });
        expect(created.single['replaceTransition'], 'magic');
        expect(calls.where((c) => c.method == 'playSymbolEffect'), isEmpty);
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );

    testWidgets(
      'changing effect sends setSymbolEffect once',
      (tester) async {
        final host = await pumpHost(
          tester,
          const CNIcon(symbol: CNSymbol('record.circle')),
        );
        await show(
          tester,
          host,
          const CNIcon(
            symbol: CNSymbol('record.circle'),
            effect: CNSymbolEffect.pulse(),
          ),
        );
        expect(methods(), ['setSymbolEffect']);
        expect((calls.single.arguments as Map)['effect'], {'type': 'pulse'});

        await show(
          tester,
          host,
          const CNIcon(
            symbol: CNSymbol('record.circle'),
            effect: CNSymbolEffect.pulse(),
          ),
        );
        expect(methods(), isEmpty, reason: 'an equal effect is not resent');

        await show(
          tester,
          host,
          const CNIcon(symbol: CNSymbol('record.circle')),
        );
        expect(methods(), ['setSymbolEffect']);
        expect((calls.single.arguments as Map)['effect'], isNull);
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );

    testWidgets(
      'a changed trigger plays the triggered effect once',
      (tester) async {
        final host = await pumpHost(
          tester,
          const CNIcon(symbol: CNSymbol('bell'), effectTrigger: 0),
        );
        await show(
          tester,
          host,
          const CNIcon(symbol: CNSymbol('bell'), effectTrigger: 1),
        );
        expect(methods(), ['playSymbolEffect']);
        expect(
          (calls.single.arguments as Map)['effect'],
          {'type': 'bounce'},
          reason: 'bounce is the default triggered effect',
        );

        await show(
          tester,
          host,
          const CNIcon(symbol: CNSymbol('bell'), effectTrigger: 1),
        );
        expect(methods(), isEmpty);

        await show(
          tester,
          host,
          const CNIcon(
            symbol: CNSymbol('bell'),
            triggeredEffect: CNSymbolEffect.wiggle(),
            effectTrigger: 2,
          ),
        );
        expect(methods(), ['playSymbolEffect']);
        expect((calls.single.arguments as Map)['effect'], {'type': 'wiggle'});
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );

    testWidgets(
      'the replace transition is sent before the new symbol',
      (tester) async {
        final host = await pumpHost(
          tester,
          const CNIcon(symbol: CNSymbol('play.fill')),
        );
        await show(
          tester,
          host,
          const CNIcon(
            symbol: CNSymbol('pause.fill'),
            replaceTransition: CNSymbolReplaceTransition.downUp,
          ),
        );
        expect(methods(), ['setReplaceTransition', 'setSymbol']);
        expect((calls.first.arguments as Map)['transition'], 'downUp');
        debugDefaultTargetPlatformOverride = null;
      },
      skip: !(Platform.isMacOS || Platform.isIOS),
    );
  });
}
