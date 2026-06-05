import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'capture_stage.dart';

class StageSpec {
  const StageSpec({required this.kind, required this.loopMs, required this.build});
  final String kind;   // 'static' | 'animated'
  final int loopMs;
  final Widget Function() build;
}

final Map<String, StageSpec> kStages = {
  'cn-button': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-button',
      size: const Size(220, 80),
      child: CNButton(
        label: 'Get Started',
        icon: const CNSymbol('arrow.right', size: 18),
        config: const CNButtonConfig(style: CNButtonStyle.filled),
        onPressed: () {},
      ),
    ),
  ),
  'cn-button-icon': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-button-icon',
      size: const Size(120, 80),
      child: CNButton.icon(
        icon: const CNSymbol('square.and.arrow.up', size: 20),
        onPressed: () {},
      ),
    ),
  ),
  'cn-icon': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-icon',
      size: const Size(96, 80),
      child: const CNIcon(
        symbol: CNSymbol('star.fill'),
        size: 32,
        color: CupertinoColors.systemYellow,
      ),
    ),
  ),
  'liquid-glass-container': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'liquid-glass-container',
      size: const Size(240, 140),
      background: const Color(0xFF3A5BA0),
      child: LiquidGlassContainer(
        config: const LiquidGlassConfig(
          shape: CNGlassEffectShape.rect,
          cornerRadius: 20,
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Liquid Glass',
            style: TextStyle(color: CupertinoColors.white),
          ),
        ),
      ),
    ),
  ),
  'cn-glass-button-group': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-glass-button-group',
      size: const Size(240, 90),
      background: const Color(0xFF3A5BA0),
      child: CNGlassButtonGroup.fromWidgets(
        buttonWidgets: [
          CNButton.icon(
            icon: const CNSymbol('plus', size: 18),
            onPressed: () {},
          ),
          CNButton.icon(
            icon: const CNSymbol('minus', size: 18),
            onPressed: () {},
          ),
          CNButton.icon(
            icon: const CNSymbol('square.and.arrow.up', size: 18),
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
  'cn-glass-card': StageSpec(
    kind: 'static',
    loopMs: 0,
    build: () => CaptureStage(
      id: 'cn-glass-card',
      size: const Size(260, 160),
      background: const Color(0xFF2A2440),
      child: const CNGlassCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Glass Card',
            style: TextStyle(color: CupertinoColors.white),
          ),
        ),
      ),
    ),
  ),
  'cn-switch': StageSpec(
    kind: 'animated',
    loopMs: 2400,
    build: () => const _SwitchLoop(),
  ),
};

class _SwitchLoop extends StatefulWidget {
  const _SwitchLoop();
  @override
  State<_SwitchLoop> createState() => _SwitchLoopState();
}

class _SwitchLoopState extends State<_SwitchLoop> {
  bool _v = false;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (mounted) setState(() => _v = !_v);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptureStage(
    id: 'cn-switch',
    size: const Size(120, 80),
    animMs: 2400,
    child: CNSwitch(value: _v, onChanged: (x) => setState(() => _v = x)),
  );
}
