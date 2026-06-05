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
